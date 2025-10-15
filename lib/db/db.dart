import 'dart:io';
import 'dart:async';
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
      version: 2, // bumped to trigger onUpgrade for existing installs
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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

        // Ensure required tables exist even if onUpgrade didn't run yet
        // (creates v2 tables if missing). Idempotent and safe to call on every open.
        try {
          await _ensureSchemaExists(db);
        } catch (e) {
          print('Failed to ensure DB schema on open: $e');
        }
      },
    );
  }

  // Create tables for fresh installs
  Future _onCreate(Database db, int version) async {
    // USER table
    await db.execute('''
    CREATE TABLE user (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      is_active INTEGER NOT NULL DEFAULT 1
    );
  ''');

    // ACCOUNT table
    await db.execute('''
    CREATE TABLE account (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      balance REAL DEFAULT 0.0,
      currency TEXT DEFAULT 'TND',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES user(id)
    );
  ''');

    // TRANSACTION table
    await db.execute('''
    CREATE TABLE "transaction" (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      type TEXT CHECK(type IN ('income','expense')) NOT NULL,
      amount REAL NOT NULL,
      category TEXT,
      description TEXT,
      date TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (account_id) REFERENCES account(id)
    );
  ''');

    // CATEGORY table
    await db.execute('''
    CREATE TABLE category (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT CHECK(type IN ('income','expense')) NOT NULL
    );
  ''');

    // BUDGET table
    await db.execute('''
    CREATE TABLE budget (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      account_id INTEGER,
      name TEXT NOT NULL,
      amount_limit REAL NOT NULL,
      period_start TEXT NOT NULL,
      period_end TEXT NOT NULL,
      category TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES user(id),
      FOREIGN KEY (account_id) REFERENCES account(id)
    );
  ''');

    print('✅ All tables created successfully');
  }

  // Handle migrations between DB versions.
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: add account, transaction and category tables
    if (oldVersion < 2 && newVersion >= 2) {
      await _createSchemaV2(db);
      print('🔼 Database upgraded from $oldVersion to $newVersion: v2 tables added');
    }
  }

  // Create v2 schema pieces (safe to call on existing DB).
  Future<void> _createSchemaV2(Database db) async {
    // Use IF NOT EXISTS to avoid errors if table already present.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS account (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'TND',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES user(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "transaction" (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        type TEXT CHECK(type IN ('income','expense')) NOT NULL,
        amount REAL NOT NULL,
        category TEXT,
        description TEXT,
        date TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (account_id) REFERENCES account(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT CHECK(type IN ('income','expense')) NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        account_id INTEGER,
        name TEXT NOT NULL,
        amount_limit REAL NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        category TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES user(id),
        FOREIGN KEY (account_id) REFERENCES account(id)
      );
    ''');
  }

  /// Force database creation / initialization and print its path.
  /// Call this from your app startup (e.g. main) to ensure app.db is created.
  Future<void> init() async {
    await database;
    print('DB ready at: $_dbPath');

    // Force schema verification and creation
    await ensureAllTablesExist();

    // Fire-and-forget: create an exported, consolidated DB inside the app's
    // databases/ directory so `adb shell "run-as <pkg> cat databases/exported_app.db"` works.
    // Do NOT await here to avoid jank on startup.
    Future(() async {
      try {
        final exported = await ensureExportedDatabaseInDatabasesDir(fileName: 'exported_app.db');
        print('Exported DB created at: $exported');
      } catch (e) {
        print('Failed to create exported DB: $e');
      }
    });

    // Fire-and-forget: ensure there's one sample row in each table for debugging/dev.
    Future(() async {
      try {
        await seedSampleData();
      } catch (e) {
        print('Failed to seed sample data: $e');
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

  // Update a user
  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await database;
    return await db.update('user', user, where: 'id = ?', whereArgs: [id]);
  }

  // Get user by email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query('user', where: 'email = ?', whereArgs: [email]);
    return result.isNotEmpty ? result.first : null;
  }

  // ACCOUNT CRUD operations
  Future<int> insertAccount(Map<String, dynamic> account) async {
    final db = await database;
    return await db.insert('account', account);
  }

  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    final db = await database;
    return await db.query('account');
  }

  Future<List<Map<String, dynamic>>> getAccountsByUserId(int userId) async {
    final db = await database;
    return await db.query('account', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<int> updateAccount(int id, Map<String, dynamic> account) async {
    final db = await database;
    return await db.update('account', account, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete('account', where: 'id = ?', whereArgs: [id]);
  }

  // TRANSACTION CRUD operations
  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    return await db.insert('transaction', transaction);
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    return await db.query('transaction');
  }

  Future<List<Map<String, dynamic>>> getTransactionsByAccountId(int accountId) async {
    final db = await database;
    return await db.query('transaction', where: 'account_id = ?', whereArgs: [accountId]);
  }

  Future<int> updateTransaction(int id, Map<String, dynamic> transaction) async {
    final db = await database;
    return await db.update('transaction', transaction, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transaction', where: 'id = ?', whereArgs: [id]);
  }

  // CATEGORY CRUD operations
  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert('category', category);
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query('category');
  }

  Future<List<Map<String, dynamic>>> getCategoriesByType(String type) async {
    final db = await database;
    return await db.query('category', where: 'type = ?', whereArgs: [type]);
  }

  Future<int> updateCategory(int id, Map<String, dynamic> category) async {
    final db = await database;
    return await db.update('category', category, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('category', where: 'id = ?', whereArgs: [id]);
  }

  // DATABASE DEBUGGING AND VERIFICATION METHODS

  // BUDGET CRUD operations
  Future<int> insertBudget(Map<String, dynamic> budget) async {
    final db = await database;
    return await db.insert('budget', budget);
  }

  Future<List<Map<String, dynamic>>> getAllBudgets() async {
    final db = await database;
    return await db.query('budget', orderBy: 'period_start DESC');
  }

  Future<List<Map<String, dynamic>>> getBudgetsByUser(int userId) async {
    final db = await database;
    return await db.query('budget', where: 'user_id = ?', whereArgs: [userId], orderBy: 'period_start DESC');
  }

  Future<int> updateBudget(int id, Map<String, dynamic> budget) async {
    final db = await database;
    return await db.update('budget', budget, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete('budget', where: 'id = ?', whereArgs: [id]);
  }

  /// Compute total spent amount within a date range, optionally filtered by account and category.
  Future<double> getSpentAmount({
    required DateTime from,
    required DateTime to,
    int? accountId,
    String? category,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    where.add('date >= ?');
    args.add(from.toIso8601String());
    where.add('date <= ?');
    args.add(to.toIso8601String());
    where.add("type = 'expense'");
    if (accountId != null) {
      where.add('account_id = ?');
      args.add(accountId);
    }
    if (category != null && category.isNotEmpty) {
      where.add('category = ?');
      args.add(category);
    }

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM "transaction" WHERE ' + where.join(' AND '),
      args,
    );
    final total = result.first['total'] as num?;
    return (total ?? 0).toDouble();
  }

  /// Get all table names in the database
  Future<List<String>> getTableNames() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );
    return result.map((row) => row['name'] as String).toList();
  }

  /// Get table info for debugging
  Future<Map<String, dynamic>> getTableInfo(String tableName) async {
    final db = await database;
    try {
      final result = await db.rawQuery("PRAGMA table_info($tableName)");
      final count = await db.rawQuery("SELECT COUNT(*) as count FROM $tableName");
      return {
        'columns': result,
        'row_count': count.first['count'],
        'table_name': tableName,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'table_name': tableName,
      };
    }
  }

  /// Get comprehensive database status
  Future<Map<String, dynamic>> getDatabaseStatus() async {
    final db = await database;
    final tables = await getTableNames();
    final Map<String, dynamic> status = {
      'database_path': _dbPath,
      'tables': tables,
      'table_details': <String, dynamic>{},
    };

    for (final table in tables) {
      status['table_details'][table] = await getTableInfo(table);
    }

    return status;
  }

  /// Verify all expected tables exist and have correct structure
  Future<bool> verifyDatabaseSchema() async {
    try {
      final tables = await getTableNames();
      final expectedTables = ['user', 'account', 'transaction', 'category', 'budget'];
      
      print('📊 Database schema verification:');
      print('Found tables: ${tables.join(', ')}');
      print('Expected tables: ${expectedTables.join(', ')}');
      
      for (final expectedTable in expectedTables) {
        if (!tables.contains(expectedTable)) {
          print('❌ Missing table: $expectedTable');
          return false;
        } else {
          final info = await getTableInfo(expectedTable);
          print('✅ Table $expectedTable exists with ${info['row_count']} rows');
        }
      }
      
      return true;
    } catch (e) {
      print('❌ Schema verification failed: $e');
      return false;
    }
  }

  /// Force creation of all tables (even if they exist)
  Future<void> ensureAllTablesExist() async {
    final db = await database;
    try {
      print('🔧 Ensuring all tables exist...');
      
      // First check what currently exists
      final currentTables = await getTableNames();
      print('Current tables in DB: ${currentTables.join(', ')}');
      
      // Force create user table first (in case onCreate didn't run)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          is_active INTEGER NOT NULL DEFAULT 1
        );
      ''');
      
      await _ensureSchemaExists(db);
      
      // Verify the schema was created
      final success = await verifyDatabaseSchema();
      if (success) {
        print('✅ All tables verified successfully');
      } else {
        print('❌ Table verification failed after creation attempt');
        // If verification failed, try to force recreate the entire database
        print('🔄 Attempting to force recreate database...');
        await forceRecreateDatabase();
        print('🔄 Database recreated, verifying again...');
        await verifyDatabaseSchema();
      }
    } catch (e) {
      print('❌ Failed to ensure tables exist: $e');
      rethrow;
    }
  }

  /// Complete database test and setup
  Future<void> testDatabaseSetup() async {
    try {
      print('🧪 Starting complete database test...');
      
      // Force recreate database to start fresh
      await forceRecreateDatabase();
      
      // Verify schema
      final verified = await verifyDatabaseSchema();
      if (!verified) {
        throw Exception('Schema verification failed');
      }
      
      // Create test data
      await createTestData();
      
      // Export database
      await exportForAdbPull();
      
      print('✅ Database test completed successfully');
      
    } catch (e) {
      print('❌ Database test failed: $e');
      rethrow;
    }
  }

  /// Create sample data in all tables for testing
  Future<void> createTestData() async {
    try {
      print('🧪 Creating test data...');
      
      // Create test user
      final userId = await insertUser({
        'name': 'Test User',
        'email': 'test@example.com',
        'password': 'test123',
      });
      print('Created test user with ID: $userId');

      // Create test account
      final accountId = await insertAccount({
        'user_id': userId,
        'name': 'Test Account',
        'type': 'checking',
        'balance': 1000.0,
        'currency': 'TND',
      });
      print('Created test account with ID: $accountId');

      // Create test categories
      final expenseCategoryId = await insertCategory({
        'name': 'Food',
        'type': 'expense',
      });
      
      final incomeCategoryId = await insertCategory({
        'name': 'Salary',
        'type': 'income',
      });
      print('Created test categories: expense=$expenseCategoryId, income=$incomeCategoryId');

      // Create test transactions
      final expenseId = await insertTransaction({
        'account_id': accountId,
        'type': 'expense',
        'amount': 25.50,
        'category': 'Food',
        'description': 'Lunch at restaurant',
      });

      final incomeId = await insertTransaction({
        'account_id': accountId,
        'type': 'income',
        'amount': 2000.0,
        'category': 'Salary',
        'description': 'Monthly salary',
      });
      print('Created test transactions: expense=$expenseId, income=$incomeId');

      print('✅ Test data created successfully');
    } catch (e) {
      print('❌ Failed to create test data: $e');
      rethrow;
    }
  }

  // Close the database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Idempotent helper that creates any missing schema pieces (v2 tables).
  /// Safe to call on every open; uses IF NOT EXISTS.
  Future<void> _ensureSchemaExists(Database db) async {
    // If account/transaction/category don't exist, create them.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS account (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'TND',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES user(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "transaction" (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        type TEXT CHECK(type IN ('income','expense')) NOT NULL,
        amount REAL NOT NULL,
        category TEXT,
        description TEXT,
        date TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (account_id) REFERENCES account(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT CHECK(type IN ('income','expense')) NOT NULL
      );
    '''); 

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        account_id INTEGER,
        name TEXT NOT NULL,
        amount_limit REAL NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        category TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES user(id),
        FOREIGN KEY (account_id) REFERENCES account(id)
      );
    ''');
  }

  // Insert one sample row in each table (idempotent: only runs when user table is empty).
  Future<void> seedSampleData() async {
    final db = await database;
    try {
      final countRes = await db.rawQuery('SELECT COUNT(*) AS c FROM user');
      final count = Sqflite.firstIntValue(countRes) ?? 0;
      if (count > 0) {
        print('seedSampleData: user table not empty, skipping inserts');
        return;
      }

      // Insert sample user
      final userId = await db.insert('user', {
        'name': 'Sample User',
        'email': 'sample@example.com',
        'password': 'password123',
      });
      print('seedSampleData: inserted user id=$userId');

      // Insert sample account for the user
      final accountId = await db.insert('account', {
        'user_id': userId,
        'name': 'Main Account',
        'type': 'bank',
        'balance': 100.0,
        'currency': 'TND',
      });
      print('seedSampleData: inserted account id=$accountId');

      // Insert sample category
      final categoryId = await db.insert('category', {
        'name': 'General',
        'type': 'expense',
      });
      print('seedSampleData: inserted category id=$categoryId');

      // Insert sample transaction referencing the account
      await db.insert('transaction', {
        'account_id': accountId,
        'type': 'expense',
        'amount': 10.0,
        'category': 'General',
        'description': 'Sample transaction',
      });
      print('seedSampleData: inserted sample transaction');

      // Insert sample budget for current month
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      final budgetId = await db.insert('budget', {
        'user_id': userId,
        'account_id': accountId,
        'name': 'Monthly Groceries',
        'amount_limit': 200.0,
        'period_start': start.toIso8601String(),
        'period_end': end.toIso8601String(),
        'category': 'General',
      });
      print('seedSampleData: inserted budget id=$budgetId');

    } catch (e) {
      print('seedSampleData failed: $e');
    }
  }

  /// Permanently delete the existing database files and recreate a fresh DB
  Future<void> forceRecreateDatabase({bool removeExported = true}) async {
    // Close any open DB handle first.
    await close();

    // Determine db path (use stored path if available, otherwise derive).
    final dbPath = _dbPath ?? join(await getDatabasesPath(), 'app.db');

    // Ensure any WAL/SHM files and the main DB are removed.
    final filesToRemove = <String>[
      dbPath,
      '$dbPath-wal',
      '$dbPath-shm',
    ];
    for (final f in filesToRemove) {
      try {
        final file = File(f);
        if (await file.exists()) {
          await file.delete();
          print('Deleted DB file: $f');
        }
      } catch (e) {
        print('Failed to delete $f: $e');
      }
    }

    // Recreate DB by initializing again (calls _onCreate).
    _database = await _initDB('app.db');
    print('Database force-recreated at: $_dbPath');
  }

  /// Ensure an exported DB file exists in the app's databases directory.
  Future<String> ensureExportedDatabaseInDatabasesDir({String fileName = 'exported_app.db'}) async {
    final dbPath = await getDatabasesPath();
    final destPath = join(dbPath, fileName);
    final destFile = File(destPath);

    final db = await database;
    // Close DB and copy file for export
    await close();
    await Future.delayed(Duration(milliseconds: 80));

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

    try {
      final len = await destFile.length();
      print('DB exported to: $destPath (size: $len bytes)');
    } catch (_) {
      print('DB exported to: $destPath');
    }

    return destPath;
  }

  /// Convenience helper for debugging/dev to ensure an export exists and print adb commands.
  Future<String> exportForAdbPull({String fileName = 'exported_app.db'}) async {
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

  /// Export a consolidated copy of the database to the app's files directory.
  /// This will close the database, copy the file, and reopen it.
  /// Returns the full path of the exported file.
  Future<String> exportConsolidatedDatabase({String fileName = 'exported_app.db'}) async {
    final db = await database;
    
    // Best-effort: checkpoint WAL and disable WAL journaling so main file is up-to-date
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.execute('PRAGMA journal_mode=DELETE');
      await Future.delayed(Duration(milliseconds: 80));
    } catch (_) {
      // ignore (best effort)
    }

    // Prepare destination path in app's documents directory
    final appFilesDir = await getApplicationDocumentsDirectory();
    final destPath = join(appFilesDir.path, fileName);
    final destFile = File(destPath);

    // Close DB so we can safely copy the file
    await close();
    await Future.delayed(Duration(milliseconds: 80));

    if (_dbPath == null) {
      throw Exception('Database path unknown; cannot export');
    }

    final src = File(_dbPath!);
    if (!await src.exists()) {
      throw Exception('Source DB file not found at $_dbPath');
    }

    // Ensure destination directory exists
    try {
      await destFile.parent.create(recursive: true);
    } catch (_) {}

    // Overwrite if exists
    if (await destFile.exists()) {
      await destFile.delete();
    }
    await src.copy(destPath);

    // Reopen DB for normal operation
    await database; // triggers _initDB again via getter

    try {
      final len = await destFile.length();
      print('DB exported to: $destPath (size: $len bytes)');
    } catch (_) {
      print('DB exported to: $destPath');
    }
    
    return destPath;
  }
}