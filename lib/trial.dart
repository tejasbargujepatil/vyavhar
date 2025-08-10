import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // For async operations



class TrialScreen extends StatefulWidget {
  final VoidCallback onAccessGranted;
  final bool startTrialIfMissing;

  const TrialScreen({
    super.key,
    required this.onAccessGranted,
    this.startTrialIfMissing = true,
  });

  @override
  _TrialScreenState createState() => _TrialScreenState();
}

class _TrialScreenState extends State<TrialScreen> with SingleTickerProviderStateMixin {
  DateTime? _startDate;
  bool _isExpired = false;
  bool _loading = true;
  final TextEditingController _adminKeyController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isPasswordVisible = false;

  final List<String> validAdminKeys = [
    'PREMIUM123',
    'UNLOCK456',
    'ACCESS789',
  ];

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
    _checkTrial();
  }

  @override
  void dispose() {
    _adminKeyController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Future<void> _checkTrial() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final start = prefs.getString('trial_start_date');
  //   final isPaid = prefs.getBool('paid_user') ?? false;

  //   if (isPaid) {
  //     widget.onAccessGranted();
  //     return;
  //   }

  //   if (start == null) {
  //     if (widget.startTrialIfMissing) {
  //       final now = DateTime.now();
  //       await prefs.setString('trial_start_date', now.toIso8601String());
  //       setState(() {
  //         _startDate = now;
  //         _isExpired = false;
  //         _loading = false;
  //       });
  //       widget.onAccessGranted();
  //       return;
  //     } else {
  //       setState(() {
  //         _isExpired = true;
  //         _loading = false;
  //       });
  //       return;
  //     }
  //   }

  //   final parsed = DateTime.parse(start);
  //   final difference = DateTime.now().difference(parsed).inDays;
  //   final expired = difference >= 30;

  //   setState(() {
  //     _startDate = parsed;
  //     _isExpired = expired;
  //     _loading = false;
  //   });

  //   if (!expired) {
  //     widget.onAccessGranted();
  //   }
  // }


  Future<void> _checkTrial() async {
  final prefs = await SharedPreferences.getInstance();
  final start = prefs.getString('trial_start_date');
  final isPaid = prefs.getBool('paid_user') ?? false;

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    debugPrint("Desktop detected. Skipping Firebase check.");
    widget.onAccessGranted(); // Simulate access for desktop dev
    return;
  }

  if (isPaid) {
    widget.onAccessGranted();
    return;
  }

  if (start == null) {
    if (widget.startTrialIfMissing) {
      final now = DateTime.now();
      await prefs.setString('trial_start_date', now.toIso8601String());
      setState(() {
        _startDate = now;
        _isExpired = false;
        _loading = false;
      });
      widget.onAccessGranted();
      return;
    } else {
      setState(() {
        _isExpired = true;
        _loading = false;
      });
      return;
    }
  }

  final parsed = DateTime.parse(start);
  final difference = DateTime.now().difference(parsed).inDays;
  final expired = difference >= 30;

  setState(() {
    _startDate = parsed;
    _isExpired = expired;
    _loading = false;
  });

  if (!expired) {
    widget.onAccessGranted();
  }
}


  Future<void> _validateKey() async {
    final key = _adminKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an unlock key'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    if (validAdminKeys.contains(key)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('paid_user', true);
      setState(() {
        _isExpired = false;
        _adminKeyController.clear();
        _isPasswordVisible = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Access unlocked successfully'),
          backgroundColor: Colors.green[600],
        ),
      );
      widget.onAccessGranted();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid unlock key'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  Widget _buildTrialInfo() {
    if (_startDate == null) return Container();

    final daysElapsed = DateTime.now().difference(_startDate!).inDays;
    final daysLeft = 30 - daysElapsed;
    final formattedStart = DateFormat('yyyy-MM-dd').format(_startDate!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Trial Started On: $formattedStart',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          _isExpired ? 'Trial expired after 30 days' : 'Trial Days Remaining: $daysLeft',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: _isExpired ? Colors.red[600] : Colors.green[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: _loading
              ? const CircularProgressIndicator(color: Color(0xFF2C3E50))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isWideScreen ? 32 : 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_clock,
                              size: 48,
                              color: Color(0xFF2C3E50),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Trial Access',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTrialInfo(),
                            if (_isExpired) ...[
                              Text(
                                'Enter admin unlock key:',
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              _buildFormField(
                                controller: _adminKeyController,
                                label: 'Unlock Key',
                                obscureText: !_isPasswordVisible,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      _adminKeyController.clear();
                                      setState(() => _isPasswordVisible = false);
                                    },
                                    child: Text('Clear', style: GoogleFonts.poppins(color: Colors.grey[600])),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _validateKey,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2C3E50),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    child: Text(
                                      'Unlock Access',
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
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
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';

// class TrialScreen extends StatefulWidget {
//   final VoidCallback onAccessGranted;
//   TrialScreen({required this.onAccessGranted});

//   @override
//   _TrialScreenState createState() => _TrialScreenState();
// }

// class _TrialScreenState extends State<TrialScreen> {
//   DateTime? _startDate;
//   bool _isExpired = false;
//   final _adminKeyController = TextEditingController();

//   final List<String> validAdminKeys = [
//     'PREMIUM123',
//     'UNLOCK456',
//     'ACCESS789'
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _checkTrial();
//   }

//   Future<void> _checkTrial() async {
//     final prefs = await SharedPreferences.getInstance();
//     final start = prefs.getString('trial_start_date');

//     if (start == null) {
//       final now = DateTime.now();
//       await prefs.setString('trial_start_date', now.toIso8601String());
//       setState(() => _startDate = now);
//       widget.onAccessGranted();
//     } else {
//       final parsed = DateTime.parse(start);
//       final difference = DateTime.now().difference(parsed).inDays;
//       setState(() {
//         _startDate = parsed;
//         _isExpired = difference >= 30;
//       });
//       if (!_isExpired) widget.onAccessGranted();
//     }
//   }

//   Future<void> _validateKey() async {
//     final key = _adminKeyController.text.trim();
//     if (validAdminKeys.contains(key)) {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('paid_user', true);
//       setState(() => _isExpired = false);
//       widget.onAccessGranted();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Invalid unlock key.')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: _isExpired
//             ? Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text('Trial expired after 30 days.',
//                         style: TextStyle(fontSize: 18, color: Colors.red)),
//                     SizedBox(height: 12),
//                     Text('Enter admin unlock password:'),
//                     TextField(
//                       controller: _adminKeyController,
//                       decoration: InputDecoration(hintText: 'Enter key'),
//                     ),
//                     SizedBox(height: 12),
//                     ElevatedButton(
//                       onPressed: _validateKey,
//                       child: Text('Unlock Access'),
//                     )
//                   ],
//                 ),
//               )
//             : CircularProgressIndicator(),
//       ),
//     );
//   }
// }
