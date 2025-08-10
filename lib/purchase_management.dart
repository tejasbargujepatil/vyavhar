import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'db_helper.dart';
import 'purchase_notifier.dart';

class PurchaseManagementScreen extends StatefulWidget {
  const PurchaseManagementScreen({super.key});

  @override
  _PurchaseManagementScreenState createState() => _PurchaseManagementScreenState();
}

class _PurchaseManagementScreenState extends State<PurchaseManagementScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _purchaseDate = DateTime.now();
  final TextEditingController _invoiceNoController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _paymentModeController = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _purchases = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item['amount']);
  double get _totalTax => _items.fold(0.0, (sum, item) => sum + item['tax_amount']);

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
    _loadPurchases();
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _vendorController.dispose();
    _paymentModeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPurchases() async {
    final db = await DBHelper().database;
    final data = await db.query('purchases', orderBy: 'id DESC');
    setState(() {
      _purchases = data;
    });
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (_) {
        final TextEditingController hsn = TextEditingController();
        final TextEditingController qty = TextEditingController();
        final TextEditingController rate = TextEditingController();
        final TextEditingController tax = TextEditingController();
        final formKey = GlobalKey<FormState>();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Add Purchase Item', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFormField(
                    controller: hsn,
                    label: 'HSN Code',
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
                final t = double.tryParse(tax.text) ?? 0;
                double base = r * q;
                double taxAmt = base * (t / 100);
                double total = base + taxAmt;
                _items.add({
                  'hsn': hsn.text.trim(),
                  'qty': q,
                  'rate': r,
                  'tax': t,
                  'tax_amount': taxAmt,
                  'amount': total,
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

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate() || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_items.isEmpty ? 'Please add at least one item' : 'Please fill all required fields'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final db = await DBHelper().database;
    final purchaseId = await db.insert('purchases', {
      'date': DateFormat('yyyy-MM-dd').format(_purchaseDate),
      'invoice_no': _invoiceNoController.text.trim(),
      'vendor': _vendorController.text.trim(),
      'payment_mode': _paymentModeController.text.trim(),
      'total': _totalAmount,
      'tax': _totalTax,
    });

    for (final item in _items) {
      await db.insert('purchase_items', {
        'purchase_id': purchaseId,
        'hsn': item['hsn'],
        'quantity': item['qty'],
        'rate': item['rate'],
        'tax': item['tax'],
        'tax_amount': item['tax_amount'],
        'amount': item['amount'],
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Purchase saved successfully'),
        backgroundColor: Colors.green[600],
      ),
    );

    _clearForm();
    await _loadPurchases();
    await Provider.of<PurchaseNotifier>(context, listen: false).refresh();
  }

  void _clearForm() {
    _items.clear();
    _invoiceNoController.clear();
    _vendorController.clear();
    _paymentModeController.clear();
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 1 : screenWidth < 900 ? 2 : 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Purchase Management',
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
              _loadPurchases();
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
                          'Create New Purchase',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          controller: _invoiceNoController,
                          label: 'Invoice No',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _vendorController,
                          label: 'Vendor Name',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _paymentModeController,
                          label: 'Payment Mode',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Purchase Items',
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
                          label: Text('Add Purchase Item', style: GoogleFonts.poppins(color: Colors.white)),
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
                                            'HSN: ${item['hsn']}',
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
                                      'Qty: ${item['qty']} | Amount: ₹${item['amount'].toStringAsFixed(2)}',
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Tax: ₹${_totalTax.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Total Amount: ₹${_totalAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _clearForm,
                                  child: Text('Clear', style: GoogleFonts.poppins(color: Colors.grey[600])),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _savePurchase,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C3E50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: Text(
                                    'Save Purchase',
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
              const SizedBox(height: 24),
              Text(
                'Saved Purchases',
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
                itemCount: _purchases.length,
                itemBuilder: (context, index) {
                  final purchase = _purchases[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice: ${purchase['invoice_no']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Vendor: ${purchase['vendor']} | Total: ₹${purchase['total'].toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'Tax: ₹${purchase['tax'].toStringAsFixed(2)} | Date: ${purchase['date']}',
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
// import 'package:provider/provider.dart';
// import 'purchase_notifier.dart';

// class PurchaseManagementScreen extends StatefulWidget {
//   @override
//   _PurchaseManagementScreenState createState() => _PurchaseManagementScreenState();
// }

// class _PurchaseManagementScreenState extends State<PurchaseManagementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _purchaseDate = DateTime.now();
//   final TextEditingController _invoiceNoController = TextEditingController();
//   final TextEditingController _vendorController = TextEditingController();
//   final TextEditingController _paymentModeController = TextEditingController();

//   List<Map<String, dynamic>> _items = [];
//   List<Map<String, dynamic>> _purchases = [];

//   double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item['amount']);
//   double get _totalTax => _items.fold(0.0, (sum, item) => sum + item['tax_amount']);

//   @override
//   void initState() {
//     super.initState();
//     _loadPurchases();
//   }

//   Future<void> _loadPurchases() async {
//     final db = await DBHelper().database;
//     final data = await db.query('purchases', orderBy: 'id DESC');
//     setState(() {
//       _purchases = data;
//     });
//   }

//   void _addItem() {
//     showDialog(
//       context: context,
//       builder: (_) {
//         final TextEditingController hsn = TextEditingController();
//         final TextEditingController qty = TextEditingController();
//         final TextEditingController rate = TextEditingController();
//         final TextEditingController tax = TextEditingController();

//         return AlertDialog(
//           title: Text('Add Purchase Item'),
//           content: SingleChildScrollView(
//             child: Column(
//               children: [
//                 TextField(controller: hsn, decoration: InputDecoration(labelText: 'HSN Code')),
//                 TextField(controller: qty, decoration: InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
//                 TextField(controller: rate, decoration: InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
//                 TextField(controller: tax, decoration: InputDecoration(labelText: 'Tax %'), keyboardType: TextInputType.number),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 final q = int.tryParse(qty.text) ?? 0;
//                 final r = double.tryParse(rate.text) ?? 0;
//                 final t = double.tryParse(tax.text) ?? 0;
//                 double base = r * q;
//                 double taxAmt = base * (t / 100);
//                 double total = base + taxAmt;

//                 _items.add({
//                   'hsn': hsn.text,
//                   'qty': q,
//                   'rate': r,
//                   'tax': t,
//                   'tax_amount': taxAmt,
//                   'amount': total
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

//   Future<void> _savePurchase() async {
//     if (!_formKey.currentState!.validate() || _items.isEmpty) return;

//     final db = await DBHelper().database;

//     final purchaseId = await db.insert('purchases', {
//       'date': DateFormat('yyyy-MM-dd').format(_purchaseDate),
//       'invoice_no': _invoiceNoController.text,
//       'vendor': _vendorController.text,
//       'payment_mode': _paymentModeController.text,
//       'total': _totalAmount,
//       'tax': _totalTax
//     });

//     for (final item in _items) {
//       await db.insert('purchase_items', {
//         'purchase_id': purchaseId,
//         'hsn': item['hsn'],
//         'quantity': item['qty'],
//         'rate': item['rate'],
//         'tax': item['tax'],
//         'tax_amount': item['tax_amount'],
//         'amount': item['amount'],
//       });
//     }

//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase saved successfully.')));
//     setState(() {
//       _items.clear();
//       _invoiceNoController.clear();
//       _vendorController.clear();
//       _paymentModeController.clear();
//     });

//     await _loadPurchases(); // refresh list after save
//     await Provider.of<PurchaseNotifier>(context, listen: false).refresh();


//     // 🔔 OPTIONAL: Notify dashboard to refresh (explained below)
//     // Provider.of<DashboardNotifier>(context, listen: false).refreshTotalPurchases();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Purchase Management')),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   TextFormField(controller: _invoiceNoController, decoration: InputDecoration(labelText: 'Invoice No'), validator: (v) => v!.isEmpty ? 'Required' : null),
//                   TextFormField(controller: _vendorController, decoration: InputDecoration(labelText: 'Vendor Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
//                   TextFormField(controller: _paymentModeController, decoration: InputDecoration(labelText: 'Payment Mode')),
//                   SizedBox(height: 12),
//                   ElevatedButton.icon(
//                     onPressed: _addItem,
//                     icon: Icon(Icons.add),
//                     label: Text('Add Purchase Item'),
//                   ),
//                   ..._items.map((item) => ListTile(
//                         title: Text('HSN: ${item['hsn']}'),
//                         subtitle: Text('Qty: ${item['qty']} - Amount: ₹${item['amount'].toStringAsFixed(2)}'),
//                       )),
//                   Divider(),
//                   Text('Total Tax: ₹${_totalTax.toStringAsFixed(2)}'),
//                   Text('Total Amount: ₹${_totalAmount.toStringAsFixed(2)}'),
//                   SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: _savePurchase,
//                     child: Text('Save Purchase'),
//                   ),
//                 ],
//               ),
//             ),
//             Divider(height: 32),
//             Text('📋 Saved Purchases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             ..._purchases.map((purchase) => ListTile(
//                   title: Text('Invoice: ${purchase['invoice_no']} - Vendor: ${purchase['vendor']}'),
//                   subtitle: Text('Total: ₹${purchase['total'].toString()} | Tax: ₹${purchase['tax'].toString()} | Date: ${purchase['date']}'),
//                 )),
//           ],
//         ),
//       ),
//     );
//   }
// }