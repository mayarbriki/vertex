import 'package:flutter/material.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  // Create 4 controllers for 4 digits
  final List<TextEditingController> _controllers =
  List.generate(4, (_) => TextEditingController());

  // Combine digits into OTP string
  String get _otpCode =>
      _controllers.map((controller) => controller.text).join();

  void _verifyOTP() {
    if (_otpCode.length == 4) {
      // Dummy check: OTP = "1234"
      if (_otpCode == "1234") {
        Navigator.pushNamed(context, '/reset-password');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid OTP, please try again")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter all 4 digits")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("OTP Verification",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Enter the verification code sent to your email."),
            const SizedBox(height: 20),

            // OTP input fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                    (index) => SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _controllers[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: const InputDecoration(counterText: ""),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 3) {
                        FocusScope.of(context).nextFocus(); // move to next box
                      }
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyOTP,
              child: const Text("Verify"),
            ),

            const Spacer(),
            TextButton(
              onPressed: () {
                // TODO: add resend OTP logic
              },
              child: const Text("Didn’t receive code? Resend"),
            )
          ],
        ),
      ),
    );
  }
}
