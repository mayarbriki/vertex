import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DBProvider {
  // Singleton
  DBProvider._privateConstructor();
  static final DBProvider instance = DBProvider._privateConstructor();

  static Database? _database;

  // stored database file path (useful for debugging / exporting)
  String? _dbPath;

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app.db');
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDB(String fileName) async {
    // Use sqflite's database directory which is the conventional location
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    _dbPath = path;
    // Make sure the directory exists (safe no-op if it already does)
    try {
      await Directory(dbPath).create(recursive: true);
    } catch (_) {}
    print('📁 Database created at: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        // Ensure WAL is checkpointed and disabled so the main .db file
        // contains the most recent data when copied off device.
        // This helps avoid "file is not a database" when pulling the file.
        try {
          await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
          await db.execute('PRAGMA journal_mode=DELETE');
        } catch (e) {
          // ignore errors here (best effort)
        }
      },
    );
  }

  // Create tables
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT,
        created_at TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  /// Force database creation / initialization and print its path.
  /// Call this from your app startup (e.g. main) to ensure app.db is created.
  Future<void> init() async {
    await database;
    print('DB ready at: $_dbPath');

    // Fire-and-forget: create an exported, consolidated DB inside the app's
    // databases/ directory so `adb shell "run-as <pkg> cat databases/exported_app.db"` works.
    // Do NOT await here to avoid jank on startup.
    Future(() async {
      try {
        final exported = await ensureExportedDatabaseInDatabasesDir(fileName: 'exported_app1.db');
        print('Exported DB created at: $exported');
      } catch (e) {
        print('Failed to create exported DB: $e');
      }
    });
  }

  /// Optional: get the path where the DB file is stored.
  String? get databasePath => _dbPath;

  // Insert a user
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('user', user);
  }

  // Get all users
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('user');
  }

  // Delete a user by id
  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('user', where: 'id = ?', whereArgs: [id]);
  }

  /// Export a consolidated copy of the database to the app's files directory.
  /// This will:
  ///  1) attempt a WAL checkpoint and switch to DELETE mode (consolidate changes)
  ///  2) close the database (to avoid racing writes)
  ///  3) copy the .db file to <app_files_dir>/$fileName (e.g. files/exported_app.db)
  ///  4) reopen the database
  /// Returns the full path of the exported file inside the app's files dir.
  Future<String> exportConsolidatedDatabase({String fileName = 'exported_app1.db'}) async {
    final db = await database;
    // Best-effort: checkpoint WAL and disable WAL journaling so main file is up-to-date
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.execute('PRAGMA journal_mode=DELETE');
    } catch (_) {
      // ignore (best effort)
    }

    // Prepare destination path
    final appFilesDir = await getApplicationDocumentsDirectory();
    final destPath = join(appFilesDir.path, fileName);
    final destFile = File(destPath);

    // Try to produce a consolidated DB directly using VACUUM INTO (if supported).
    // This creates a new, consistent DB file at destPath while DB is open.
    try {
      // Ensure destination directory exists and remove any pre-existing file,
      // because VACUUM INTO fails when the output file already exists.
      try {
        await destFile.parent.create(recursive: true);
      } catch (_) {}
      if (await destFile.exists()) {
        await destFile.delete();
      }
      // Escape single quotes in path for SQL literal safety
      final vacuumPathEscaped = destPath.replaceAll("'", "''");
      await db.execute("VACUUM INTO '$vacuumPathEscaped'");
      // If VACUUM INTO succeeded, ensure DB is closed and reopened for normal operation.
      await close();
      await database; // reopen
      print('DB exported to (via VACUUM INTO): $destPath');
      return destPath;
    } catch (e) {
      // VACUUM INTO may not be supported; fall back to close-and-copy method below.
    }

    // Close DB so we can safely copy the file
    await close();

    if (_dbPath == null) {
      throw Exception('Database path unknown; cannot export');
    }

    final src = File(_dbPath!);
    if (!await src.exists()) {
      throw Exception('Source DB file not found at $_dbPath');
    }

    // Overwrite if exists
    if (await destFile.exists()) {
      await destFile.delete();
    }
    await src.copy(destPath);

    // Reopen DB for normal operation
    await database; // triggers _initDB again via getter

    print('DB exported to: $destPath');
    return destPath;
  }

  /// Export a consolidated copy of the database into the app's databases/ directory.
  /// This is useful when you want to pull the DB via:
  ///   adb shell "run-as <package> cat databases/exported_app.db" > app.db
  /// The method attempts VACUUM INTO first, falls back to close+copy.
  Future<String> exportConsolidatedDatabaseToDatabasesDir({String fileName = 'exported_app1.db'}) async {
    final db = await database;
    // Best-effort: checkpoint WAL and disable WAL journaling so main file is up-to-date
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.execute('PRAGMA journal_mode=DELETE');
    } catch (_) {
      // ignore (best effort)
    }

    // Destination path inside the app's databases directory
    final dbPath = await getDatabasesPath();
    final destPath = join(dbPath, fileName);
    final destFile = File(destPath);

    // Try VACUUM INTO first (may work on some SQLite builds)
    try {
      // Ensure destination directory exists and remove any pre-existing file
      // because VACUUM INTO fails when the output file already exists.
      try {
        await destFile.parent.create(recursive: true);
      } catch (_) {}
      if (await destFile.exists()) {
        await destFile.delete();
      }
      final vacuumPathEscaped = destPath.replaceAll("'", "''");
      await db.execute("VACUUM INTO '$vacuumPathEscaped'");
      // If VACUUM INTO succeeded, ensure DB is closed and reopened for normal operation.
      await close();
      await database; // reopen
      print('DB exported to (via VACUUM INTO): $destPath');
      return destPath;
    } catch (e) {
      // VACUUM INTO may not be supported; fall back to close-and-copy method below.
    }

    // Close DB so we can safely copy the file
    await close();

    if (_dbPath == null) {
      throw Exception('Database path unknown; cannot export');
    }

    final src = File(_dbPath!);
    if (!await src.exists()) {
      throw Exception('Source DB file not found at $_dbPath');
    }

    // Ensure destination directory exists (should be the same as dbPath)
    try {
      await Directory(dbPath).create(recursive: true);
    } catch (_) {}

    // Overwrite if exists
    if (await destFile.exists()) {
      await destFile.delete();
    }
    await src.copy(destPath);

    // Reopen DB for normal operation
    await database; // triggers _initDB again via getter

    print('DB exported to: $destPath');
    return destPath;
  }

  /// Ensure an exported DB file exists in the app's databases directory.
  /// This wrapper tries VACUUM INTO, falls back to close+copy, then attempts
  /// to set permissive file mode (best-effort with chmod) so `adb shell run-as` can read it.
  /// Returns absolute path to the exported file inside databases/.
  Future<String> ensureExportedDatabaseInDatabasesDir({String fileName = 'exported_app1.db'}) async {
    final dbPath = await getDatabasesPath();
    final destPath = join(dbPath, fileName);
    final destFile = File(destPath);

    final db = await database;
    // Try VACUUM INTO first (may work on some SQLite builds)
    try {
      // Ensure destination directory exists and remove any pre-existing file
      // because VACUUM INTO fails when the output file already exists.
      try {
        await destFile.parent.create(recursive: true);
      } catch (_) {}
      if (await destFile.exists()) {
        await destFile.delete();
      }
      final vacuumPathEscaped = destPath.replaceAll("'", "''");
      await db.execute("VACUUM INTO '$vacuumPathEscaped'");
      // If VACUUM INTO succeeded, ensure DB is closed and reopened for normal operation.
      await close();
      await database; // reopen
      print('DB exported to (via VACUUM INTO): $destPath');
    } catch (_) {
      // VACUUM INTO failed; fall back to close+copy
      await close();

      if (_dbPath == null) {
        throw Exception('Database path unknown; cannot export');
      }

      final src = File(_dbPath!);
      if (!await src.exists()) {
        throw Exception('Source DB file not found at $_dbPath');
      }

      try {
        await Directory(dbPath).create(recursive: true);
      } catch (_) {}

      if (await destFile.exists()) {
        await destFile.delete();
      }
      await src.copy(destPath);

      // Reopen DB for normal operation
      await database; // triggers _initDB again via getter

      print('DB exported to: $destPath');
    }

    // Best-effort: try to make file world-readable within app storage via chmod.
    // This often isn't necessary for run-as (same uid), but can help tooling.
    try {
      await Process.run('chmod', ['644', destPath]);
      print('chmod 644 applied to $destPath (best-effort)');
    } catch (e) {
      // ignore failures; it's just best-effort
    }

    return destPath;
  }

  /// Convenience helper used by debugging/dev to ensure an export exists and
  /// print the adb command you can run to pull it to your PC.
  /// Returns the exported file path inside the app's databases directory.
  Future<String> exportForAdbPull({String fileName = 'exported_app1.db'}) async {
    final exportedPath = await ensureExportedDatabaseInDatabasesDir(fileName: fileName);

    // Helpful printed instructions for the developer using adb
    final pkg = 'com.example.smart_personal_final_app';
    final cmd1 = 'adb exec-out run-as $pkg cat databases/$fileName > $fileName';
    final cmd2 = 'adb shell "run-as $pkg cat databases/$fileName" > $fileName';
    print('Export ready: $exportedPath');
    print('Pull using one of these on your machine:');
    print('  $cmd1');
    print('or');
    print('  $cmd2');

    return exportedPath;
  }

  /// List files in the app databases directory (useful to confirm exported file exists).
  Future<List<String>> listDatabasesDir() async {
    final dbPath = await getDatabasesPath();
    final dir = Directory(dbPath);
    if (!await dir.exists()) return [];
    final children = await dir.list().toList();
    return children.map((e) => e.path).toList();
  }
  

  // Close the database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
