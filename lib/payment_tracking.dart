import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class PaymentTrackingScreen extends StatefulWidget {
  const PaymentTrackingScreen({super.key});

  @override
  _PaymentTrackingScreenState createState() => _PaymentTrackingScreenState();
}

class _PaymentTrackingScreenState extends State<PaymentTrackingScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _orderNoController = TextEditingController();
  final TextEditingController _utrController = TextEditingController();
  final TextEditingController _paymentDateController = TextEditingController();
  String _paymentMode = 'RTGS';
  int? _selectedCustomerId;
  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _payments = [];
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
    _paymentDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadCustomers();
    _loadPayments();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _orderNoController.dispose();
    _utrController.dispose();
    _paymentDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final db = await DBHelper().database;
    final data = await db.query('customers', orderBy: 'name ASC');
    setState(() => _customers = data);
  }

  Future<void> _loadPayments() async {
    final db = await DBHelper().database;
    final data = await db.rawQuery('''
      SELECT p.*, c.name as customer_name
      FROM payments p
      LEFT JOIN customers c ON p.customer_id = c.id
      ORDER BY p.date DESC
    ''');
    setState(() => _payments = data);
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate() || _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedCustomer == null ? 'Please select a customer' : 'Please fill all required fields'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final db = await DBHelper().database;
    await db.insert('payments', {
      'customer_id': _selectedCustomerId,
      'amount': double.tryParse(_amountController.text) ?? 0,
      'order_no': _orderNoController.text.trim(),
      'utr_no': _utrController.text.trim(),
      'date': _paymentDateController.text.trim(),
      'mode': _paymentMode,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Payment recorded successfully'),
        backgroundColor: Colors.green[600],
      ),
    );

    _clearForm();
    await _loadPayments();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _amountController.clear();
    _orderNoController.clear();
    _utrController.clear();
    _paymentDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedCustomerId = null;
    _selectedCustomer = null;
    setState(() => _paymentMode = 'RTGS');
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
          'Payment Tracking',
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
              _loadCustomers();
              _loadPayments();
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
                          'Record New Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedCustomerId,
                          items: _customers.map((cust) {
                            return DropdownMenuItem<int>(
                              value: cust['id'],
                              child: Text(cust['name'], style: GoogleFonts.poppins(fontSize: 14)),
                              onTap: () => _selectedCustomer = cust,
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCustomerId = val),
                          decoration: InputDecoration(
                            labelText: 'Customer Name',
                            labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) => value == null ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _amountController,
                          label: 'Amount Paid',
                          keyboardType: TextInputType.number,
                          validator: (val) => val!.trim().isEmpty || double.tryParse(val) == null || double.parse(val) <= 0 ? 'Valid amount required' : null,
                        ),
                        _buildFormField(
                          controller: _orderNoController,
                          label: 'Order No.',
                          validator: (val) => val!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _utrController,
                          label: 'UTR/Transaction No.',
                          validator: (val) => val!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _paymentDateController,
                          label: 'Payment Date',
                          validator: (val) => val!.trim().isEmpty ? 'Required' : null,
                        ),
                        DropdownButtonFormField<String>(
                          value: _paymentMode,
                          items: ['RTGS', 'NEFT', 'Cheque', 'UPI', 'Cash']
                              .map((mode) => DropdownMenuItem<String>(value: mode, child: Text(mode, style: GoogleFonts.poppins(fontSize: 14))))
                              .toList(),
                          onChanged: (val) => setState(() => _paymentMode = val!),
                          decoration: InputDecoration(
                            labelText: 'Payment Mode',
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
                              onPressed: _savePayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Save Payment',
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
                'Recent Payments',
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
                itemCount: _payments.length,
                itemBuilder: (context, index) {
                  final pay = _payments[index];
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
                                  pay['customer_name'] ?? 'Unknown',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                pay['mode'],
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          Text(
                            'Amount: ₹${pay['amount'].toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'Order #: ${pay['order_no']} | UTR: ${pay['utr_no']}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'Date: ${pay['date']}',
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

// class PaymentTrackingScreen extends StatefulWidget {
//   @override
//   _PaymentTrackingScreenState createState() => _PaymentTrackingScreenState();
// }

// class _PaymentTrackingScreenState extends State<PaymentTrackingScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _amountController = TextEditingController();
//   final _orderNoController = TextEditingController();
//   final _utrController = TextEditingController();
//   final _paymentDateController = TextEditingController();

//   String _paymentMode = 'RTGS';
//   int? _selectedCustomerId;
//   Map<String, dynamic>? _selectedCustomer;
//   List<Map<String, dynamic>> _customers = [];
//   List<Map<String, dynamic>> _payments = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadCustomers();
//     _loadPayments();
//     _paymentDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
//   }

//   Future<void> _loadCustomers() async {
//     final db = await DBHelper().database;
//     final data = await db.query('customers');
//     setState(() => _customers = data);
//   }

//   Future<void> _loadPayments() async {
//     final db = await DBHelper().database;
//     final data = await db.rawQuery('''
//       SELECT p.*, c.name as customer_name
//       FROM payments p
//       LEFT JOIN customers c ON p.customer_id = c.id
//       ORDER BY p.date DESC
//     ''');
//     setState(() => _payments = data);
//   }

//   Future<void> _savePayment() async {
//     if (!_formKey.currentState!.validate() || _selectedCustomer == null) return;
//     final db = await DBHelper().database;
//     await db.insert('payments', {
//       'customer_id': _selectedCustomerId,
//       'amount': double.tryParse(_amountController.text) ?? 0,
//       'order_no': _orderNoController.text,
//       'utr_no': _utrController.text,
//       'date': _paymentDateController.text,
//       'mode': _paymentMode,
//     });

//     // Reset fields
//     _amountController.clear();
//     _orderNoController.clear();
//     _utrController.clear();
//     _paymentDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     _selectedCustomerId = null;
//     _selectedCustomer = null;

//     // Show confirmation and reload payments
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment recorded.')));
//     _formKey.currentState!.reset();
//     setState(() => _paymentMode = 'RTGS');
//     await _loadPayments();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Payment Tracking')),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   DropdownButtonFormField<int>(
//                     value: _selectedCustomerId,
//                     items: _customers.map((cust) {
//                       return DropdownMenuItem<int>(
//                         value: cust['id'],
//                         child: Text(cust['name']),
//                         onTap: () => _selectedCustomer = cust,
//                       );
//                     }).toList(),
//                     onChanged: (val) => setState(() => _selectedCustomerId = val),
//                     decoration: InputDecoration(labelText: 'Customer Name'),
//                   ),
//                   TextFormField(
//                     controller: _amountController,
//                     decoration: InputDecoration(labelText: 'Amount Paid'),
//                     keyboardType: TextInputType.number,
//                     validator: (val) => val!.isEmpty ? 'Enter amount' : null,
//                   ),
//                   TextFormField(
//                     controller: _orderNoController,
//                     decoration: InputDecoration(labelText: 'Order No.'),
//                   ),
//                   TextFormField(
//                     controller: _utrController,
//                     decoration: InputDecoration(labelText: 'UTR/Transaction No.'),
//                   ),
//                   TextFormField(
//                     controller: _paymentDateController,
//                     decoration: InputDecoration(labelText: 'Payment Date'),
//                   ),
//                   DropdownButtonFormField<String>(
//                     value: _paymentMode,
//                     items: ['RTGS', 'NEFT', 'Cheque', 'UPI', 'Cash'].map((mode) {
//                       return DropdownMenuItem<String>(value: mode, child: Text(mode));
//                     }).toList(),
//                     onChanged: (val) => setState(() => _paymentMode = val!),
//                     decoration: InputDecoration(labelText: 'Payment Mode'),
//                   ),
//                   SizedBox(height: 20),
//                   ElevatedButton(onPressed: _savePayment, child: Text('Save Payment')),
//                 ],
//               ),
//             ),
//             SizedBox(height: 20),
//             Divider(),
//             Text('Recent Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             ListView.builder(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               itemCount: _payments.length,
//               itemBuilder: (context, index) {
//                 final pay = _payments[index];
//                 return Card(
//                   child: ListTile(
//                     title: Text(pay['customer_name'] ?? 'Unknown'),
//                     subtitle: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Order #: ${pay['order_no']}'),
//                         Text('UTR: ${pay['utr_no']}'),
//                         Text('Date: ${pay['date']}'),
//                       ],
//                     ),
//                     trailing: Column(
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         Text('₹${pay['amount']}'),
//                         Text(pay['mode'], style: TextStyle(fontSize: 12)),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
  
