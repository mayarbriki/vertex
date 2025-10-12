import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "Welcome back! Glad to see you, Again!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const TextField(decoration: InputDecoration(labelText: "Enter your email")),
            const SizedBox(height: 15),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: "Enter your password")),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                child: const Text("Forgot Password?"),
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Login"),
            ),
            const SizedBox(height: 20),
            const Text("Or Login with"),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.facebook, size: 32),
                SizedBox(width: 20),
                Icon(Icons.g_mobiledata, size: 32),
                SizedBox(width: 20),
                Icon(Icons.apple, size: 32),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don’t have an account?"),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text("Register Now"),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
