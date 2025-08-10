import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  _EmployeeManagementScreenState createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dojController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  int? _editingId;
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
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _dojController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadEmployees();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dojController.dispose();
    _ageController.dispose();
    _designationController.dispose();
    _salaryController.dispose();
    _contactController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final db = await DBHelper().database;
    final data = await db.query('employees', orderBy: 'name ASC');
    setState(() => _employees = data);
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill all required fields'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final db = await DBHelper().database;
    final employee = {
      'name': _nameController.text.trim(),
      'joining_date': _dojController.text.trim(),
      'age': int.tryParse(_ageController.text) ?? 0,
      'role': _designationController.text.trim(),
      'salary': double.tryParse(_salaryController.text) ?? 0,
      'contact': _contactController.text.trim(),
    };

    if (_editingId == null) {
      await db.insert('employees', employee);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Employee added successfully'),
          backgroundColor: Colors.green[600],
        ),
      );
    } else {
      await db.update('employees', employee, where: 'id = ?', whereArgs: [_editingId]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Employee updated successfully'),
          backgroundColor: Colors.green[600],
        ),
      );
    }

    _clearForm();
    await _loadEmployees();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _dojController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _ageController.clear();
    _designationController.clear();
    _salaryController.clear();
    _contactController.clear();
    _editingId = null;
    setState(() {});
  }

  void _editEmployee(Map<String, dynamic> emp) {
    _nameController.text = emp['name'] ?? '';
    _dojController.text = emp['joining_date'] ?? '';
    _ageController.text = emp['age']?.toString() ?? '';
    _designationController.text = emp['role'] ?? '';
    _salaryController.text = emp['salary']?.toString() ?? '';
    _contactController.text = emp['contact'] ?? '';
    _editingId = emp['id'];
    setState(() {});
  }

  Future<void> _deleteEmployee(int id) async {
    final db = await DBHelper().database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Employee deleted successfully'),
        backgroundColor: Colors.red[600],
      ),
    );
    await _loadEmployees();
  }

  Future<void> _assignLeave(int employeeId) async {
    final TextEditingController leaveDate = TextEditingController();
    final TextEditingController reason = TextEditingController();
    final formKey = GlobalKey<FormState>();
    leaveDate.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Assign Leave', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFormField(
                controller: leaveDate,
                label: 'Leave Date (yyyy-MM-dd)',
                validator: (value) => value!.trim().isEmpty ? 'Required' : null,
              ),
              _buildFormField(
                controller: reason,
                label: 'Reason',
                validator: (value) => value!.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final db = await DBHelper().database;
              await db.insert('leaves', {
                'employee_id': employeeId,
                'leave_date': leaveDate.text.trim(),
                'reason': reason.text.trim(),
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Leave assigned successfully'),
                  backgroundColor: Colors.green[600],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C3E50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Assign', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<int> _getLeaveCount(int empId) async {
    final db = await DBHelper().database;
    final leaves = await db.rawQuery('SELECT COUNT(*) as total FROM leaves WHERE employee_id = ?', [empId]);
    return leaves.first['total'] != null ? leaves.first['total'] as int : 0;
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
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
        ),
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14),
        keyboardType: keyboardType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 1 : screenWidth < 900 ? 2 : 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Employee Management',
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
            onPressed: () {
              _clearForm();
              _loadEmployees();
            },
            tooltip: 'Reset Form & Refresh',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingId == null ? 'Add New Employee' : 'Edit Employee',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          controller: _nameController,
                          label: 'Employee Name',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _dojController,
                          label: 'Date of Joining',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _ageController,
                          label: 'Age',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.trim().isEmpty || int.tryParse(v) == null || int.parse(v) <= 0 ? 'Valid age required' : null,
                        ),
                        _buildFormField(
                          controller: _designationController,
                          label: 'Designation',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _salaryController,
                          label: 'Salary',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.trim().isEmpty || double.tryParse(v) == null || double.parse(v) < 0 ? 'Valid salary required' : null,
                        ),
                        _buildFormField(
                          controller: _contactController,
                          label: 'Contact',
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Required';
                            final phoneRegex = RegExp(r'^\+?\d{10,12}$');
                            return phoneRegex.hasMatch(v.trim()) ? null : 'Invalid phone number';
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_editingId != null)
                              TextButton(
                                onPressed: _clearForm,
                                child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600])),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _saveEmployee,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                _editingId == null ? 'Add Employee' : 'Update Employee',
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
              const SizedBox(height: 24),
              Text(
                'Employee List',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2,
                ),
                itemCount: _employees.length,
                itemBuilder: (context, index) {
                  final emp = _employees[index];
                  return FutureBuilder<int>(
                    future: _getLeaveCount(emp['id']),
                    builder: (context, snapshot) {
                      final leaveCount = snapshot.data ?? 0;
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      emp['name'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _editEmployee(emp),
                                        tooltip: 'Edit Employee',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteEmployee(emp['id']),
                                        tooltip: 'Delete Employee',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.beach_access, color: Colors.green),
                                        onPressed: () => _assignLeave(emp['id']),
                                        tooltip: 'Assign Leave',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                'Role: ${emp['role']} | Leaves: $leaveCount',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                'Salary: ₹${emp['salary'].toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}































// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'db_helper.dart';

// class EmployeeManagementScreen extends StatefulWidget {
//   @override
//   _EmployeeManagementScreenState createState() => _EmployeeManagementScreenState();
// }

// class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _dojController = TextEditingController();
//   final _ageController = TextEditingController();
//   final _designationController = TextEditingController();
//   final _salaryController = TextEditingController();
//   final _contactController = TextEditingController();

//   List<Map<String, dynamic>> _employees = [];
//   int? _editingId;

//   @override
//   void initState() {
//     super.initState();
//     _dojController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     _loadEmployees();
//   }

//   Future<void> _loadEmployees() async {
//     final db = await DBHelper().database;
//     final data = await db.query('employees');
//     setState(() => _employees = data);
//   }

//   Future<void> _saveEmployee() async {
//     if (!_formKey.currentState!.validate()) return;
//     final db = await DBHelper().database;

//     final employee = {
//       'name': _nameController.text,
//       'joining_date': _dojController.text,
//       'age': int.tryParse(_ageController.text) ?? 0,
//       'role': _designationController.text,
//       'salary': double.tryParse(_salaryController.text) ?? 0,
//       'contact': _contactController.text,
//     };

//     if (_editingId == null) {
//       await db.insert('employees', employee);
//     } else {
//       await db.update('employees', employee, where: 'id = ?', whereArgs: [_editingId]);
//     }

//     _formKey.currentState!.reset();
//     _dojController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     _editingId = null;
//     _loadEmployees();
//   }

//   void _editEmployee(Map<String, dynamic> emp) {
//     _nameController.text = emp['name'];
//     _dojController.text = emp['joining_date'];
//     _ageController.text = emp['age'].toString();
//     _designationController.text = emp['role'];
//     _salaryController.text = emp['salary'].toString();
//     _contactController.text = emp['contact'];
//     _editingId = emp['id'];
//     setState(() {});
//   }

//   Future<void> _deleteEmployee(int id) async {
//     final db = await DBHelper().database;
//     await db.delete('employees', where: 'id = ?', whereArgs: [id]);
//     _loadEmployees();
//   }

//   void _assignLeave(int employeeId) {
//     final TextEditingController leaveDate = TextEditingController();
//     final TextEditingController reason = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Assign Leave'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: leaveDate,
//               decoration: InputDecoration(labelText: 'Leave Date (yyyy-MM-dd)'),
//             ),
//             TextField(
//               controller: reason,
//               decoration: InputDecoration(labelText: 'Reason'),
//             )
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () async {
//               final db = await DBHelper().database;
//               await db.insert('leaves', {
//                 'employee_id': employeeId,
//                 'leave_date': leaveDate.text,
//                 'reason': reason.text,
//               });
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leave Assigned')));
//             },
//             child: Text('Assign'),
//           )
//         ],
//       ),
//     );
//   }

//   Future<int> _getLeaveCount(int empId) async {
//     final db = await DBHelper().database;
//     final leaves = await db.rawQuery('SELECT COUNT(*) as total FROM leaves WHERE employee_id = ?', [empId]);
//     return leaves.first['total'] != null ? leaves.first['total'] as int : 0;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Employee Management')),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   TextFormField(controller: _nameController, decoration: InputDecoration(labelText: 'Employee Name'), validator: (v) => v!.isEmpty ? 'Enter name' : null),
//                   TextFormField(controller: _dojController, decoration: InputDecoration(labelText: 'Date of Joining')),
//                   TextFormField(controller: _ageController, decoration: InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
//                   TextFormField(controller: _designationController, decoration: InputDecoration(labelText: 'Designation')),
//                   TextFormField(controller: _salaryController, decoration: InputDecoration(labelText: 'Salary'), keyboardType: TextInputType.number),
//                   TextFormField(controller: _contactController, decoration: InputDecoration(labelText: 'Contact')),
//                   SizedBox(height: 10),
//                   ElevatedButton(
//                     onPressed: _saveEmployee,
//                     child: Text(_editingId == null ? 'Add Employee' : 'Update Employee'),
//                   ),
//                 ],
//               ),
//             ),
//             Divider(),
//             ListView.builder(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               itemCount: _employees.length,
//               itemBuilder: (context, index) {
//                 final emp = _employees[index];
//                 return FutureBuilder<int>(
//                   future: _getLeaveCount(emp['id']),
//                   builder: (context, snapshot) {
//                     final leaveCount = snapshot.data ?? 0;
//                     return ListTile(
//                       title: Text(emp['name']),
//                       subtitle: Text('Role: ${emp['role']} | Leaves: $leaveCount'),
//                       trailing: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           IconButton(icon: Icon(Icons.edit), onPressed: () => _editEmployee(emp)),
//                           IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteEmployee(emp['id'])),
//                           IconButton(icon: Icon(Icons.beach_access), onPressed: () => _assignLeave(emp['id'])),
//                         ],
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ],
//         ),

//       ),
//     );
//   }
// }
