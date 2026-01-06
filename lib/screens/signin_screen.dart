import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/background.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- NEW: Custom Error Dialog Helper ---
  Future<void> _showErrorDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF282C33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.redAccent, width: 1),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _signInWithEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = await _authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (user != null && mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
} catch (e) {
        // --- IMPROVED ERROR MESSAGING ---
        String errorMessage = "An unexpected error occurred. Please check your connection.";
        String errorString = e.toString().toLowerCase();

        // Check for specific error codes
        if (errorString.contains('user-not-found')) {
          errorMessage = "No account found with this email.";
        } 
        // FIX: Added 'invalid-credential' and 'invalid-login-credentials'
        else if (errorString.contains('wrong-password') || 
                 errorString.contains('invalid-credential') ||
                 errorString.contains('invalid-login-credentials')) {
          errorMessage = "The email or password you entered is incorrect.";
        } 
        else if (errorString.contains('invalid-email')) {
          errorMessage = "The email address is badly formatted.";
        } 
        else if (errorString.contains('network-request-failed')) {
          errorMessage = "Please check your internet connection.";
        } 
        else if (errorString.contains('too-many-requests')) {
          errorMessage = "Too many failed attempts. Please try again later.";
        }

        if (mounted) {
          _showErrorDialog("Login Failed", errorMessage);
        }
      }finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        // Also applied the dialog here for consistency
        _showErrorDialog("Google Sign-In Failed", "Could not connect to Google. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282C33),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF3C4147),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty) {
                // Keep SnackBar here for simple validation inside the dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your email')),
                );
                return;
              }
              
              try {
                setState(() => _isLoading = true);
                await _authService.sendPasswordResetEmail(emailController.text.trim());
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset email sent! Check your inbox.'),
                      duration: Duration(seconds: 3),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                 // Close the reset dialog first
                 Navigator.pop(context);
                 if (mounted) {
                   // Show the detailed error dialog
                   _showErrorDialog("Reset Failed", "Could not send reset email. Please verify the address.");
                 }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. Get Screen Width ---
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      body: Stack(
        children: [
          const GlowyBackground(),
          
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 42, vertical: 13),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 
                        MediaQuery.of(context).padding.top - 
                        MediaQuery.of(context).padding.bottom - 26, 
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 50, bottom: 40),
                          // --- 2. Applied Responsive Logic Here ---
                          child: Container(
                            width: screenWidth * 0.6, // 80% of screen width
                            child: Image.asset(
                              'assets/images/StudySync.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          // ----------------------------------------
                        ),
                        SizedBox(height: 60),
                        
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : _signInWithGoogle,
                                    icon: Image.asset('assets/images/google_Logo.png', width: 28, height: 28),
                                    label: const Text(
                                      'LOGIN WITH GOOGLE',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontFamily: 'LexendDeca',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              Align(
                                alignment: Alignment.centerLeft,
                               
                              ),
                              SizedBox(height: 8),
                              CustomTextField(
                                hintText: 'E-mail',
                                controller: _emailController,
                                obscureText: false,
                              ),
                              SizedBox(height: 20),
                              
                              Align(
                                alignment: Alignment.centerLeft,
                                
                              ),
                              SizedBox(height: 8),
                              CustomTextField(
                                hintText: 'Password',
                                controller: _passwordController,
                                obscureText: true,
                              ),
                              const SizedBox(height: 12),
                              
                              Align(
                                alignment: Alignment.center,
                                child: TextButton(
                                  onPressed: _isLoading ? null : _showForgotPasswordDialog,
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              Center(
                                child: CustomButton(
                                  text: 'LOGIN',
                                  onPressed: _isLoading ? null : _signInWithEmail,
                                  width: 300,
                                  height: 52,
                                  fontSize: 20,
                                  backgroundColor: const Color(0xFF7550FF),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/signup');
                                },
                                child: const Text(
                                  'Don\'t have an account? Sign Up',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'LexendDeca',
                                    fontWeight: FontWeight.w400,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white,
                                    decorationThickness: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}