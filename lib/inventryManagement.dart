import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  _InventoryManagementScreenState createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _purchaseDateController = TextEditingController();
  final TextEditingController _buyPriceController = TextEditingController();
  final TextEditingController _sellPriceController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _minAlertQtyController = TextEditingController();
  List<Map<String, dynamic>> _inventory = [];
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
    _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadInventory();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _brandController.dispose();
    _purchaseDateController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _hsnController.dispose();
    _minAlertQtyController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final db = await DBHelper().database;
    final data = await db.query('inventory', orderBy: 'product_name ASC');
    setState(() => _inventory = data);
  }

  Future<void> _saveInventory() async {
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
    await db.insert('inventory', {
      'product_name': _productNameController.text.trim(),
      'quantity': int.tryParse(_quantityController.text) ?? 0,
      'description': _descriptionController.text.trim(),
      'brand': _brandController.text.trim(),
      'purchase_date': _purchaseDateController.text.trim(),
      'buy_price': double.tryParse(_buyPriceController.text) ?? 0,
      'sell_price': double.tryParse(_sellPriceController.text) ?? 0,
      'hsn_code': _hsnController.text.trim(),
      'min_alert_qty': int.tryParse(_minAlertQtyController.text) ?? 0,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Inventory added successfully'),
        backgroundColor: Colors.green[600],
      ),
    );

    _clearForm();
    await _loadInventory();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _productNameController.clear();
    _quantityController.clear();
    _descriptionController.clear();
    _brandController.clear();
    _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _buyPriceController.clear();
    _sellPriceController.clear();
    _hsnController.clear();
    _minAlertQtyController.clear();
    setState(() {});
  }

  bool _isLowStock(Map<String, dynamic> item) {
    return (item['quantity'] as int) <= (item['min_alert_qty'] as int);
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
          'Inventory Management',
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
              _loadInventory();
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
                          'Add New Inventory Item',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          controller: _productNameController,
                          label: 'Product Name',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _quantityController,
                          label: 'Quantity',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.trim().isEmpty || int.tryParse(v) == null || int.parse(v) < 0 ? 'Valid quantity required' : null,
                        ),
                        _buildFormField(
                          controller: _descriptionController,
                          label: 'Description',
                        ),
                        _buildFormField(
                          controller: _brandController,
                          label: 'Brand / Make',
                        ),
                        _buildFormField(
                          controller: _purchaseDateController,
                          label: 'Purchase Date',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _buyPriceController,
                          label: 'Buying Price',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.trim().isEmpty || double.tryParse(v) == null || double.parse(v) < 0 ? 'Valid price required' : null,
                        ),
                        _buildFormField(
                          controller: _sellPriceController,
                          label: 'Selling Price',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.trim().isEmpty || double.tryParse(v) == null || double.parse(v) < 0 ? 'Valid price required' : null,
                        ),
                        _buildFormField(
                          controller: _hsnController,
                          label: 'HSN Code',
                        ),
                        _buildFormField(
                          controller: _minAlertQtyController,
                          label: 'Minimum Alert Quantity',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.trim().isEmpty || int.tryParse(v) == null || int.parse(v) < 0 ? 'Valid quantity required' : null,
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
                              onPressed: _saveInventory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Add Inventory',
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
                'Inventory List',
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
                itemCount: _inventory.length,
                itemBuilder: (context, index) {
                  final item = _inventory[index];
                  final lowStock = _isLowStock(item);
                  return Card(
                    elevation: 4,
                    color: lowStock ? Colors.red[100] : null,
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
                                  item['product_name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                lowStock ? 'Low Stock' : '',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[600], fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Text(
                            'Qty: ${item['quantity']} | Alert at: ${item['min_alert_qty']}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'Buy: ₹${item['buy_price'].toStringAsFixed(2)} | Sell: ₹${item['sell_price'].toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (item['brand'].isNotEmpty)
                            Text(
                              'Brand: ${item['brand']}',
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

// class InventoryManagementScreen extends StatefulWidget {
//   @override
//   _InventoryManagementScreenState createState() => _InventoryManagementScreenState();
// }

// class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _productNameController = TextEditingController();
//   final _quantityController = TextEditingController();
//   final _descriptionController = TextEditingController();
//   final _brandController = TextEditingController();
//   final _purchaseDateController = TextEditingController();
//   final _buyPriceController = TextEditingController();
//   final _sellPriceController = TextEditingController();
//   final _hsnController = TextEditingController();
//   final _minAlertQtyController = TextEditingController();

//   List<Map<String, dynamic>> _inventory = [];

//   @override
//   void initState() {
//     super.initState();
//     _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     _loadInventory();
//   }

//   Future<void> _loadInventory() async {
//     final db = await DBHelper().database;
//     final data = await db.query('inventory');
//     setState(() => _inventory = data);
//   }

//   Future<void> _saveInventory() async {
//     if (!_formKey.currentState!.validate()) return;

//     final db = await DBHelper().database;
//     await db.insert('inventory', {
//       'product_name': _productNameController.text,
//       'quantity': int.tryParse(_quantityController.text) ?? 0,
//       'description': _descriptionController.text,
//       'brand': _brandController.text,
//       'purchase_date': _purchaseDateController.text,
//       'buy_price': double.tryParse(_buyPriceController.text) ?? 0,
//       'sell_price': double.tryParse(_sellPriceController.text) ?? 0,
//       'hsn_code': _hsnController.text,
//       'min_alert_qty': int.tryParse(_minAlertQtyController.text) ?? 0,
//     });

//     _formKey.currentState!.reset();
//     _purchaseDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inventory Added.')));
//     _loadInventory();
//   }

//   bool _isLowStock(Map<String, dynamic> item) {
//     return (item['quantity'] as int) <= (item['min_alert_qty'] as int);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Inventory Management')),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Form(
//               key: _formKey,
//               child: Column(
//                 children: [
//                   TextFormField(controller: _productNameController, decoration: InputDecoration(labelText: 'Product Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
//                   TextFormField(controller: _quantityController, decoration: InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
//                   TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: 'Description')),
//                   TextFormField(controller: _brandController, decoration: InputDecoration(labelText: 'Brand / Make')),
//                   TextFormField(controller: _purchaseDateController, decoration: InputDecoration(labelText: 'Purchase Date')),
//                   TextFormField(controller: _buyPriceController, decoration: InputDecoration(labelText: 'Buying Price'), keyboardType: TextInputType.number),
//                   TextFormField(controller: _sellPriceController, decoration: InputDecoration(labelText: 'Selling Price'), keyboardType: TextInputType.number),
//                   TextFormField(controller: _hsnController, decoration: InputDecoration(labelText: 'HSN Code')),
//                   TextFormField(controller: _minAlertQtyController, decoration: InputDecoration(labelText: 'Minimum Alert Quantity'), keyboardType: TextInputType.number),
//                   SizedBox(height: 10),
//                   ElevatedButton(onPressed: _saveInventory, child: Text('Add Inventory')),
//                 ],
//               ),
//             ),
//             Divider(),
//             ListView.builder(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               itemCount: _inventory.length,
//               itemBuilder: (context, index) {
//                 final item = _inventory[index];
//                 final lowStock = _isLowStock(item);
//                 return Card(
//                   color: lowStock ? Colors.red[100] : null,
//                   child: ListTile(
//                     title: Text(item['product_name']),
//                     subtitle: Text('Qty: ${item['quantity']} | Alert at: ${item['min_alert_qty']}'),
//                     trailing: Text('₹${item['buy_price']} → ₹${item['sell_price']}'),
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
