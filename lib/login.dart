import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyapar/main.dart';
// import 'db_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _resetNewPasswordController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    _resetNewPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // String _hashPassword(String password) {
  //   final bytes = utf8.encode(password);
  //   final digest = sha256.convert(bytes);
  //   return digest.toString();
  // }

  
//   Future<void> _loginUser() async {
//   if (!_formKey.currentState!.validate()) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('Please fill all required fields correctly'),
//         backgroundColor: Colors.red[600],
//       ),
//     );
//     return;
//   }

//   try {
//     await FirebaseAuth.instance.signInWithEmailAndPassword(
//       email: _emailController.text.trim(),
//       password: _passwordController.text.trim(),
//     );

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('Login successful'),
//         backgroundColor: Colors.green[600],
//       ),
//     );
//     _clearForm();

//     // Navigate to dashboard or trial gate
//     Navigator.pushReplacementNamed(context, '/dashboard'); // or TrialScreen()
//   } on FirebaseAuthException catch (e) {
//     String message = 'Login failed';
//     if (e.code == 'user-not-found') {
//       message = 'No user found with this email';
//     } else if (e.code == 'wrong-password') {
//       message = 'Incorrect password';
//     }
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red[600]),
//     );
//   }
// }

Future<void> _loginUser() async {
  if (Platform.isLinux) {
    // Simulate user
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppDrawerWrapper()),
    );
    return;
  }

  try {
    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppDrawerWrapper()),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Login failed: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}




  void _showResetDialog() {
  showDialog(
    context: context,
    builder: (context) {
      final dialogFormKey = GlobalKey<FormState>();
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Reset Password', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Form(
          key: dialogFormKey,
          child: TextFormField(
            controller: _resetEmailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)
                  ? null
                  : 'Enter valid email';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _resetPassword(dialogFormKey),
            child: const Text('Send Reset Email'),
          ),
        ],
      );
    },
  );
}


  Future<void> _resetPassword(GlobalKey<FormState> dialogFormKey) async {
  if (!dialogFormKey.currentState!.validate()) return;

  final email = _resetEmailController.text.trim();

  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Password reset email sent'),
        backgroundColor: Colors.green[600],
      ),
    );
  } on FirebaseAuthException catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message ?? 'Failed to send reset email'),
        backgroundColor: Colors.red[600],
      ),
    );
  }

  _resetEmailController.clear();
  _resetNewPasswordController.clear();
}


  void _clearForm() {
    _formKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();
    setState(() => _isPasswordVisible = false);
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: suffixIcon,
        ),
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14),
        keyboardType: keyboardType,
        obscureText: obscureText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'User Login',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _clearForm,
            tooltip: 'Reset Form',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWideScreen ? 32 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign In',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          controller: _emailController,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Required';
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            return emailRegex.hasMatch(v.trim()) ? null : 'Enter valid email';
                          },
                        ),
                        _buildFormField(
                          controller: _passwordController,
                          label: 'Password',
                          obscureText: !_isPasswordVisible,
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Required';
                            if (v.length < 6) return 'Minimum 6 characters';
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey[600],
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _showResetDialog,
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.poppins(color: Colors.grey[600]),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Login',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



















// import 'package:flutter/material.dart';
// import 'db_helper.dart';
// import 'package:crypto/crypto.dart';
// import 'dart:convert';

// class LoginScreen extends StatefulWidget {
//   @override
//   _LoginScreenState createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _resetEmailController = TextEditingController();
//   final _resetNewPasswordController = TextEditingController();

//   String _hashPassword(String password) {
//     final bytes = utf8.encode(password);
//     final digest = sha256.convert(bytes);
//     return digest.toString();
//   }

//   Future<void> _loginUser() async {
//     if (!_formKey.currentState!.validate()) return;

//     final db = await DBHelper().database;
//     final hashed = _hashPassword(_passwordController.text);

//     final user = await db.query(
//       'users',
//       where: 'email = ? AND password = ?',
//       whereArgs: [_emailController.text.trim(), hashed],
//     );

//     if (user.isNotEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login successful.')));
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid credentials.')));
//     }
//   }

//   void _showResetDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Reset Password'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(controller: _resetEmailController, decoration: InputDecoration(labelText: 'Email')),
//             TextField(controller: _resetNewPasswordController, decoration: InputDecoration(labelText: 'New Password')),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: _resetPassword, child: Text('Reset')),
//         ],
//       ),
//     );
//   }

//   Future<void> _resetPassword() async {
//     final email = _resetEmailController.text.trim();
//     final newPass = _resetNewPasswordController.text.trim();
//     if (email.isEmpty || newPass.length < 6) return;

//     final db = await DBHelper().database;
//     final hashed = _hashPassword(newPass);

//     final user = await db.query('users', where: 'email = ?', whereArgs: [email]);
//     if (user.isEmpty) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not found.')));
//       return;
//     }

//     await db.update('users', {'password': hashed}, where: 'email = ?', whereArgs: [email]);
//     Navigator.pop(context);
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset successfully.')));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('User Login')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _emailController,
//                 decoration: InputDecoration(labelText: 'Email'),
//                 validator: (value) => value!.contains('@') ? null : 'Enter valid email',
//               ),
//               TextFormField(
//                 controller: _passwordController,
//                 decoration: InputDecoration(labelText: 'Password'),
//                 obscureText: true,
//                 validator: (value) => value!.length < 6 ? 'Min 6 characters' : null,
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(onPressed: _loginUser, child: Text('Login')),
//               TextButton(onPressed: _showResetDialog, child: Text('Forgot Password?')),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
