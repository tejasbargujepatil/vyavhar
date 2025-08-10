import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'Dashboard.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields correctly'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: _passwordController.text.trim(),
          );

      // Update display name
      await credential.user?.updateDisplayName(name);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Registration successful! Welcome to CIS Solutions'),
          backgroundColor: Colors.green[600],
        ),
      );

      _clearForm();
      
      // Navigate directly to Dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const Dashboard()),
      );

    } on FirebaseAuthException catch (e) {
      String error = 'Registration failed';
      if (e.code == 'email-already-in-use') {
        error = 'Email already registered';
      } else if (e.code == 'weak-password') {
        error = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        error = 'Invalid email address';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error), 
          backgroundColor: Colors.red[600]
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: Colors.red[600],
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _isPasswordVisible = false;
    });
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
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 2),
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
          'User Registration',
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
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFFAFBFC)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C3E50).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Icon(
                                    Icons.person_add,
                                    size: 40,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Create New Account',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Join CIS Solutions ERP System',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Form Fields
                          _buildFormField(
                            controller: _nameController,
                            label: 'Full Name',
                            validator: (v) {
                              if (v!.trim().isEmpty) return 'Name is required';
                              if (v.trim().length < 2) return 'Name must be at least 2 characters';
                              return null;
                            },
                          ),
                          _buildFormField(
                            controller: _emailController,
                            label: 'Email Address',
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v!.trim().isEmpty) return 'Email is required';
                              final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              return emailRegex.hasMatch(v.trim())
                                  ? null
                                  : 'Enter a valid email address';
                            },
                          ),
                          _buildFormField(
                            controller: _passwordController,
                            label: 'Password',
                            obscureText: !_isPasswordVisible,
                            validator: (v) {
                              if (v!.trim().isEmpty) return 'Password is required';
                              if (v.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey[600],
                              ),
                              onPressed: () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _clearForm,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF2C3E50)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: Text(
                                    'Clear',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF2C3E50),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _registerUser,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C3E50),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'Create Account',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Login Link
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: 'Already have an account? ',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    const TextSpan(
                                      text: 'Sign In',
                                      style: TextStyle(
                                        color: Color(0xFF2C3E50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
      ),
    );
  }
}










// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:crypto/crypto.dart';
// import 'dart:convert';
// // import 'db_helper.dart';
// import 'trial.dart'; // <-- import your TrialScreen
// import 'package:shared_preferences/shared_preferences.dart';
// import 'Dashboard.dart'; // <-- import your DashboardScreen

// // TODO: import your dashboard/home screen widget
// // import 'dashboard_screen.dart';

// class RegistrationScreen extends StatefulWidget {
//   const RegistrationScreen({super.key});

//   @override
//   _RegistrationScreenState createState() => _RegistrationScreenState();
// }

// class _RegistrationScreenState extends State<RegistrationScreen>
//     with SingleTickerProviderStateMixin {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   bool _isPasswordVisible = false;

//   // NEW: free trial toggle
//   bool _startTrial = true;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _fadeAnimation = CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     );
//     _animationController.forward();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }

//   String _hashPassword(String password) {
//     final bytes = utf8.encode(password);
//     final digest = sha256.convert(bytes);
//     return digest.toString();
//   }

//   /// Called after a successful registration submission.
//   Future<void> _registerUser() async {
//     if (!_formKey.currentState!.validate()) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Please fill all required fields correctly'),
//           backgroundColor: Colors.red[600],
//         ),
//       );
//       return;
//     }

//     final name = _nameController.text.trim();
//     final email = _emailController.text.trim().toLowerCase();
//     final pwdHashed = _hashPassword(_passwordController.text.trim());

//     try {
//   final credential = await FirebaseAuth.instance
//       .createUserWithEmailAndPassword(
//         email: email,
//         password: _passwordController.text.trim(),
//       );

//   // Optional: Update display name
//   await credential.user?.updateDisplayName(name);

//   // Store trial info locally if opted
//   if (_startTrial) {
//     final prefs = await SharedPreferences.getInstance();
//     prefs.setString('trial_start_date', DateTime.now().toIso8601String());
//     prefs.setBool('paid_user', false);
//   }

//   // Navigate to trial screen
//   _goToTrialGate();

// } on FirebaseAuthException catch (e) {
//   String error = 'Registration failed';
//   if (e.code == 'email-already-in-use') {
//     error = 'Email already registered';
//   } else if (e.code == 'weak-password') {
//     error = 'Password is too weak';
//   }
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text(error), backgroundColor: Colors.red[600]),
//   );
// }


//     // If trial toggle ON, record start date & mark not paid_user (trial)
//     if (_startTrial) {
//       final prefs = await SharedPreferences.getInstance();
//       // only set if not already set (avoid overwriting existing trial)
//       prefs.setString('trial_start_date',
//           DateTime.now().toIso8601String()); // start trial now
//       prefs.setBool('paid_user', false);
//     }

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('Registration successful'),
//         backgroundColor: Colors.green[600],
//       ),
//     );

//     _clearForm();

//     // Navigate to trial gate (which will auto-grant if trial active)
//     _goToTrialGate();
//   }

//   /// Navigate to the TrialScreen. If trial was set just now, user will be let in.
//   void _goToTrialGate() {
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(
//         builder: (_) => TrialScreen(
//           onAccessGranted: _goToDashboard,
//           // if you want to *prevent* TrialScreen from auto-starting trial,
//           // add a param there and use _startTrial to control.
//         ),
//       ),
//     );
//   }

//   /// Replace with your dashboard navigation.
//   void _goToDashboard() {
//     // Example:
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(builder: (_) => const Dashboard()),
//     );
//     // For now just show message:
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Access granted! Navigate to dashboard here.')),
//     );
//   }

//   void _clearForm() {
//     _formKey.currentState?.reset();
//     _nameController.clear();
//     _emailController.clear();
//     _passwordController.clear();
//     setState(() {
//       _isPasswordVisible = false;
//       _startTrial = true; // reset toggle to default ON
//     });
//   }

//   Widget _buildFormField({
//     required TextEditingController controller,
//     required String label,
//     String? Function(String?)? validator,
//     TextInputType? keyboardType,
//     bool obscureText = false,
//     Widget? suffixIcon,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: TextFormField(
//         controller: controller,
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           suffixIcon: suffixIcon,
//         ),
//         validator: validator,
//         style: GoogleFonts.poppins(fontSize: 14),
//         keyboardType: keyboardType,
//         obscureText: obscureText,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isWideScreen = screenWidth > 600;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         title: Text(
//           'User Registration',
//           style: GoogleFonts.poppins(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF2C3E50),
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh, color: Colors.white),
//             onPressed: _clearForm,
//             tooltip: 'Reset Form',
//           ),
//         ],
//       ),
//       body: FadeTransition(
//         opacity: _fadeAnimation,
//         child: SingleChildScrollView(
//           padding: EdgeInsets.all(isWideScreen ? 32 : 16),
//           child: Center(
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 500),
//               child: Card(
//                 elevation: 4,
//                 shape:
//                     RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(24),
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Create New Account',
//                           style: GoogleFonts.poppins(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.black87,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         _buildFormField(
//                           controller: _nameController,
//                           label: 'Name',
//                           validator: (v) => v!.trim().isEmpty ? 'Required' : null,
//                         ),
//                         _buildFormField(
//                           controller: _emailController,
//                           label: 'Email',
//                           keyboardType: TextInputType.emailAddress,
//                           validator: (v) {
//                             if (v!.trim().isEmpty) return 'Required';
//                             final emailRegex = RegExp(
//                                 r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
//                             return emailRegex.hasMatch(v.trim())
//                                 ? null
//                                 : 'Enter valid email';
//                           },
//                         ),
//                         _buildFormField(
//                           controller: _passwordController,
//                           label: 'Password',
//                           obscureText: !_isPasswordVisible,
//                           validator: (v) {
//                             if (v!.trim().isEmpty) return 'Required';
//                             if (v.length < 6) return 'Minimum 6 characters';
//                             return null;
//                           },
//                           suffixIcon: IconButton(
//                             icon: Icon(
//                               _isPasswordVisible
//                                   ? Icons.visibility
//                                   : Icons.visibility_off,
//                               color: Colors.grey[600],
//                             ),
//                             onPressed: () => setState(
//                                 () => _isPasswordVisible = !_isPasswordVisible),
//                           ),
//                         ),

//                         const SizedBox(height: 16),

//                         /// NEW: Start Trial toggle
//                         SwitchListTile(
//                           title: Text(
//                             'Start 30-Day Free Trial Now',
//                             style: GoogleFonts.poppins(fontSize: 14),
//                           ),
//                           subtitle: Text(
//                             _startTrial
//                                 ? 'Trial will begin immediately after registration.'
//                                 : 'Trial not activated. You will need an unlock key.',
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                           value: _startTrial,
//                           onChanged: (val) {
//                             setState(() => _startTrial = val);
//                           },
//                           activeColor: const Color(0xFF2C3E50),
//                         ),

                        

//                         const SizedBox(height: 24),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             TextButton(
//                               onPressed: _clearForm,
//                               child: Text('Clear',
//                                   style: GoogleFonts.poppins(color: Colors.grey[600])),
//                             ),
//                             const SizedBox(width: 8),
//                             ElevatedButton(
//                               onPressed: _registerUser,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFF2C3E50),
//                                 shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12)),
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 24, vertical: 12),
//                               ),
//                               child: Text(
//                                 'Register',
//                                 style: GoogleFonts.poppins(
//                                     color: Colors.white, fontSize: 14),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }


// This code is a complete registration screen for a Flutter application.
// It includes form validation, password hashing, and an option to start a trial period.


































// import 'package:flutter/material.dart';
// import 'db_helper.dart';
// import 'package:crypto/crypto.dart';
// import 'dart:convert';

// class RegistrationScreen extends StatefulWidget {
//   @override
//   _RegistrationScreenState createState() => _RegistrationScreenState();
// }

// class _RegistrationScreenState extends State<RegistrationScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();

//   String _hashPassword(String password) {
//     final bytes = utf8.encode(password);
//     final digest = sha256.convert(bytes);
//     return digest.toString();
//   }

//   Future<void> _registerUser() async {
//     if (!_formKey.currentState!.validate()) return;

//     final hashedPassword = _hashPassword(_passwordController.text);
//     final db = await DBHelper().database;

//     final existing = await db.query(
//       'users',
//       where: 'email = ?',
//       whereArgs: [_emailController.text.trim()],
//     );

//     if (existing.isNotEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Email already registered.')),
//       );
//       return;
//     }

//     await db.insert('users', {
//       'name': _nameController.text.trim(),
//       'email': _emailController.text.trim(),
//       'password': hashedPassword,
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Registration Successful!')),
//     );

//     _formKey.currentState!.reset();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('User Registration')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _nameController,
//                 decoration: InputDecoration(labelText: 'Name'),
//                 validator: (value) => value!.isEmpty ? 'Enter name' : null,
//               ),
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
//               ElevatedButton(
//                 onPressed: _registerUser,
//                 child: Text('Register'),
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }