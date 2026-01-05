import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/background.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill out all fields')),
      );
      return;
    }
    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
      if (user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2F3E),
      body: Stack(
        children: [
          const GlowyBackground(),
          
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 42, vertical: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 60, bottom: 40),
                    child: Text(
                      'Sign up',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF35E4C6),
                        fontFamily: 'LexendDeca',
                        fontWeight: FontWeight.w800,
                        fontSize: 40,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Username
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Username',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'Lexend Deca',
                                ),
                              ),
                            ),
                            SizedBox(height: 8), 
                            CustomTextField(
                              hintText: 'Username',
                              controller: _nameController,
                              obscureText: false,
                            ),
                            SizedBox(height: 20),

                            // E-mail
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'E-mail',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'Lexend Deca',
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            CustomTextField(
                              hintText: 'E-mail',
                              controller: _emailController,
                              obscureText: false,
                            ),
                            SizedBox(height: 20),

                            // Password
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'Lexend Deca',
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            CustomTextField(
                              hintText: 'Password',
                              controller: _passwordController,
                              obscureText: true,
                            ),
                            SizedBox(height: 20),

                            // Confirm password
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Confirm password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontFamily: 'Lexend Deca',
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            CustomTextField(
                              hintText: 'Confirm password',
                              controller: _confirmPasswordController,
                              obscureText: true,
                            ),
                            
                            SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // --- CHANGE HERE ---
                  // Wrapped in Center so it doesn't stretch to full width
                  Center( 
                    child: CustomButton(
                      text: 'Sign Up',
                      onPressed: _isLoading ? null : _signUp,
                      width: 300, // Now this width (100) will actually work
                      height: 51,
                      fontSize: 19,
                      backgroundColor: Color(0xFF7550FF),
                    ),
                  ),
                  // -------------------

                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Already have an account? Sign In',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'LexendDeca',
                          fontSize: 14,
                          fontWeight: FontWeight.w400, 
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}