import 'package:flutter/material.dart';
import 'package:smart_personal_final_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/login_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/otp_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/register_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/reset_password_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/success_screen.dart';
import 'package:smart_personal_final_app/features/auth/presentation/welcome_screen.dart';

void main() {
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
