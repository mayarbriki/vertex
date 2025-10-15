import 'package:flutter/material.dart';
import 'package:smart_personal_final_app/db/db.dart';
import 'package:smart_personal_final_app/features/auth/presentation/welcome_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/login_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/register_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/otp_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/reset_password_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/success_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure the SQLite DB file is created right away
  try {
    await DBProvider.instance.init();
    print('DB path: ${DBProvider.instance.databasePath}');
    final exportedPath = await DBProvider.instance.exportConsolidatedDatabase();
print('Exported DB path: $exportedPath');


    // ✅ Insert a test user
    await DBProvider.instance.insertUser({
      'name': 'John Doe',
      'email': 'john@example.com',
      'password': '123456',
      'created_at': DateTime.now().toIso8601String(),
      'is_active': 1,
    });

    print('Test user inserted!');
  } catch (e) {
    print('DB init or insert failed: $e');
  }

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Travel Auth Flow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/otp': (context) => const OTPScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/success': (context) => const SuccessScreen(),
      },
    );
  }
}
