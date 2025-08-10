import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'db_helper.dart';
import 'models.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  _ProductManagementScreenState createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  List<Product> _products = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _minAlertController = TextEditingController();
  double _gst = 5.0;
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
    _loadProducts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _hsnController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minAlertController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final db = await DBHelper().database;
    final result = await db.query('products');
    setState(() {
      _products = result.map((e) => Product.fromMap(e)).toList();
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    final db = await DBHelper().database;
    final product = Product(
      id: _editingId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      hsnCode: _hsnController.text.trim(),
      price: double.tryParse(_priceController.text) ?? 0.0,
      gst: _gst,
      quantity: int.tryParse(_stockController.text) ?? 0,
      minStock: int.tryParse(_minAlertController.text) ?? 0,
    );

    if (_editingId == null) {
      await db.insert('products', product.toMap());
    } else {
      await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [_editingId]);
    }

    _clearForm();
    await _loadProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editingId == null ? 'Product added successfully' : 'Product updated successfully'),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _hsnController.clear();
    _priceController.clear();
    _stockController.clear();
    _minAlertController.clear();
    _gst = 5.0;
    _editingId = null;
    setState(() {});
  }

  Future<void> _deleteProduct(int id) async {
    final db = await DBHelper().database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    await _loadProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Product deleted successfully'),
        backgroundColor: Colors.red[600],
      ),
    );
  }

  void _editProduct(Product product) {
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _hsnController.text = product.hsnCode;
    _priceController.text = product.price.toString();
    _stockController.text = product.quantity.toString();
    _minAlertController.text = product.minStock.toString();
    _gst = product.gst;
    _editingId = product.id;
    setState(() {});
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
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
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14),
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
          'Product Management',
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
            onPressed: _loadProducts,
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
                          _editingId == null ? 'Add New Product' : 'Edit Product',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          controller: _nameController,
                          label: 'Product Name',
                          validator: (value) => value!.trim().isEmpty ? 'Required' : null,
                        ),
                        _buildFormField(
                          controller: _descriptionController,
                          label: 'Description',
                        ),
                        _buildFormField(
                          controller: _hsnController,
                          label: 'HSN Code',
                        ),
                        _buildFormField(
                          controller: _priceController,
                          label: 'Price',
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value!.trim().isEmpty || double.tryParse(value) == null ? 'Valid number required' : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: DropdownButtonFormField<double>(
                            value: _gst,
                            items: [5, 12, 18, 28]
                                .map((e) => DropdownMenuItem(
                                      value: e.toDouble(),
                                      child: Text('$e%', style: GoogleFonts.poppins(fontSize: 14)),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() => _gst = value!);
                            },
                            decoration: InputDecoration(
                              labelText: 'GST %',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        _buildFormField(
                          controller: _stockController,
                          label: 'Quantity in Stock',
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value!.trim().isEmpty || int.tryParse(value) == null ? 'Valid number required' : null,
                        ),
                        _buildFormField(
                          controller: _minAlertController,
                          label: 'Minimum Alert Quantity',
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value!.trim().isEmpty || int.tryParse(value) == null ? 'Valid number required' : null,
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
                              onPressed: _saveProduct,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                _editingId == null ? 'Add Product' : 'Update Product',
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
                'Product List',
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
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
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
                                  product.name,
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
                                    onPressed: () => _editProduct(product),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteProduct(product.id!),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Stock: ${product.quantity} | Price: ₹${product.price.toStringAsFixed(2)} | GST: ${product.gst}%',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (product.quantity <= product.minStock)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Low Stock Alert!',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[600], fontWeight: FontWeight.w500),
                              ),
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
// import 'db_helper.dart';
// import 'models.dart';

// class ProductManagementScreen extends StatefulWidget {
//   const ProductManagementScreen({super.key});

//   @override
//   _ProductManagementScreenState createState() => _ProductManagementScreenState();
// }

// class _ProductManagementScreenState extends State<ProductManagementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   List<Product> _products = [];

//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   final TextEditingController _hsnController = TextEditingController();
//   final TextEditingController _priceController = TextEditingController();
//   double _gst = 5.0;
//   final TextEditingController _stockController = TextEditingController();
//   final TextEditingController _minAlertController = TextEditingController();
//   int? _editingId;

//   @override
//   void initState() {
//     super.initState();
//     _loadProducts();
//   }

//   Future<void> _loadProducts() async {
//     final db = await DBHelper().database;
//     final result = await db.query('products');
//     setState(() {
//       _products = result.map((e) => Product.fromMap(e)).toList();
//     });
//   }

//   Future<void> _saveProduct() async {
//     if (!_formKey.currentState!.validate()) return;
//     final db = await DBHelper().database;

//     final product = Product(
//       id: _editingId,
//       name: _nameController.text,
//       description: _descriptionController.text,
//       hsnCode: _hsnController.text,
//       price: double.parse(_priceController.text),
//       gst: _gst,
//       quantity: int.parse(_stockController.text),
//       minStock: int.parse(_minAlertController.text),
//     );

//     if (_editingId == null) {
//       await db.insert('products', product.toMap());
//     } else {
//       await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [_editingId]);
//     }

//     _clearForm();
//     _loadProducts();
//   }

//   void _clearForm() {
//     _nameController.clear();
//     _descriptionController.clear();
//     _hsnController.clear();
//     _priceController.clear();
//     _stockController.clear();
//     _minAlertController.clear();
//     _gst = 5.0;
//     _editingId = null;
//   }

//   Future<void> _deleteProduct(int id) async {
//     final db = await DBHelper().database;
//     await db.delete('products', where: 'id = ?', whereArgs: [id]);
//     _loadProducts();
//   }

//   void _editProduct(Product product) {
//     _nameController.text = product.name;
//     _descriptionController.text = product.description;
//     _hsnController.text = product.hsnCode;
//     _priceController.text = product.price.toString();
//     _stockController.text = product.quantity.toString();
//     _minAlertController.text = product.minStock.toString();
//     _gst = product.gst;
//     _editingId = product.id;
//     setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Product Management')),
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
//                     decoration: InputDecoration(labelText: 'Product Name'),
//                     validator: (value) => value!.isEmpty ? 'Required' : null,
//                   ),
//                   TextFormField(
//                     controller: _descriptionController,
//                     decoration: InputDecoration(labelText: 'Description'),
//                   ),
//                   TextFormField(
//                     controller: _hsnController,
//                     decoration: InputDecoration(labelText: 'HSN Code'),
//                   ),
//                   TextFormField(
//                     controller: _priceController,
//                     decoration: InputDecoration(labelText: 'Price'),
//                     keyboardType: TextInputType.number,
//                     validator: (value) => value!.isEmpty ? 'Required' : null,
//                   ),
//                   DropdownButtonFormField<double>(
//                     value: _gst,
//                     items: [5, 12, 18, 28]
//                         .map((e) => DropdownMenuItem(
//                               value: e.toDouble(),
//                               child: Text('$e%'),
//                             ))
//                         .toList(),
//                     onChanged: (value) {
//                       setState(() => _gst = value!);
//                     },
//                     decoration: InputDecoration(labelText: 'GST %'),
//                   ),
//                   TextFormField(
//                     controller: _stockController,
//                     decoration: InputDecoration(labelText: 'Quantity in Stock'),
//                     keyboardType: TextInputType.number,
//                   ),
//                   TextFormField(
//                     controller: _minAlertController,
//                     decoration: InputDecoration(labelText: 'Minimum Alert Quantity'),
//                     keyboardType: TextInputType.number,
//                   ),
//                   SizedBox(height: 12),
//                   ElevatedButton(
//                     onPressed: _saveProduct,
//                     child: Text(_editingId == null ? 'Add Product' : 'Update Product'),
//                   ),
//                 ],
//               ),
//             ),
//             Divider(),
//             ListView.builder(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               itemCount: _products.length,
//               itemBuilder: (context, index) {
//                 final product = _products[index];
//                 return ListTile(
//                   title: Text(product.name),
//                   subtitle: Text('Stock: ${product.quantity} | Price: ₹${product.price}'),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       IconButton(
//                         icon: Icon(Icons.edit, color: Colors.blue),
//                         onPressed: () => _editProduct(product),
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.delete, color: Colors.red),
//                         onPressed: () => _deleteProduct(product.id!),
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


















