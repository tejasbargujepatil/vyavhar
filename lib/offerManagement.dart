import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
// import 'package:open_file/open_file.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class OfferQuotationScreen extends StatefulWidget {
  const OfferQuotationScreen({super.key});

  @override
  _OfferQuotationScreenState createState() => _OfferQuotationScreenState();



  
}

class _OfferQuotationScreenState extends State<OfferQuotationScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _validityDateController = TextEditingController();
  int? _selectedCustomerId;
  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _customers = [];
  final List<Map<String, dynamic>> _items = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item['amount']);

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
    _validityDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
  }

  @override
  void dispose() {
    _validityDateController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final db = await DBHelper().database;
    final data = await db.query('customers');
    setState(() => _customers = data);
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (_) {
        final TextEditingController desc = TextEditingController();
        final TextEditingController qty = TextEditingController();
        final TextEditingController rate = TextEditingController();
        final TextEditingController discount = TextEditingController();
        final TextEditingController tax = TextEditingController();
        final formKey = GlobalKey<FormState>();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Add Item', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFormField(
                    controller: desc,
                    label: 'Description',
                    validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                  ),
                  _buildFormField(
                    controller: qty,
                    label: 'Quantity',
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.trim().isEmpty || int.tryParse(value) == null ? 'Valid number required' : null,
                  ),
                  _buildFormField(
                    controller: rate,
                    label: 'Rate',
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.trim().isEmpty || double.tryParse(value) == null ? 'Valid number required' : null,
                  ),
                  _buildFormField(
                    controller: discount,
                    label: 'Discount %',
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.trim().isEmpty || double.tryParse(value) == null ? 'Valid number required' : null,
                  ),
                  _buildFormField(
                    controller: tax,
                    label: 'Tax %',
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.trim().isEmpty || double.tryParse(value) == null ? 'Valid number required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final q = int.tryParse(qty.text) ?? 0;
                final r = double.tryParse(rate.text) ?? 0;
                final d = double.tryParse(discount.text) ?? 0;
                final t = double.tryParse(tax.text) ?? 0;
                double discounted = r * q * (1 - d / 100);
                double taxed = discounted * (1 + t / 100);
                _items.add({
                  'desc': desc.text.trim(),
                  'qty': q,
                  'rate': r,
                  'discount': d,
                  'tax': t,
                  'amount': taxed,
                });
                setState(() {});
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveOffer() async {
    if (!_formKey.currentState!.validate() || _selectedCustomer == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedCustomer == null ? 'Please select a customer' : 'Please add at least one item'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }


    final db = await DBHelper().database;
    final offerId = await db.insert('offers', {
      'customer_id': _selectedCustomerId,
      'validity_date': _validityDateController.text.trim(),
      'total_amount': _totalAmount,
    });

    for (final item in _items) {
      await db.insert('offer_items', {
        'offer_id': offerId,
        'description': item['desc'],
        'quantity': item['qty'],
        'rate': item['rate'],
        'discount': item['discount'],
        'tax': item['tax'],
        'amount': item['amount'],
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Offer saved successfully'),
        backgroundColor: Colors.green[600],
      ),
    );
    await _saveAndOpenOfferPDF();

    _clearForm();
  }


 Future<void> _saveAndOpenOfferPDF() async {
  if (!_formKey.currentState!.validate() || _items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !_formKey.currentState!.validate()
              ? 'Please fill the form correctly'
              : 'Please add at least one item',
        ),
        backgroundColor: Colors.red[600],
      ),
    );
    return;
  }

  try {
    final pdfBytes = await _generateOfferPDF();
    final customerName = (_selectedCustomer?['name'] ?? 'UnknownCustomer')
        .toString()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'SpecialOffer_$customerName.pdf';

    Directory? directory;

    if (Platform.isAndroid || Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        directory = Directory('$home/Downloads');
      }
    }

    if (directory == null || !await directory.exists()) {
      throw Exception('Downloads directory not found.');
    }

    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Offer saved to: $filePath')),
    );

    // await OpenFile.open(filePath);
    await OpenFilex.open(filePath);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save PDF: $e')),
    );
  }
}





  Future<void> _convertToInvoice() async {
    if (_selectedCustomer == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedCustomer == null ? 'Please select a customer' : 'Please add at least one item'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final db = await DBHelper().database;
    final countResult = await db.rawQuery('SELECT COUNT(*)+1 as next FROM invoices');
    final nextInvoiceNo = 'INV-${DateFormat('yyyyMM').format(DateTime.now())}-${countResult.first['next'].toString().padLeft(4, '0')}';
    final invoiceId = await db.insert('invoices', {
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'invoice_no': nextInvoiceNo,
      'delivery_note': '',
      'payment_terms': '',
      'order_no': '',
      'order_date': '',
      'dispatch_doc_no': '',
      'dispatch_mode': '',
      'delivery_address': _selectedCustomer!['shipping_address'] ?? '',
      'buyer_id': _selectedCustomerId,
      'gst_no': _selectedCustomer!['gst_number'] ?? '',
      'state': _selectedCustomer!['state'] ?? '',
      'state_code': _selectedCustomer!['state_code'] ?? '',
      'total_amount': _totalAmount,
      'amount_words': _convertToWords(_totalAmount.toInt()),
      'bank_details': '',
      'signatory': '',
    });

    for (final item in _items) {
      await db.insert('invoice_items', {
        'invoice_id': invoiceId,
        'description': item['desc'],
        'hsn': '',
        'quantity': item['qty'],
        'rate': item['rate'],
        'unit': '',
        'discount': item['discount'],
        'tax': item['tax'],
        'amount': item['amount'],
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Converted to Invoice: $nextInvoiceNo'),
        backgroundColor: Colors.green[600],
      ),
    );

    await _saveAndOpenOfferPDF(); // Optionally save as PDF after conversion

    _clearForm();

    
    
  }

  

  void _clearForm() {
    _validityDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
    _selectedCustomerId = null;
    _selectedCustomer = null;
    _items.clear();
    setState(() {});
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

  // @override
  @override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final crossAxisCount = screenWidth < 600 ? 1 : screenWidth < 900 ? 2 : 3;

  return Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    appBar: AppBar(
      title: Text(
        'Offer/Quotation Management',
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
          },
          tooltip: 'Reset Form & Refresh',
        ),
      ],
    ),
    body: FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
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
                    'Create New Offer/Quotation',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _selectedCustomerId,
                    items: _customers.map<DropdownMenuItem<int>>((cust) {
                      return DropdownMenuItem<int>(
                        value: cust['id'] as int,
                        child: Text(cust['name'], style: GoogleFonts.poppins(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomerId = val;
                        _selectedCustomer = _customers.firstWhere(
                          (cust) => cust['id'] == val,
                          orElse: () => {},
                        );
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Select Customer',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  // Display customer details if a customer is selected
                  if (_selectedCustomer != null) ...[
                    _buildReadOnlyField(
                      label: 'Customer Name',
                      value: _selectedCustomer!['name'] ?? 'N/A',
                    ),
                    _buildReadOnlyField(
                      label: 'GST Number',
                      value: _selectedCustomer!['gst_number'] ?? 'N/A',
                    ),
                    _buildReadOnlyField(
                      label: 'State',
                      value: _selectedCustomer!['state'] ?? 'N/A',
                    ),
                    _buildReadOnlyField(
                      label: 'State Code',
                      value: _selectedCustomer!['state_code'] ?? 'N/A',
                    ),
                    _buildReadOnlyField(
                      label: 'Shipping Address',
                      value: _selectedCustomer!['shipping_address'] ?? 'N/A',
                    ),
                  ],
                  _buildFormField(
                    controller: _validityDateController,
                    label: 'Validity Date',
                    validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Items',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text('Add Product/Service', style: GoogleFonts.poppins(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
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
                                      item['desc'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _items.removeAt(index));
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                'Amount: ₹${item['amount'].toStringAsFixed(2)} | Qty: ${item['qty']}',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount: ₹${_totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _clearForm,
                            child: Text('Clear', style: GoogleFonts.poppins(color: Colors.grey[600])),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveOffer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2C3E50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Save Offer',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _convertToInvoice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Convert to Invoice',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ],
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
  );
}

// Helper method to build read-only fields for customer details
Widget _buildReadOnlyField({required String label, required String value}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[200], // Light grey to indicate read-only
      ),
      style: GoogleFonts.poppins(fontSize: 14),
    ),
  );
}
  // Widget build(BuildContext context) {
  //   final screenWidth = MediaQuery.of(context).size.width;
  //   final crossAxisCount = screenWidth < 600 ? 1 : screenWidth < 900 ? 2 : 3;

  //   return Scaffold(
  //     backgroundColor: const Color(0xFFF5F7FA),
  //     appBar: AppBar(
  //       title: Text(
  //         'Offer/Quotation Management',
  //         style: GoogleFonts.poppins(
  //           fontSize: 22,
  //           fontWeight: FontWeight.w600,
  //           color: Colors.white,
  //         ),
  //       ),
  //       backgroundColor: const Color(0xFF2C3E50),
  //       elevation: 0,
  //       actions: [
  //         IconButton(
  //           icon: const Icon(Icons.refresh, color: Colors.white),
  //           onPressed: () {
  //             _clearForm();
  //             _loadCustomers();
  //           },
  //           tooltip: 'Reset Form & Refresh',
  //         ),
  //       ],
  //     ),
  //     body: FadeTransition(
  //       opacity: _fadeAnimation,
  //       child: SingleChildScrollView(
  //         padding: const EdgeInsets.all(16),
  //         child: Card(
  //           elevation: 4,
  //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //           child: Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Form(
  //               key: _formKey,
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     'Create New Offer/Quotation',
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 18,
  //                       fontWeight: FontWeight.w600,
  //                       color: Colors.black87,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 16),
  //                   DropdownButtonFormField<int>(
  //                     value: _selectedCustomerId,
  //                     items: _customers.map<DropdownMenuItem<int>>((cust) {
  //                       return DropdownMenuItem<int>(
  //                         value: cust['id'] as int,
  //                         child: Text(cust['name'], style: GoogleFonts.poppins(fontSize: 14)),
  //                         onTap: () => _selectedCustomer = cust,
  //                       );
  //                     }).toList(),
  //                     onChanged: (val) => setState(() => _selectedCustomerId = val),
  //                     decoration: InputDecoration(
  //                       labelText: 'Select Customer',
  //                       labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
  //                       border: OutlineInputBorder(
  //                         borderRadius: BorderRadius.circular(12),
  //                       ),
  //                       filled: true,
  //                       fillColor: Colors.white,
  //                     ),
  //                     validator: (value) => value == null ? 'Required' : null,
  //                   ),
  //                   _buildFormField(
  //                     controller: _validityDateController,
  //                     label: 'Validity Date',
  //                     validator: (value) => value!.trim().isEmpty ? 'Required' : null,
  //                   ),
  //                   const SizedBox(height: 16),
  //                   Text(
  //                     'Items',
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.w600,
  //                       color: Colors.black87,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 8),
  //                   ElevatedButton.icon(
  //                     onPressed: _addItem,
  //                     icon: const Icon(Icons.add, color: Colors.white),
  //                     label: Text('Add Product/Service', style: GoogleFonts.poppins(color: Colors.white)),
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: const Color(0xFF2C3E50),
  //                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 8),
  //                   GridView.builder(
  //                     shrinkWrap: true,
  //                     physics: const NeverScrollableScrollPhysics(),
  //                     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //                       crossAxisCount: crossAxisCount,
  //                       crossAxisSpacing: 16,
  //                       mainAxisSpacing: 16,
  //                       childAspectRatio: 2,
  //                     ),
  //                     itemCount: _items.length,
  //                     itemBuilder: (context, index) {
  //                       final item = _items[index];
  //                       return Card(
  //                         elevation: 4,
  //                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //                         child: Padding(
  //                           padding: const EdgeInsets.all(16),
  //                           child: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               Row(
  //                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                                 children: [
  //                                   Expanded(
  //                                     child: Text(
  //                                       item['desc'],
  //                                       style: GoogleFonts.poppins(
  //                                         fontSize: 14,
  //                                         fontWeight: FontWeight.w600,
  //                                         color: Colors.black87,
  //                                       ),
  //                                       overflow: TextOverflow.ellipsis,
  //                                     ),
  //                                   ),
  //                                   IconButton(
  //                                     icon: const Icon(Icons.delete, color: Colors.red),
  //                                     onPressed: () {
  //                                       setState(() => _items.removeAt(index));
  //                                     },
  //                                   ),
  //                                 ],
  //                               ),
  //                               Text(
  //                                 'Amount: ₹${item['amount'].toStringAsFixed(2)} | Qty: ${item['qty']}',
  //                                 style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       );
  //                     },
  //                   ),
  //                   const SizedBox(height: 16),
  //                   Row(
  //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                     children: [
  //                       Text(
  //                         'Total Amount: ₹${_totalAmount.toStringAsFixed(2)}',
  //                         style: GoogleFonts.poppins(
  //                           fontSize: 16,
  //                           fontWeight: FontWeight.w600,
  //                           color: Colors.black87,
  //                         ),
  //                       ),
  //                       Row(
  //                         children: [
  //                           TextButton(
  //                             onPressed: _clearForm,
  //                             child: Text('Clear', style: GoogleFonts.poppins(color: Colors.grey[600])),
  //                           ),
  //                           const SizedBox(width: 8),
  //                           ElevatedButton(
  //                             onPressed: _saveOffer,
  //                             style: ElevatedButton.styleFrom(
  //                               backgroundColor: const Color(0xFF2C3E50),
  //                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  //                             ),
  //                             child: Text(
  //                               'Save Offer',
  //                               style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
  //                             ),
  //                           ),
  //                           const SizedBox(width: 8),
  //                           ElevatedButton(
  //                             onPressed: _convertToInvoice,
  //                             style: ElevatedButton.styleFrom(
  //                               backgroundColor: Colors.green[600],
  //                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  //                             ),
  //                             child: Text(
  //                               'Convert to Invoice',
  //                               style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ],
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }


  Future<Uint8List> _generateOfferPDF() async {
  final pdf = pw.Document();
  final ByteData bytes = await rootBundle.load('assets/logo.png');
  final Uint8List logoData = bytes.buffer.asUint8List();
  final logoImage = pw.MemoryImage(logoData);

  formatCurrency(double val) => '₹${val.toStringAsFixed(2)}';

  pdf.addPage(
    pw.Page(
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Image(logoImage, height: 60)),
          pw.SizedBox(height: 16),
          pw.Text('SPECIAL OFFER', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),

          // pw.Text('Customer Name: ${_selectedCustomer!['name']}'),
          pw.Text('Customer Name: ${_selectedCustomer?['name'] ?? 'Unknown'}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Customer ID: ${_selectedCustomerId ?? 'N/A'}'),
          pw.Text('GST No: ${_selectedCustomer?['gst_number'] ?? 'N/A'}'),
          pw.Text('State: ${_selectedCustomer?['state'] ?? 'N/A'}'),
          pw.Text('State Code: ${_selectedCustomer?['state_code'] ?? 'N/A'}'),
          pw.SizedBox(height: 10),
          pw.Text('Validity: ${_validityDateController.text}'),
          pw.SizedBox(height: 10),

          pw.Text('Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Description', 'Qty', 'Rate', 'Disc%', 'Tax%', 'Amount'],
            data: _items.map((item) {
              return [
                item['desc'],
                '${item['qty']}',
                formatCurrency(item['rate']),
                '${item['discount']}',
                '${item['tax']}',
                formatCurrency(item['amount']),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total: ${formatCurrency(_totalAmount)}'),
                pw.Text('In Words: ${_convertToWords(_totalAmount.toInt())}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Thank you for your business!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
        ],
      ),
    ),
  );

  return pdf.save();
}
  String _convertToWords(int amount) {
    // Placeholder for number-to-words conversion; consider using a package like `number_to_words`
    return '$amount Rupees Only';
  }

}









// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'db_helper.dart';

// class OfferQuotationScreen extends StatefulWidget {
//   @override
//   _OfferQuotationScreenState createState() => _OfferQuotationScreenState();
// }

// class _OfferQuotationScreenState extends State<OfferQuotationScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _validityDateController = TextEditingController();
//   int? _selectedCustomerId;
//   Map<String, dynamic>? _selectedCustomer;
//   List<Map<String, dynamic>> _customers = [];
//   List<Map<String, dynamic>> _items = [];

//   double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item['amount']);

//   @override
//   void initState() {
//     super.initState();
//     _loadCustomers();
//     _validityDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: 30)));
//   }

//   Future<void> _loadCustomers() async {
//     final db = await DBHelper().database;
//     final data = await db.query('customers');
//     setState(() => _customers = data);
//   }

//   void _addItem() {
//     showDialog(
//       context: context,
//       builder: (_) {
//         final TextEditingController desc = TextEditingController();
//         final TextEditingController qty = TextEditingController();
//         final TextEditingController rate = TextEditingController();
//         final TextEditingController discount = TextEditingController();
//         final TextEditingController tax = TextEditingController();

//         return AlertDialog(
//           title: Text('Add Item'),
//           content: SingleChildScrollView(
//             child: Column(
//               children: [
//                 TextField(controller: desc, decoration: InputDecoration(labelText: 'Description')),
//                 TextField(controller: qty, decoration: InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
//                 TextField(controller: rate, decoration: InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
//                 TextField(controller: discount, decoration: InputDecoration(labelText: 'Discount %'), keyboardType: TextInputType.number),
//                 TextField(controller: tax, decoration: InputDecoration(labelText: 'Tax %'), keyboardType: TextInputType.number),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 final q = int.tryParse(qty.text) ?? 0;
//                 final r = double.tryParse(rate.text) ?? 0;
//                 final d = double.tryParse(discount.text) ?? 0;
//                 final t = double.tryParse(tax.text) ?? 0;

//                 double discounted = r * q * (1 - d / 100);
//                 double taxed = discounted * (1 + t / 100);

//                 _items.add({
//                   'desc': desc.text,
//                   'qty': q,
//                   'rate': r,
//                   'discount': d,
//                   'tax': t,
//                   'amount': taxed
//                 });

//                 setState(() {});
//                 Navigator.pop(context);
//               },
//               child: Text('Add'),
//             )
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _saveOffer() async {
//     if (!_formKey.currentState!.validate() || _selectedCustomer == null || _items.isEmpty) return;

//     final db = await DBHelper().database;
//     final offerId = await db.insert('offers', {
//       'customer_id': _selectedCustomerId,
//       'validity_date': _validityDateController.text,
//       'total_amount': _totalAmount,
//     });

//     for (final item in _items) {
//       await db.insert('offer_items', {
//         'offer_id': offerId,
//         'description': item['desc'],
//         'quantity': item['qty'],
//         'rate': item['rate'],
//         'discount': item['discount'],
//         'tax': item['tax'],
//         'amount': item['amount'],
//       });
//     }

//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Offer saved.')));
//   }

//   Future<void> _convertToInvoice() async {
//     if (_selectedCustomer == null || _items.isEmpty) return;

//     final db = await DBHelper().database;
//     final countResult = await db.rawQuery('SELECT COUNT(*)+1 as next FROM invoices');
//     final nextInvoiceNo = 'INV-${countResult.first['next']}';

//     final invoiceId = await db.insert('invoices', {
//       'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
//       'invoice_no': nextInvoiceNo,
//       'delivery_note': '',
//       'payment_terms': '',
//       'order_no': '',
//       'order_date': '',
//       'dispatch_doc_no': '',
//       'dispatch_mode': '',
//       'delivery_address': _selectedCustomer!['shipping_address'] ?? '',
//       'buyer_id': _selectedCustomerId,
//       'gst_no': _selectedCustomer!['gst_number'],
//       'state': _selectedCustomer!['state'],
//       'state_code': _selectedCustomer!['state_code'],
//       'total_amount': _totalAmount,
//       'amount_words': '${_totalAmount.toInt()} Rupees Only',
//       'bank_details': '',
//       'signatory': '',
//     });

//     for (final item in _items) {
//       await db.insert('invoice_items', {
//         'invoice_id': invoiceId,
//         'description': item['desc'],
//         'hsn': '',
//         'quantity': item['qty'],
//         'rate': item['rate'],
//         'unit': '',
//         'discount': item['discount'],
//         'tax': item['tax'],
//         'amount': item['amount'],
//       });
//     }

//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Converted to Invoice: $nextInvoiceNo')));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Offer / Quotation Management')),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               DropdownButtonFormField<int>(
//                 value: _selectedCustomerId,
//                 items: _customers.map<DropdownMenuItem<int>>((cust) {
//                   return DropdownMenuItem<int>(
//                     value: cust['id'] as int,
//                     child: Text(cust['name']),
//                     onTap: () => _selectedCustomer = cust,
//                   );
//                 }).toList(),
//                 onChanged: (val) => setState(() => _selectedCustomerId = val),
//                 decoration: InputDecoration(labelText: 'Select Customer'),
//               ),
//               TextFormField(controller: _validityDateController, decoration: InputDecoration(labelText: 'Validity Date')),
//               ElevatedButton.icon(
//                 onPressed: _addItem,
//                 icon: Icon(Icons.add),
//                 label: Text('Add Product/Service'),
//               ),
//               ..._items.map((item) => ListTile(
//                     title: Text(item['desc']),
//                     subtitle: Text('Amount: ₹${item['amount'].toStringAsFixed(2)}'),
//                   )),
//               Divider(),
//               Text('Total Amount: ₹${_totalAmount.toStringAsFixed(2)}'),
//               SizedBox(height: 12),
//               ElevatedButton(
//                 onPressed: _saveOffer,
//                 child: Text('Save Offer'),
//               ),
//               ElevatedButton(
//                 onPressed: _convertToInvoice,
//                 child: Text('Convert to Invoice'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }