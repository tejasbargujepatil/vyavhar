import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'db_helper.dart';

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  _CustomerManagementScreenState createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _customers = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _billingAddressController = TextEditingController();
  final TextEditingController _shippingAddressController = TextEditingController();
  final TextEditingController _emailsController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _contactsController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _stateCodeController = TextEditingController();
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
    _loadCustomers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gstController.dispose();
    _billingAddressController.dispose();
    _shippingAddressController.dispose();
    _emailsController.dispose();
    _contactPersonController.dispose();
    _contactsController.dispose();
    _stateController.dispose();
    _stateCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final db = await DBHelper().database;
    final result = await db.query('customers');
    setState(() {
      _customers = result;
    });
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    final db = await DBHelper().database;
    final customer = {
      'name': _nameController.text.trim(),
      'gst_number': _gstController.text.trim(),
      'billing_address': _billingAddressController.text.trim(),
      'shipping_address': _shippingAddressController.text.trim(),
      'emails': _emailsController.text.trim(),
      'contact_person': _contactPersonController.text.trim(),
      'contact_numbers': _contactsController.text.trim(),
      'state': _stateController.text.trim(),
      'state_code': _stateCodeController.text.trim(),
    };

    if (_editingId == null) {
      await db.insert('customers', customer);
    } else {
      await db.update('customers', customer, where: 'id = ?', whereArgs: [_editingId]);
    }

    _clearForm();
    await _loadCustomers();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editingId == null ? 'Customer added successfully' : 'Customer updated successfully'),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _gstController.clear();
    _billingAddressController.clear();
    _shippingAddressController.clear();
    _emailsController.clear();
    _contactPersonController.clear();
    _contactsController.clear();
    _stateController.clear();
    _stateCodeController.clear();
    _editingId = null;
    setState(() {});
  }

  Future<void> _deleteCustomer(int id) async {
    final db = await DBHelper().database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    await _loadCustomers();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Customer deleted successfully'),
        backgroundColor: Colors.red[600],
      ),
    );
  }

  void _editCustomer(Map<String, dynamic> customer) {
    _nameController.text = customer['name'] ?? '';
    _gstController.text = customer['gst_number'] ?? '';
    _billingAddressController.text = customer['billing_address'] ?? '';
    _shippingAddressController.text = customer['shipping_address'] ?? '';
    _emailsController.text = customer['emails'] ?? '';
    _contactPersonController.text = customer['contact_person'] ?? '';
    _contactsController.text = customer['contact_numbers'] ?? '';
    _stateController.text = customer['state'] ?? '';
    _stateCodeController.text = customer['state_code'] ?? '';
    _editingId = customer['id'];
    setState(() {});
  }

  void _copyBillingToShipping() {
    _shippingAddressController.text = _billingAddressController.text;
    setState(() {});
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    bool isMultiLine = false,
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
        maxLines: isMultiLine ? 3 : 1,
        minLines: isMultiLine ? 3 : 1,
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
          'Customer Management',
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
            onPressed: _loadCustomers,
            tooltip: 'Refresh Customers',
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
                          _editingId == null ? 'Add New Customer' : 'Edit Customer',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          controller: _nameController,
                          label: 'Customer Name',
                          validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _gstController,
                          label: 'GST Number',
                        ),
                        _buildFormField(
                          controller: _billingAddressController,
                          label: 'Billing Address',
                          isMultiLine: true,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                controller: _shippingAddressController,
                                label: 'Shipping Address',
                                isMultiLine: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: IconButton(
                                icon: const Icon(Icons.copy, color: Colors.blue),
                                onPressed: _copyBillingToShipping,
                                tooltip: 'Copy Billing to Shipping',
                              ),
                            ),
                          ],
                        ),
                        _buildFormField(
                          controller: _emailsController,
                          label: 'Email IDs (comma separated)',
                          validator: (value) {
                            if (value!.trim().isEmpty) return null;
                            final emails = value.split(',').map((e) => e.trim()).toList();
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            for (var email in emails) {
                              if (!emailRegex.hasMatch(email)) return 'Invalid email format';
                            }
                            return null;
                          },
                        ),
                        _buildFormField(
                          controller: _contactPersonController,
                          label: 'Contact Person Name',
                        ),
                        _buildFormField(
                          controller: _contactsController,
                          label: 'Contact Numbers (comma separated)',
                          validator: (value) {
                            if (value!.trim().isEmpty) return null;
                            final numbers = value.split(',').map((e) => e.trim()).toList();
                            final numberRegex = RegExp(r'^\+?\d{10,12}$');
                            for (var number in numbers) {
                              if (!numberRegex.hasMatch(number)) return 'Invalid phone number format';
                            }
                            return null;
                          },
                        ),
                        _buildFormField(
                          controller: _stateController,
                          label: 'State',
                        ),
                        _buildFormField(
                          controller: _stateCodeController,
                          label: 'State Code',
                          validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_editingId != null)
                              TextButton(
                                onPressed: _clearForm,
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                                ),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _saveCustomer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                _editingId == null ? 'Add Customer' : 'Update Customer',
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
                'Customer List',
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
                itemCount: _customers.length,
                itemBuilder: (context, index) {
                  final customer = _customers[index];
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
                                  customer['name'] ?? 'Unnamed',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
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
                                    onPressed: () => _editCustomer(customer),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteCustomer(customer['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Address: ${customer['billing_address'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Contact: ${customer['contact_numbers'] ?? 'N/A'}',
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














// Uncomment the following code if you want to use the original version without animations and Google Fonts
// import 'package:flutter/material.dart';
// import 'db_helper.dart';

// class CustomerManagementScreen extends StatefulWidget {
//   const CustomerManagementScreen({super.key});

//   @override
//   _CustomerManagementScreenState createState() => _CustomerManagementScreenState();
// }

// class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   List<Map<String, dynamic>> _customers = [];

//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _gstController = TextEditingController();
//   final TextEditingController _billingAddressController = TextEditingController();
//   final TextEditingController _shippingAddressController = TextEditingController();
//   final TextEditingController _emailsController = TextEditingController();
//   final TextEditingController _contactPersonController = TextEditingController();
//   final TextEditingController _contactsController = TextEditingController();
//   final TextEditingController _stateController = TextEditingController();
//   final TextEditingController _stateCodeController = TextEditingController();
//   int? _editingId;

//   @override
//   void initState() {
//     super.initState();
//     _loadCustomers();
//   }

//   Future<void> _loadCustomers() async {
//     final db = await DBHelper().database;
//     final result = await db.query('customers');
//     setState(() {
//       _customers = result;
//     });
//   }

//   Future<void> _saveCustomer() async {
//     if (!_formKey.currentState!.validate()) return;
//     final db = await DBHelper().database;

//     final customer = {
//       'name': _nameController.text,
//       'gst_number': _gstController.text,
//       'billing_address': _billingAddressController.text,
//       'shipping_address': _shippingAddressController.text,
//       'emails': _emailsController.text,
//       'contact_person': _contactPersonController.text,
//       'contact_numbers': _contactsController.text,
//       'state': _stateController.text,
//       'state_code': _stateCodeController.text,
//     };

//     if (_editingId == null) {
//       await db.insert('customers', customer);
//     } else {
//       await db.update('customers', customer, where: 'id = ?', whereArgs: [_editingId]);
//     }

//     _clearForm();
//     _loadCustomers();
//   }

//   void _clearForm() {
//     _nameController.clear();
//     _gstController.clear();
//     _billingAddressController.clear();
//     _shippingAddressController.clear();
//     _emailsController.clear();
//     _contactPersonController.clear();
//     _contactsController.clear();
//     _stateController.clear();
//     _stateCodeController.clear();
//     _editingId = null;
//   }

//   Future<void> _deleteCustomer(int id) async {
//     final db = await DBHelper().database;
//     await db.delete('customers', where: 'id = ?', whereArgs: [id]);
//     _loadCustomers();
//   }

//   void _editCustomer(Map<String, dynamic> customer) {
//     _nameController.text = customer['name'];
//     _gstController.text = customer['gst_number'];
//     _billingAddressController.text = customer['billing_address'];
//     _shippingAddressController.text = customer['shipping_address'];
//     _emailsController.text = customer['emails'];
//     _contactPersonController.text = customer['contact_person'];
//     _contactsController.text = customer['contact_numbers'];
//     _stateController.text = customer['state'];
//     _stateCodeController.text = customer['state_code'];
//     _editingId = customer['id'];
//     setState(() {});
//   }

//   void _copyBillingToShipping() {
//     _shippingAddressController.text = _billingAddressController.text;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Customer Management')),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   TextFormField(
//                     controller: _nameController,
//                     decoration: InputDecoration(labelText: 'Customer Name'),
//                     validator: (value) => value!.isEmpty ? 'Required' : null,
//                   ),
//                   TextFormField(
//                     controller: _gstController,
//                     decoration: InputDecoration(labelText: 'GST Number'),
//                   ),
//                   TextFormField(
//                     controller: _billingAddressController,
//                     decoration: InputDecoration(labelText: 'Billing Address'),
//                   ),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextFormField(
//                           controller: _shippingAddressController,
//                           decoration: InputDecoration(labelText: 'Shipping Address'),
//                         ),
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.copy),
//                         onPressed: _copyBillingToShipping,
//                         tooltip: 'Copy Billing to Shipping',
//                       ),
//                     ],
//                   ),
//                   TextFormField(
//                     controller: _emailsController,
//                     decoration: InputDecoration(labelText: 'Email IDs (comma separated)'),
//                   ),
//                   TextFormField(
//                     controller: _contactPersonController,
//                     decoration: InputDecoration(labelText: 'Contact Person Name'),
//                   ),
//                   TextFormField(
//                     controller: _contactsController,
//                     decoration: InputDecoration(labelText: 'Contact Numbers (comma separated)'),
//                   ),
//                   TextFormField(
//                     controller: _stateController,
//                     decoration: InputDecoration(labelText: 'State'),
//                   ),
//                   TextFormField(
//                     controller: _stateCodeController,
//                     decoration: InputDecoration(labelText: 'State Code'),
//                   ),
//                   SizedBox(height: 12),
//                   ElevatedButton(
//                     onPressed: _saveCustomer,
//                     child: Text(_editingId == null ? 'Add Customer' : 'Update Customer'),
//                   ),
//                 ],
//               ),
//             ),
//             Divider(),
//             ListView.builder(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               itemCount: _customers.length,
//               itemBuilder: (context, index) {
//                 final customer = _customers[index];
//                 return ListTile(
//                   title: Text(customer['name']),
//                   subtitle: Text(customer['billing_address']),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       IconButton(
//                         icon: Icon(Icons.edit, color: Colors.blue),
//                         onPressed: () => _editCustomer(customer),
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.delete, color: Colors.red),
//                         onPressed: () => _deleteCustomer(customer['id']),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }