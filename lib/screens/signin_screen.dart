import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      } finally {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF282C33),
      body: SafeArea(
        child: Column(
          children: [
            // Top section for logo/image
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/images/StudySync.png',
                    width: 240,
                    height: 220,
                  ),
                ],
              ),
            ),
            Spacer(flex: 1),
            // Centered bottom section: fields and buttons
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Google Sign-In button at top
                      SizedBox(
                        width: 330,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: Image.asset('assets/images/google_Logo.png', width: 28, height: 28),
                         label: Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'Lexend Deca',
                                  fontWeight: FontWeight.w800, // ExtraBold
                                  fontSize: 16, // (adjust size as needed)
                                ),
                              ),

                            style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.white),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      CustomTextField(
                        hintText: 'email',
                        controller: _emailController,
                        obscureText: false,
                      ),
                      SizedBox(height: 16),
                      CustomTextField(
                        hintText: 'password',
                        controller: _passwordController,
                        obscureText: true,
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: 274,
                        height: 50,
                        child: CustomButton(
                          text: 'LOGIN',
                          onPressed: _isLoading ? null : _signInWithEmail,
                          width: 274,
                          height: 50,
                          fontSize: 18,
                          backgroundColor: Color(0xFF7550FF)
                        ),
                      ),
                      SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: Text(
                          'Don\'t have an account? Sign Up',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 18),
                      // <-- Divider and OR Row Removed
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
