import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class ExpenseManagementScreen extends StatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  _ExpenseManagementScreenState createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _employeeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _approvedByController = TextEditingController();
  final TextEditingController _expenseDateController = TextEditingController();
  String _expenseType = 'Travel';
  String _paymentMode = 'Cash';
  List<Map<String, dynamic>> _expenses = [];
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
    _expenseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadExpenses();
  }

  @override
  void dispose() {
    _employeeController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _approvedByController.dispose();
    _expenseDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    final db = await DBHelper().database;
    final data = await db.query('expenses', orderBy: 'date DESC');
    setState(() {
      _expenses = data;
    });
  }

  Future<void> _saveExpense() async {
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
    await db.insert('expenses', {
      'employee_name': _employeeController.text.trim(),
      'expense_type': _expenseType,
      'category': _descriptionController.text.trim(),
      'amount': double.tryParse(_amountController.text) ?? 0,
      'approved_by': _approvedByController.text.trim(),
      'date': _expenseDateController.text.trim(),
      'mode': _paymentMode,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Expense added successfully'),
        backgroundColor: Colors.green[600],
      ),
    );

    _clearForm();
    await _loadExpenses();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _employeeController.clear();
    _descriptionController.clear();
    _amountController.clear();
    _approvedByController.clear();
    _expenseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    setState(() {
      _expenseType = 'Travel';
      _paymentMode = 'Cash';
    });
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
          'Expense Management',
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
              _loadExpenses();
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
                          'Add New Expense',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          controller: _employeeController,
                          label: 'Employee Name (Optional)',
                        ),
                        DropdownButtonFormField<String>(
                          value: _expenseType,
                          items: ['Travel', 'Maintenance', 'Utility', 'Office', 'Misc']
                              .map((type) => DropdownMenuItem(value: type, child: Text(type, style: GoogleFonts.poppins(fontSize: 14))))
                              .toList(),
                          onChanged: (val) => setState(() => _expenseType = val!),
                          decoration: InputDecoration(
                            labelText: 'Expense Type',
                            labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        _buildFormField(
                          controller: _descriptionController,
                          label: 'Description',
                          validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _amountController,
                          label: 'Amount',
                          keyboardType: TextInputType.number,
                          validator: (value) => value!.trim().isEmpty || double.tryParse(value) == null ? 'Valid amount required' : null,
                        ),
                        _buildFormField(
                          controller: _approvedByController,
                          label: 'Approved By',
                          validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _expenseDateController,
                          label: 'Expense Date',
                          validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: _paymentMode,
                          items: ['Cash', 'UPI', 'Bank', 'Card']
                              .map((mode) => DropdownMenuItem(value: mode, child: Text(mode, style: GoogleFonts.poppins(fontSize: 14))))
                              .toList(),
                          onChanged: (val) => setState(() => _paymentMode = val!),
                          decoration: InputDecoration(
                            labelText: 'Mode of Payment',
                            labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _clearForm,
                              child: Text('Clear', style: GoogleFonts.poppins(color: Colors.grey[600])),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _saveExpense,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Add Expense',
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
                'Expenses List',
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
                itemCount: _expenses.length,
                itemBuilder: (context, index) {
                  final expense = _expenses[index];
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
                                  expense['category'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                expense['expense_type'],
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          Text(
                            'Amount: ₹${expense['amount'].toStringAsFixed(2)} | Date: ${expense['date']}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'Mode: ${expense['mode']}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
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

// class ExpenseManagementScreen extends StatefulWidget {
//   @override
//   _ExpenseManagementScreenState createState() => _ExpenseManagementScreenState();
// }

// class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _employeeController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   final TextEditingController _amountController = TextEditingController();
//   final TextEditingController _approvedByController = TextEditingController();
//   final TextEditingController _expenseDateController = TextEditingController();

//   String _expenseType = 'Travel';
//   String _paymentMode = 'Cash';
//   List<Map<String, dynamic>> _expenses = [];

//   @override
//   void initState() {
//     super.initState();
//     _expenseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     _loadExpenses();
//   }

//   Future<void> _loadExpenses() async {
//     final db = await DBHelper().database;
//     final data = await db.query('expenses', orderBy: 'date DESC');
//     setState(() {
//       _expenses = data;
//     });
//   }

//   Future<void> _saveExpense() async {
//     if (!_formKey.currentState!.validate()) return;

//     final db = await DBHelper().database;
//     await db.insert('expenses', {
//       'employee_name': _employeeController.text,
//       'expense_type': _expenseType,
//       'category': _descriptionController.text,
//       'amount': double.tryParse(_amountController.text) ?? 0,
//       'approved_by': _approvedByController.text,
//       'date': _expenseDateController.text,
//       'mode': _paymentMode,
//     });

//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense added successfully!')));

//     _formKey.currentState!.reset();
//     _expenseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     setState(() {
//       _expenseType = 'Travel';
//       _paymentMode = 'Cash';
//     });

//     await _loadExpenses();
//   }

//   Widget _buildExpenseCard(Map<String, dynamic> expense) {
//     return Card(
//       margin: EdgeInsets.symmetric(vertical: 6),
//       child: ListTile(
//         title: Text('${expense['category']} - ₹${expense['amount'].toStringAsFixed(2)}'),
//         subtitle: Text('Date: ${expense['date']} | Mode: ${expense['mode']}'),
//         trailing: Text(expense['expense_type']),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Expense Management')),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   TextFormField(controller: _employeeController, decoration: InputDecoration(labelText: 'Employee Name (Optional)')),
//                   DropdownButtonFormField<String>(
//                     value: _expenseType,
//                     items: ['Travel', 'Maintenance', 'Utility', 'Office', 'Misc'].map((type) {
//                       return DropdownMenuItem(value: type, child: Text(type));
//                     }).toList(),
//                     onChanged: (val) => setState(() => _expenseType = val!),
//                     decoration: InputDecoration(labelText: 'Expense Type'),
//                   ),
//                   TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: 'Description')),
//                   TextFormField(
//                     controller: _amountController,
//                     decoration: InputDecoration(labelText: 'Amount'),
//                     keyboardType: TextInputType.number,
//                     validator: (value) => value!.isEmpty ? 'Enter amount' : null,
//                   ),
//                   TextFormField(controller: _approvedByController, decoration: InputDecoration(labelText: 'Approved By')),
//                   TextFormField(controller: _expenseDateController, decoration: InputDecoration(labelText: 'Expense Date')),
//                   DropdownButtonFormField<String>(
//                     value: _paymentMode,
//                     items: ['Cash', 'UPI', 'Bank', 'Card'].map((mode) {
//                       return DropdownMenuItem(value: mode, child: Text(mode));
//                     }).toList(),
//                     onChanged: (val) => setState(() => _paymentMode = val!),
//                     decoration: InputDecoration(labelText: 'Mode of Payment'),
//                   ),
//                   SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: _saveExpense,
//                     child: Text('Add Expense'),
//                   ),
//                 ],
//               ),
//             ),
//             Divider(height: 32),
//             Text('Expenses List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//             ListView.builder(
//               itemCount: _expenses.length,
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               itemBuilder: (context, index) => _buildExpenseCard(_expenses[index]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }