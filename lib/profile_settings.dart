import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsProfileScreen extends StatefulWidget {
  const SettingsProfileScreen({super.key});

  @override
  State<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends State<SettingsProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyName = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _gst = TextEditingController();
  final TextEditingController _pan = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _stateCode = TextEditingController();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _email = TextEditingController();
  List<Map<String, TextEditingController>> _bankAccounts = [];
  File? _signature;
  Database? _db;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
    _initDb().then((_) => _loadData());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _companyName.dispose();
    _address.dispose();
    _gst.dispose();
    _pan.dispose();
    _state.dispose();
    _stateCode.dispose();
    _mobile.dispose();
    _email.dispose();
    for (final acc in _bankAccounts) {
      acc['name']!.dispose();
      acc['number']!.dispose();
    }
    _db?.close();
    super.dispose();
  }

  Future<void> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'company_settings.db');
    _db = await openDatabase(path, version: 2, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE settings (
          id INTEGER PRIMARY KEY,
          companyName TEXT,
          address TEXT,
          gst TEXT,
          pan TEXT,
          state TEXT,
          stateCode TEXT,
          mobile TEXT,
          email TEXT,
          signaturePath TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE bank_accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          accountName TEXT,
          accountNumber TEXT
        )
      ''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        // Add mobile and email columns if upgrading from version 1
        await db.execute('ALTER TABLE settings ADD COLUMN mobile TEXT');
        await db.execute('ALTER TABLE settings ADD COLUMN email TEXT');
      }
    });
  }

  Future<void> _loadData() async {
    final settings = await _db!.query('settings', limit: 1);
    if (settings.isNotEmpty) {
      final s = settings.first;
      _companyName.text = (s['companyName'] ?? '') as String;
      _address.text = (s['address'] ?? '') as String;
      _gst.text = (s['gst'] ?? '') as String;
      _pan.text = (s['pan'] ?? '') as String;
      _state.text = (s['state'] ?? '') as String;
      _stateCode.text = (s['stateCode'] ?? '') as String;
      _mobile.text = (s['mobile'] ?? '') as String;
      _email.text = (s['email'] ?? '') as String;
      if (s['signaturePath'] != null) {
        _signature = File(s['signaturePath'] as String);
      }
    }

    final bankRows = await _db!.query('bank_accounts');
    _bankAccounts = bankRows.map((row) {
      return {
        'name': TextEditingController(text: (row['accountName'] ?? '') as String),
        'number': TextEditingController(text: (row['accountNumber'] ?? '') as String),
      };
    }).toList();

    if (_bankAccounts.isEmpty) {
      _bankAccounts.add({'name': TextEditingController(), 'number': TextEditingController()});
    }

    setState(() {});
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await _db!.delete('settings');
    await _db!.insert('settings', {
      'companyName': _companyName.text,
      'address': _address.text,
      'gst': _gst.text,
      'pan': _pan.text,
      'state': _state.text,
      'stateCode': _stateCode.text,
      'mobile': _mobile.text,
      'email': _email.text,
      'signaturePath': _signature?.path,
    });

    await _db!.delete('bank_accounts');
    for (final account in _bankAccounts) {
      if (account['name']!.text.trim().isNotEmpty || account['number']!.text.trim().isNotEmpty) {
        await _db!.insert('bank_accounts', {
          'accountName': account['name']!.text,
          'accountNumber': account['number']!.text,
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Company profile saved successfully",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickSignature() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedPath = p.join(appDir.path, fileName);
      final savedFile = await File(image.path).copy(savedPath);
      setState(() {
        _signature = savedFile;
      });
    }
  }

  void _addBankAccount() {
    setState(() {
      _bankAccounts.add({
        'name': TextEditingController(),
        'number': TextEditingController(),
      });
    });
  }

  void _removeBankAccount(int index) {
    setState(() {
      _bankAccounts[index]['name']!.dispose();
      _bankAccounts[index]['number']!.dispose();
      _bankAccounts.removeAt(index);
    });
  }

  Widget _buildTextField(TextEditingController controller, String label, {
    bool isRequired = false, 
    TextInputType? keyboardType,
    String? Function(String?)? validator
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: GoogleFonts.poppins(fontSize: 16),
        validator: validator ?? (isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter $label';
                }
                return null;
              }
            : null),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Email is optional
    }
    
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Mobile is optional
    }
    
    final mobileRegExp = RegExp(r'^[6-9]\d{9}$');
    if (!mobileRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }

  Widget _buildBankAccountCard(int index, Map<String, TextEditingController> account) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bank Account ${index + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeBankAccount(index),
                    tooltip: 'Remove Account',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTextField(account['name']!, 'Bank Name', isRequired: true),
              _buildTextField(account['number']!, 'Account Number', isRequired: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Authorized Signature",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _signature != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _signature!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: Center(
                        child: Text(
                          "No signature selected",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _pickSignature,
                  icon: const Icon(Icons.upload, size: 20),
                  label: Text(
                    "Upload Signature",
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Company Settings',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveData,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: _db == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.all(isWideScreen ? 32 : 16),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Company Details Section
                        Card(
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.grey[50]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Company Details",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  isWideScreen
                                      ? Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  _buildTextField(_companyName, 'Company Name', isRequired: true),
                                                  _buildTextField(_address, 'Address', isRequired: true),
                                                  _buildTextField(_gst, 'GST Number'),
                                                  _buildTextField(_mobile, 'Mobile Number', 
                                                    keyboardType: TextInputType.phone,
                                                    validator: _validateMobile),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  _buildTextField(_pan, 'PAN Number'),
                                                  _buildTextField(_state, 'State', isRequired: true),
                                                  _buildTextField(_stateCode, 'State Code'),
                                                  _buildTextField(_email, 'Email Address', 
                                                    keyboardType: TextInputType.emailAddress,
                                                    validator: _validateEmail),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            _buildTextField(_companyName, 'Company Name', isRequired: true),
                                            _buildTextField(_address, 'Address', isRequired: true),
                                            _buildTextField(_gst, 'GST Number'),
                                            _buildTextField(_pan, 'PAN Number'),
                                            _buildTextField(_state, 'State', isRequired: true),
                                            _buildTextField(_stateCode, 'State Code'),
                                            _buildTextField(_mobile, 'Mobile Number', 
                                              keyboardType: TextInputType.phone,
                                              validator: _validateMobile),
                                            _buildTextField(_email, 'Email Address', 
                                              keyboardType: TextInputType.emailAddress,
                                              validator: _validateEmail),
                                          ],
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Bank Accounts Section
                        Text(
                          "Bank Accounts",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._bankAccounts.asMap().entries.map((entry) {
                          return _buildBankAccountCard(entry.key, entry.value);
                        }),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addBankAccount,
                            icon: const Icon(Icons.add_circle, color: Color(0xFF3B82F6)),
                            label: Text(
                              "Add Bank Account",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Signature Section
                        _buildSignatureSection(),
                        const SizedBox(height: 24),
                        // Save Button
                        Center(
                          child: ElevatedButton(
                            onPressed: _saveData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              elevation: 4,
                            ),
                            child: Text(
                              'Save Settings',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
    );
  }
}































// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;
// import 'package:sqflite/sqflite.dart';
// import 'package:google_fonts/google_fonts.dart';

// class SettingsProfileScreen extends StatefulWidget {
//   const SettingsProfileScreen({super.key});

//   @override
//   State<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
// }

// class _SettingsProfileScreenState extends State<SettingsProfileScreen>
//     with SingleTickerProviderStateMixin {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _companyName = TextEditingController();
//   final TextEditingController _address = TextEditingController();
//   final TextEditingController _gst = TextEditingController();
//   final TextEditingController _pan = TextEditingController();
//   final TextEditingController _state = TextEditingController();
//   final TextEditingController _stateCode = TextEditingController();
//   List<Map<String, TextEditingController>> _bankAccounts = [];
//   File? _signature;
//   Database? _db;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _fadeAnimation = CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOutCubic,
//     );
//     _animationController.forward();
//     _initDb().then((_) => _loadData());
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     _companyName.dispose();
//     _address.dispose();
//     _gst.dispose();
//     _pan.dispose();
//     _state.dispose();
//     _stateCode.dispose();
//     for (final acc in _bankAccounts) {
//       acc['name']!.dispose();
//       acc['number']!.dispose();
//     }
//     _db?.close();
//     super.dispose();
//   }

//   Future<void> _initDb() async {
//     final dir = await getApplicationDocumentsDirectory();
//     final path = p.join(dir.path, 'company_settings.db');
//     _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
//       await db.execute('''
//         CREATE TABLE settings (
//           id INTEGER PRIMARY KEY,
//           companyName TEXT,
//           address TEXT,
//           gst TEXT,
//           pan TEXT,
//           state TEXT,
//           stateCode TEXT,
//           signaturePath TEXT
//         )
//       ''');
//       await db.execute('''
//         CREATE TABLE bank_accounts (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           accountName TEXT,
//           accountNumber TEXT
//         )
//       ''');
//     });
//   }

//   Future<void> _loadData() async {
//     final settings = await _db!.query('settings', limit: 1);
//     if (settings.isNotEmpty) {
//       final s = settings.first;
//       _companyName.text = (s['companyName'] ?? '') as String;
//       _address.text = (s['address'] ?? '') as String;
//       _gst.text = (s['gst'] ?? '') as String;
//       _pan.text = (s['pan'] ?? '') as String;
//       _state.text = (s['state'] ?? '') as String;
//       _stateCode.text = (s['stateCode'] ?? '') as String;
//       if (s['signaturePath'] != null) {
//         _signature = File(s['signaturePath'] as String);
//       }
//     }

//     final bankRows = await _db!.query('bank_accounts');
//     _bankAccounts = bankRows.map((row) {
//       return {
//         'name': TextEditingController(text: (row['accountName'] ?? '') as String),
//         'number': TextEditingController(text: (row['accountNumber'] ?? '') as String),
//       };
//     }).toList();

//     if (_bankAccounts.isEmpty) {
//       _bankAccounts.add({'name': TextEditingController(), 'number': TextEditingController()});
//     }

//     setState(() {});
//   }

//   Future<void> _saveData() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//     await _db!.delete('settings');
//     await _db!.insert('settings', {
//       'companyName': _companyName.text,
//       'address': _address.text,
//       'gst': _gst.text,
//       'pan': _pan.text,
//       'state': _state.text,
//       'stateCode': _stateCode.text,
//       'signaturePath': _signature?.path,
//     });

//     await _db!.delete('bank_accounts');
//     for (final account in _bankAccounts) {
//       if (account['name']!.text.trim().isNotEmpty || account['number']!.text.trim().isNotEmpty) {
//         await _db!.insert('bank_accounts', {
//           'accountName': account['name']!.text,
//           'accountNumber': account['number']!.text,
//         });
//       }
//     }

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           "Company profile saved successfully",
//           style: GoogleFonts.poppins(color: Colors.white),
//         ),
//         backgroundColor: Colors.green[600],
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ),
//     );
//   }

//   Future<void> _pickSignature() async {
//     final picker = ImagePicker();
//     final image = await picker.pickImage(source: ImageSource.gallery);
//     if (image != null) {
//       final appDir = await getApplicationDocumentsDirectory();
//       final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
//       final savedPath = p.join(appDir.path, fileName);
//       final savedFile = await File(image.path).copy(savedPath);
//       setState(() {
//         _signature = savedFile;
//       });
//     }
//   }

//   void _addBankAccount() {
//     setState(() {
//       _bankAccounts.add({
//         'name': TextEditingController(),
//         'number': TextEditingController(),
//       });
//     });
//   }

//   void _removeBankAccount(int index) {
//     setState(() {
//       _bankAccounts[index]['name']!.dispose();
//       _bankAccounts[index]['number']!.dispose();
//       _bankAccounts.removeAt(index);
//     });
//   }

//   Widget _buildTextField(TextEditingController controller, String label, {bool isRequired = false}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: TextFormField(
//         controller: controller,
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: BorderSide(color: Colors.grey[300]!),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: BorderSide(color: Colors.grey[300]!),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
//           ),
//           filled: true,
//           fillColor: Colors.white,
//           contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         ),
//         style: GoogleFonts.poppins(fontSize: 16),
//         validator: isRequired
//             ? (value) {
//                 if (value == null || value.trim().isEmpty) {
//                   return 'Please enter $label';
//                 }
//                 return null;
//               }
//             : null,
//       ),
//     );
//   }

//   Widget _buildBankAccountCard(int index, Map<String, TextEditingController> account) {
//     return Card(
//       elevation: 4,
//       shadowColor: Colors.black.withOpacity(0.1),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           gradient: LinearGradient(
//             colors: [Colors.white, Colors.grey[50]!],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Bank Account ${index + 1}',
//                     style: GoogleFonts.poppins(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.delete, color: Colors.red),
//                     onPressed: () => _removeBankAccount(index),
//                     tooltip: 'Remove Account',
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               _buildTextField(account['name']!, 'Bank Name', isRequired: true),
//               _buildTextField(account['number']!, 'Account Number', isRequired: true),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSignatureSection() {
//     return Card(
//       elevation: 4,
//       shadowColor: Colors.black.withOpacity(0.1),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           gradient: LinearGradient(
//             colors: [Colors.white, Colors.grey[50]!],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Authorized Signature",
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               _signature != null
//                   ? ClipRRect(
//                       borderRadius: BorderRadius.circular(8),
//                       child: Image.file(
//                         _signature!,
//                         height: 100,
//                         width: double.infinity,
//                         fit: BoxFit.contain,
//                       ),
//                     )
//                   : Container(
//                       height: 100,
//                       width: double.infinity,
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey[300]!),
//                         borderRadius: BorderRadius.circular(8),
//                         color: Colors.grey[50],
//                       ),
//                       child: Center(
//                         child: Text(
//                           "No signature selected",
//                           style: GoogleFonts.poppins(
//                             fontSize: 14,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       ),
//                     ),
//               const SizedBox(height: 12),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: ElevatedButton.icon(
//                   onPressed: _pickSignature,
//                   icon: const Icon(Icons.upload, size: 20),
//                   label: Text(
//                     "Upload Signature",
//                     style: GoogleFonts.poppins(fontSize: 14),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF3B82F6),
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isWideScreen = screenWidth > 600;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         title: Text(
//           'Company Settings',
//           style: GoogleFonts.poppins(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF1E3A8A),
//         elevation: 0,
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.save, color: Colors.white),
//             onPressed: _saveData,
//             tooltip: 'Save Settings',
//           ),
//         ],
//       ),
//       body: _db == null
//           ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
//           : FadeTransition(
//               opacity: _fadeAnimation,
//               child: Padding(
//                 padding: EdgeInsets.all(isWideScreen ? 32 : 16),
//                 child: Form(
//                   key: _formKey,
//                   child: SingleChildScrollView(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Company Details Section
//                         Card(
//                           elevation: 4,
//                           shadowColor: Colors.black.withOpacity(0.1),
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                           child: Container(
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(12),
//                               gradient: LinearGradient(
//                                 colors: [Colors.white, Colors.grey[50]!],
//                                 begin: Alignment.topLeft,
//                                 end: Alignment.bottomRight,
//                               ),
//                             ),
//                             child: Padding(
//                               padding: const EdgeInsets.all(20),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     "Company Details",
//                                     style: GoogleFonts.poppins(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.w600,
//                                       color: Colors.black87,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 16),
//                                   isWideScreen
//                                       ? Row(
//                                           crossAxisAlignment: CrossAxisAlignment.start,
//                                           children: [
//                                             Expanded(
//                                               child: Column(
//                                                 children: [
//                                                   _buildTextField(_companyName, 'Company Name', isRequired: true),
//                                                   _buildTextField(_address, 'Address', isRequired: true),
//                                                   _buildTextField(_gst, 'GST Number'),
//                                                 ],
//                                               ),
//                                             ),
//                                             const SizedBox(width: 16),
//                                             Expanded(
//                                               child: Column(
//                                                 children: [
//                                                   _buildTextField(_pan, 'PAN Number'),
//                                                   _buildTextField(_state, 'State', isRequired: true),
//                                                   _buildTextField(_stateCode, 'State Code'),
//                                                 ],
//                                               ),
//                                             ),
//                                           ],
//                                         )
//                                       : Column(
//                                           children: [
//                                             _buildTextField(_companyName, 'Company Name', isRequired: true),
//                                             _buildTextField(_address, 'Address', isRequired: true),
//                                             _buildTextField(_gst, 'GST Number'),
//                                             _buildTextField(_pan, 'PAN Number'),
//                                             _buildTextField(_state, 'State', isRequired: true),
//                                             _buildTextField(_stateCode, 'State Code'),
//                                           ],
//                                         ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 24),
//                         // Bank Accounts Section
//                         Text(
//                           "Bank Accounts",
//                           style: GoogleFonts.poppins(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.black87,
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         ..._bankAccounts.asMap().entries.map((entry) {
//                           return _buildBankAccountCard(entry.key, entry.value);
//                         }),
//                         const SizedBox(height: 12),
//                         Align(
//                           alignment: Alignment.centerLeft,
//                           child: TextButton.icon(
//                             onPressed: _addBankAccount,
//                             icon: const Icon(Icons.add_circle, color: Color(0xFF3B82F6)),
//                             label: Text(
//                               "Add Bank Account",
//                               style: GoogleFonts.poppins(
//                                 fontSize: 14,
//                                 color: const Color(0xFF3B82F6),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 24),
//                         // Signature Section
//                         _buildSignatureSection(),
//                         const SizedBox(height: 24),
//                         // Save Button
//                         Center(
//                           child: ElevatedButton(
//                             onPressed: _saveData,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: const Color(0xFF3B82F6),
//                               foregroundColor: Colors.white,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                               elevation: 4,
//                             ),
//                             child: Text(
//                               'Save Settings',
//                               style: GoogleFonts.poppins(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//     );
//   }
// }









// Originally, this file was intended to manage company settings and profile information.
// However, it has been replaced by a new implementation in the 'profile_settings.dart' file
// which provides a more comprehensive and user-friendly interface for managing company profiles.
// The new implementation includes features such as:
// - Company name, address, GST, PAN, state, and state code management
// - Bank account management with dynamic addition and removal of accounts
// - Signature upload functionality
// - Persistent storage using SQLite for data management




// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;
// import 'package:sqflite/sqflite.dart';

// class SettingsProfileScreen extends StatefulWidget {
//   const SettingsProfileScreen({super.key});

//   @override
//   State<SettingsProfileScreen> createState() => _SettingsProfileScreenState();
// }

// class _SettingsProfileScreenState extends State<SettingsProfileScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _companyName = TextEditingController();
//   final TextEditingController _address = TextEditingController();
//   final TextEditingController _gst = TextEditingController();
//   final TextEditingController _pan = TextEditingController();
//   final TextEditingController _state = TextEditingController();
//   final TextEditingController _stateCode = TextEditingController();
//   List<Map<String, TextEditingController>> _bankAccounts = [];
//   File? _signature;
//   Database? _db;

//   @override
//   void initState() {
//     super.initState();
//     _initDb().then((_) => _loadData());
//   }

//   Future<void> _initDb() async {
//     final dir = await getApplicationDocumentsDirectory();
//     final path = p.join(dir.path, 'company_settings.db');
//     _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
//       await db.execute('''
//         CREATE TABLE settings (
//           id INTEGER PRIMARY KEY,
//           companyName TEXT,
//           address TEXT,
//           gst TEXT,
//           pan TEXT,
//           state TEXT,
//           stateCode TEXT,
//           signaturePath TEXT
//         )
//       ''');

//       await db.execute('''
//         CREATE TABLE bank_accounts (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           accountName TEXT,
//           accountNumber TEXT
//         )
//       ''');
//     });
//   }

//   Future<void> _loadData() async {
//   final settings = await _db!.query('settings', limit: 1);
//   if (settings.isNotEmpty) {
//     final s = settings.first;
//     _companyName.text = (s['companyName'] ?? '') as String;
//     _address.text = (s['address'] ?? '') as String;
//     _gst.text = (s['gst'] ?? '') as String;
//     _pan.text = (s['pan'] ?? '') as String;
//     _state.text = (s['state'] ?? '') as String;
//     _stateCode.text = (s['stateCode'] ?? '') as String;

//     if (s['signaturePath'] != null) {
//       _signature = File(s['signaturePath'] as String);
//     }
//   }

//   final bankRows = await _db!.query('bank_accounts');
//   _bankAccounts = bankRows.map((row) {
//     return {
//       'name': TextEditingController(text: (row['accountName'] ?? '') as String),
//       'number': TextEditingController(text: (row['accountNumber'] ?? '') as String),
//     };
//   }).toList();

//   if (_bankAccounts.isEmpty) {
//     _bankAccounts.add({'name': TextEditingController(), 'number': TextEditingController()});
//   }

//   setState(() {});
// }


//   Future<void> _saveData() async {
//     await _db!.delete('settings');
//     await _db!.insert('settings', {
//       'companyName': _companyName.text,
//       'address': _address.text,
//       'gst': _gst.text,
//       'pan': _pan.text,
//       'state': _state.text,
//       'stateCode': _stateCode.text,
//       'signaturePath': _signature?.path,
//     });

//     await _db!.delete('bank_accounts');
//     for (final account in _bankAccounts) {
//       if (account['name']!.text.trim().isNotEmpty || account['number']!.text.trim().isNotEmpty) {
//         await _db!.insert('bank_accounts', {
//           'accountName': account['name']!.text,
//           'accountNumber': account['number']!.text,
//         });
//       }
//     }

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Company profile saved")),
//     );
//   }

//   Future<void> _pickSignature() async {
//     final picker = ImagePicker();
//     final image = await picker.pickImage(source: ImageSource.gallery);
//     if (image != null) {
//       final appDir = await getApplicationDocumentsDirectory();
//       final fileName = 'signature_${DateTime.now().millisecondsSinceEpoch}.png';
//       final savedPath = p.join(appDir.path, fileName);
//       final savedFile = await File(image.path).copy(savedPath);
//       setState(() {
//         _signature = savedFile;
//       });
//     }
//   }

//   void _addBankAccount() {
//     setState(() {
//       _bankAccounts.add({
//         'name': TextEditingController(),
//         'number': TextEditingController(),
//       });
//     });
//   }

//   void _removeBankAccount(int index) {
//     setState(() {
//       _bankAccounts.removeAt(index);
//     });
//   }

//   @override
//   void dispose() {
//     _companyName.dispose();
//     _address.dispose();
//     _gst.dispose();
//     _pan.dispose();
//     _state.dispose();
//     _stateCode.dispose();
//     for (final acc in _bankAccounts) {
//       acc['name']!.dispose();
//       acc['number']!.dispose();
//     }
//     _db?.close();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Company Settings/Profile'),
//         backgroundColor: const Color(0xFF2C3E50),
//       ),
//       body: _db == null
//           ? const Center(child: CircularProgressIndicator())
//           : Padding(
//               padding: const EdgeInsets.all(16),
//               child: Form(
//                 key: _formKey,
//                 child: ListView(
//                   children: [
//                     _buildTextField(_companyName, 'Company Name'),
//                     _buildTextField(_address, 'Address'),
//                     _buildTextField(_gst, 'GST Number'),
//                     _buildTextField(_pan, 'PAN Number'),
//                     _buildTextField(_state, 'State'),
//                     _buildTextField(_stateCode, 'State Code'),
//                     const SizedBox(height: 16),
//                     const Text("Bank Accounts", style: TextStyle(fontWeight: FontWeight.bold)),
//                     ..._bankAccounts.asMap().entries.map((entry) {
//                       final i = entry.key;
//                       final account = entry.value;
//                       return Card(
//                         margin: const EdgeInsets.symmetric(vertical: 8),
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             children: [
//                               _buildTextField(account['name']!, 'Bank Name'),
//                               _buildTextField(account['number']!, 'Account Number'),
//                               Align(
//                                 alignment: Alignment.centerRight,
//                                 child: IconButton(
//                                   icon: const Icon(Icons.delete, color: Colors.red),
//                                   onPressed: () => _removeBankAccount(i),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     }),
//                     TextButton.icon(
//                       onPressed: _addBankAccount,
//                       icon: const Icon(Icons.add),
//                       label: const Text("Add Bank Account"),
//                     ),
//                     const SizedBox(height: 16),
//                     const Text("Authorized Signature", style: TextStyle(fontWeight: FontWeight.bold)),
//                     const SizedBox(height: 8),
//                     _signature != null
//                         ? Image.file(_signature!, height: 100)
//                         : const Text("No signature selected"),
//                     TextButton(
//                       onPressed: _pickSignature,
//                       child: const Text("Upload Signature"),
//                     ),
//                     const SizedBox(height: 24),
//                     ElevatedButton(
//                       onPressed: _saveData,
//                       child: const Text('Save Settings'),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   Widget _buildTextField(TextEditingController controller, String label) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: TextFormField(
//         controller: controller,
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(),
//         ),
//       ),
//     );
//   }
// }
