import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// For number-to-words conversion. Please add this to your pubspec.yaml:
// dependencies:
//   number_to_words_en: ^1.0.2
import 'package:number_to_words_english/number_to_words_english.dart';

import 'db_helper.dart';
import 'sales_notifier.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
File? _userLogo;
String? _logoPath;

class InvoiceManagementScreen extends StatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  _InvoiceManagementScreenState createState() =>
      _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _date = DateTime.now();
  String _invoiceNo = '';
  final TextEditingController _deliveryNoteController = TextEditingController();
  final TextEditingController _paymentTermsController = TextEditingController();
  final TextEditingController _orderNoController = TextEditingController();
  final TextEditingController _orderDateController = TextEditingController();
  final TextEditingController _dispatchDocController = TextEditingController();
  String _dispatchMode = 'Courier';
  final TextEditingController _deliveryAddressController =
      TextEditingController();
  int? _selectedCustomerId;
  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _customers = [];
  final List<Map<String, dynamic>> _items = [];
  final TextEditingController _bankDetailsController = TextEditingController();
  final TextEditingController _signatoryController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  double get _totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item['amount']);

  @override
  void initState() {
    super.initState();
    _loadSavedLogo();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _animationController.forward();
    _generateInvoiceNumber();
    _loadCustomers();
  }

  Future<void> _loadSavedLogo() async {
    final prefs = await SharedPreferences.getInstance();
    _logoPath = prefs.getString('logoPath');
    if (_logoPath != null && File(_logoPath!).existsSync()) {
      setState(() => _userLogo = File(_logoPath!));
    }
  }

  @override
  void dispose() {
    _deliveryNoteController.dispose();
    _paymentTermsController.dispose();
    _orderNoController.dispose();
    _orderDateController.dispose();
    _dispatchDocController.dispose();
    _deliveryAddressController.dispose();
    _bankDetailsController.dispose();
    _signatoryController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateInvoiceNumber() async {
    final db = await DBHelper().database;
    final result =
        await db.rawQuery('SELECT COUNT(*)+1 as next FROM invoices');
    _invoiceNo =
        'INV-${DateFormat('yyyyMM').format(DateTime.now())}-${result.first['next'].toString().padLeft(4, '0')}';
    setState(() {});
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
        final TextEditingController hsn = TextEditingController();
        final TextEditingController qty = TextEditingController();
        final TextEditingController rate = TextEditingController();
        final TextEditingController unit = TextEditingController();
        final TextEditingController discount = TextEditingController();
        final TextEditingController tax = TextEditingController();
        final formKey = GlobalKey<FormState>();

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Add Line Item',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFormField(
                      controller: desc,
                      label: 'Description',
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Required' : null),
                  _buildFormField(controller: hsn, label: 'HSN/SAC No.'),
                  _buildFormField(
                    controller: qty,
                    label: 'Quantity',
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.trim().isEmpty ||
                            int.tryParse(value) == null
                        ? 'Valid number required'
                        : null,
                  ),
                  _buildFormField(
                    controller: rate,
                    label: 'Rate',
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.trim().isEmpty ||
                            double.tryParse(value) == null
                        ? 'Valid number required'
                        : null,
                  ),
                  _buildFormField(controller: unit, label: 'Unit'),
                  _buildFormField(
                    controller: discount,
                    label: 'Discount %',
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.trim().isEmpty ||
                            double.tryParse(value) == null
                        ? 'Valid number required'
                        : null,
                  ),
                  _buildFormField(
                    controller: tax,
                    label: 'Tax %',
                    keyboardType: TextInputType.number,
                    validator: (value) => value!.trim().isEmpty ||
                            double.tryParse(value) == null
                        ? 'Valid number required'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey[600])),
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
                  'hsn': hsn.text.trim(),
                  'qty': q,
                  'rate': r,
                  'unit': unit.text.trim(),
                  'discount': d,
                  'tax': t,
                  'amount': taxed,
                });
                setState(() {});
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child:
                  Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCustomer == null ||
        _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedCustomer == null
              ? 'Please select a customer'
              : 'Please add at least one item'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final db = await DBHelper().database;
    final invoiceId = await db.insert('invoices', {
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'invoice_no': _invoiceNo,
      'delivery_note': _deliveryNoteController.text.trim(),
      'payment_terms': _paymentTermsController.text.trim(),
      'order_no': _orderNoController.text.trim(),
      'order_date': _orderDateController.text.trim(),
      'dispatch_doc_no': _dispatchDocController.text.trim(),
      'dispatch_mode': _dispatchMode,
      'delivery_address': _deliveryAddressController.text.trim(),
      'buyer_id': _selectedCustomerId,
      'gst_no': _selectedCustomer!['gst_number'],
      'state': _selectedCustomer!['state'],
      'state_code': _selectedCustomer!['state_code'],
      'total_amount': _totalAmount,
      'amount_words': _convertToWords(_totalAmount.toInt()),
      'bank_details': _bankDetailsController.text.trim(),
      'signatory': _signatoryController.text.trim(),
    });

    for (final item in _items) {
      await db.insert('invoice_items', {
        'invoice_id': invoiceId,
        'description': item['desc'],
        'hsn': item['hsn'],
        'quantity': item['qty'],
        'rate': item['rate'],
        'unit': item['unit'],
        'discount': item['discount'],
        'tax': item['tax'],
        'amount': item['amount'],
      });
    }

    final pdf = await _generatePDF(invoiceId);
    final Uint8List bytes = await pdf.save();
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$_invoiceNo.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // Refresh dashboard sales total
    if (mounted) {
      Provider.of<SalesNotifier>(context, listen: false).refresh();
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice saved to: $filePath'),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () {
            Share.shareXFiles(
              [XFile(filePath, name: '$_invoiceNo.pdf')],
              text: 'Invoice $_invoiceNo',
            );
          },
        ),
      ),
    );

    _clearForm();
  }

  void _clearForm() {
    _deliveryNoteController.clear();
    _paymentTermsController.clear();
    _orderNoController.clear();
    _orderDateController.clear();
    _dispatchDocController.clear();
    _deliveryAddressController.clear();
    _bankDetailsController.clear();
    _signatoryController.clear();
    _selectedCustomerId = null;
    _selectedCustomer = null;
    _items.clear();
    _generateInvoiceNumber();
    setState(() {});
  }


  Future<pw.Document> _generatePDF(int invoiceId) async {
  final pdf = pw.Document();
  // formatCurrency(double val) => '₹${val.toStringAsFixed(2)}';
  formatCurrency(double val) => 'INR ${val.toStringAsFixed(2)}';

  // Load company settings from database
  final companySettings = await _loadCompanySettings();
  final bankAccounts = await _loadBankAccounts();

  // Load user logo if exists
  final pw.MemoryImage? logoImage;
  if (_logoPath != null && File(_logoPath!).existsSync()) {
    final Uint8List logoData = await File(_logoPath!).readAsBytes();
    logoImage = pw.MemoryImage(logoData);
  } else {
    logoImage = null;
  }

  // Load signature if exists in company settings
  pw.MemoryImage? signatureImage;
  if (companySettings['signaturePath'] != null && 
      File(companySettings['signaturePath']).existsSync()) {
    final Uint8List signatureData = await File(companySettings['signaturePath']).readAsBytes();
    signatureImage = pw.MemoryImage(signatureData);
  }

  // State code comparison
  final sellerStateCode = companySettings['stateCode'] ?? '27'; // Use from settings or default
  final buyerStateCode = _selectedCustomer!['state_code'].toString();
  final isInterState = buyerStateCode != sellerStateCode;

  // Define clean theme - matching Marine invoice style
  final theme = pw.ThemeData.withFont(
    base: pw.Font.helvetica(),
    bold: pw.Font.helveticaBold(),
    italic: pw.Font.helveticaOblique(),
  );

  // Professional color scheme - matching the reference PDF
  final borderColor = PdfColor.fromHex('#000000');
  final headerBg = PdfColor.fromHex('#F5F5F5');
  final textColor = PdfColor.fromHex('#000000');
  final lightGray = PdfColor.fromHex('#F8F8F8');

  pdf.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        theme: theme,
        margin: const pw.EdgeInsets.all(20),
        pageFormat: PdfPageFormat.a4,
      ),
      build: (context) => [
        // Header Section - Company Info & Invoice Title
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Column(
            children: [
              // Top header with e-Invoice and company details
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                color: headerBg,
                child: pw.Center(
                  child: pw.Text(
                    'e-Invoice',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              
              // Company details and logo section
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Company info
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (logoImage != null) ...[
                                pw.Image(logoImage, height: 60, fit: pw.BoxFit.contain),
                                pw.SizedBox(height: 10),
                              ],
                              pw.Text(
                                companySettings['companyName'] ?? 'CIS SOLUTIONS',
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text(
                                companySettings['address'] ?? '402 Gera Imperium I, Patto Plaza, Panjim, Goa – 403 001, INDIA',
                                style: pw.TextStyle(fontSize: 10, color: textColor),
                              ),
                              pw.Text(
                                'Tel: +91 XXXXXXXXXX',
                                style: pw.TextStyle(fontSize: 10, color: textColor),
                              ),
                              pw.Text(
                                'email: info@cissolutions.com / www.cissolutions.com',
                                style: pw.TextStyle(fontSize: 10, color: textColor),
                              ),
                            ],
                          ),
                        ),
                        // TAX INVOICE title
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'TAX INVOICE',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // GSTIN and Invoice details row
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GSTIN Number: ${companySettings['gst'] ?? '27ALLPD1172E1ZF'}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('PAN Number: ${companySettings['pan'] ?? 'ALLPD1172E'}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Place OF Supply: ${_selectedCustomer!['state']}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Terms of Delivery: ${_selectedCustomer!['payment_terms'] ?? 'As per agreement'}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Invoice Number: $_invoiceNo', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Invoice Date: ${DateFormat('dd/MM/yyyy').format(_date)}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Payment Due Date: ${DateFormat('dd/MM/yyyy').format(_date)}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Purchase Order No: ${_orderNoController.text}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Delivery Date: ${_orderDateController.text}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Dispatch No & Date: ${_dispatchDocController.text}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 10),

        // Customer Details Section
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Row(
            children: [
              // Billed To
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(color: borderColor, width: 1)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        color: headerBg,
                        child: pw.Text(
                          'Details of Receiver (Billed to)',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Name: ${_selectedCustomer!['name']}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Address: ${_selectedCustomer!['billing_address']}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('State: ${_selectedCustomer!['state']} State Code: $buyerStateCode', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('GSTIN Number: ${_selectedCustomer!['gst_number']}', style: const pw.TextStyle(fontSize: 10)),
                      if (_selectedCustomer!['contact_person'] != null)
                        pw.Text('Contact Person: ${_selectedCustomer!['contact_person']}', style: const pw.TextStyle(fontSize: 10)),
                      if (_selectedCustomer!['mobile'] != null)
                        pw.Text('Contact No: ${_selectedCustomer!['mobile']}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
              // Shipped To
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        color: headerBg,
                        child: pw.Text(
                          'Details of Consignee (Shipped to)',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Name: ${_selectedCustomer!['name']}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Address: ${_selectedCustomer!['shipping_address'] ?? _selectedCustomer!['billing_address']}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('State: ${_selectedCustomer!['state']}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('State Code: $buyerStateCode', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('GSTIN Number: ${_selectedCustomer!['gst_number']}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 10),

        // Items Table
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Column(
            children: [
              // Table Header
              pw.Container(
                color: headerBg,
                child: pw.Row(
                  children: [
                    _buildTableCell('S.\nNo', 30, true),
                    _buildTableCell('Description of Goods', 150, true),
                    _buildTableCell('HSN\nCode', 50, true),
                    _buildTableCell('Qty\nUOM', 45, true),
                    _buildTableCell('Rate', 50, true),
                    _buildTableCell('Total\nAmount', 60, true),
                    _buildTableCell('GST\nRate\n%', 40, true),
                    _buildTableCell('CGST\nAmount', 50, true),
                    _buildTableCell('SGST\nAmount', 50, true),
                    _buildTableCell('IGST\nAmount', 50, true),
                  ],
                ),
              ),
              // Table Rows
              ...List.generate(_items.length, (i) {
                final item = _items[i];
                final taxableAmount = item['rate'] * item['qty'] * (1 - item['discount'] / 100);
                final totalTax = taxableAmount * item['tax'] / 100;
                final halfTax = totalTax / 2;
                
                return pw.Container(
                  decoration: pw.BoxDecoration(
                    color: i % 2 == 0 ? lightGray : PdfColors.white,
                    border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      _buildTableCell('${i + 1}', 30, false),
                      _buildTableCell(item['desc'], 150, false),
                      _buildTableCell(item['hsn'], 50, false),
                      _buildTableCell('${item['qty']}\n${item['unit']}', 45, false),
                      _buildTableCell(formatCurrency(item['rate']), 50, false),
                      _buildTableCell(formatCurrency(item['amount']), 60, false),
                      _buildTableCell('${item['tax']}', 40, false),
                      _buildTableCell(isInterState ? '0.00' : formatCurrency(halfTax), 50, false),
                      _buildTableCell(isInterState ? '0.00' : formatCurrency(halfTax), 50, false),
                      _buildTableCell(isInterState ? formatCurrency(totalTax) : '0.00', 50, false),
                    ],
                  ),
                );
              }),
              // Total Row
              pw.Container(
                color: headerBg,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Row(
                  children: [
                    _buildTableCell('Total', 275, true),
                    _buildTableCell(formatCurrency(_totalAmount - _getTotalTax()), 60, true),
                    _buildTableCell('', 40, true),
                    _buildTableCell(formatCurrency(isInterState ? 0 : _getTotalTax() / 2), 50, true),
                    _buildTableCell(formatCurrency(isInterState ? 0 : _getTotalTax() / 2), 50, true),
                    _buildTableCell(formatCurrency(isInterState ? _getTotalTax() : 0), 50, true),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 10),

        // Total Amount Section
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Row(
            children: [
              // Left side - Bank details from profile settings
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(color: borderColor, width: 1)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bank Details:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      ...bankAccounts.map((bank) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          'Bank Name: ${bank['accountName']}\nA/c No: ${bank['accountNumber']}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      )),
                      if (bankAccounts.isEmpty)
                        pw.Text(
                          _bankDetailsController.text.isNotEmpty ? _bankDetailsController.text : 
                          'Bank Name: HDFC BANK\nA/c No: XXXXXXXXXX\nBranch: PANJIM, GOA\nIFS Code: HDFC0000XXX', 
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ),
              // Right side - Amount details
              pw.Expanded(
                flex: 1,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Invoice Total', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text(formatCurrency(_totalAmount), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Rounding', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('0.00', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Advance', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('0', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Balance Due', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text(formatCurrency(_totalAmount), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 5),

        // Amount in words
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Text(
            'Invoice Value (In Words): INR ${_convertToWords(_totalAmount.toInt())} Only',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),

        pw.SizedBox(height: 10),

        // Footer Section
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Row(
            children: [
              // Left - IRN Details
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(right: pw.BorderSide(color: borderColor, width: 1)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('IRN NO, ACK NO & ACK Date', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 40),
                      pw.Text('Received in Goods Condition', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Name, Stamp & Receiver\'s Signature', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
              // Right - Company signature from profile settings
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('For ${companySettings['companyName'] ?? 'CIS Solutions'}', style: const pw.TextStyle(fontSize: 11)),
                      pw.SizedBox(height: 20),
                      // Display signature image if available
                      if (signatureImage != null) ...[
                        pw.Image(signatureImage, height: 40, fit: pw.BoxFit.contain),
                        pw.SizedBox(height: 10),
                      ] else ...[
                        pw.SizedBox(height: 30),
                      ],
                      pw.Text('Signature:', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.Text(_signatoryController.text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Authorised Signatory', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 10),

        // Footer text
        pw.Center(
          child: pw.Text(
            'Printed by CIS ERP System',
            style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
          ),
        ),
      ],
    ),
  );

  return pdf;
}

// Add these helper methods to load company settings from database
Future<Map<String, dynamic>> _loadCompanySettings() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'company_settings.db');
    final db = await openDatabase(path);
    
    final settings = await db.query('settings', limit: 1);
    await db.close();
    
    if (settings.isNotEmpty) {
      return settings.first;
    }
    return {};
  } catch (e) {
    print('Error loading company settings: $e');
    return {};
  }
}

Future<List<Map<String, dynamic>>> _loadBankAccounts() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'company_settings.db');
    final db = await openDatabase(path);
    
    final bankRows = await db.query('bank_accounts');
    await db.close();
    
    return bankRows;
  } catch (e) {
    print('Error loading bank accounts: $e');
    return [];
  }
}

// Helper method for building table cells (you may already have this)
pw.Widget _buildTableCell(String text, double width, bool isHeader) {
  return pw.Container(
    width: width,
    padding: const pw.EdgeInsets.all(4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        right: pw.BorderSide(color: PdfColor.fromHex('#000000'), width: 0.5),
      ),
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: isHeader ? 9 : 8,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      textAlign: pw.TextAlign.center,
    ),
  );
}



// Helper method to calculate total tax
double _getTotalTax() {
  return _items.fold(0.0, (sum, item) {
    final taxableAmount = item['rate'] * item['qty'] * (1 - item['discount'] / 100);
    return sum + (taxableAmount * item['tax'] / 100);
  });
}

  Future<void> _pickAndSaveLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logoPath', path);
      setState(() {
        _logoPath = path;
        _userLogo = File(path);
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Logo updated successfully'),
              backgroundColor: Colors.green),
        );
      }
    }
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    bool isMultiLine = false,
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
        maxLines: isMultiLine ? 3 : 1,
        minLines: isMultiLine ? 3 : 1,
        keyboardType: keyboardType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600
        ? 1
        : screenWidth < 900
            ? 2
            : 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Invoice Management',
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
            tooltip: 'Reset Form',
          ),
          IconButton(
            icon: const Icon(Icons.image, color: Colors.white),
            tooltip: 'Upload Logo',
            onPressed: _pickAndSaveLogo,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Invoice #$_invoiceNo',
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
                          child: Text(cust['name'],
                              style: GoogleFonts.poppins(fontSize: 14)),
                          onTap: () => _selectedCustomer = cust,
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCustomerId = val),
                      decoration: InputDecoration(
                        labelText: 'Select Customer',
                        labelStyle:
                            GoogleFonts.poppins(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    _buildFormField(
                        controller: _deliveryNoteController,
                        label: 'Delivery Note'),
                    _buildFormField(
                        controller: _paymentTermsController,
                        label: 'Payment Terms'),
                    _buildFormField(
                        controller: _orderNoController,
                        label: 'Buyer\'s Order No.'),
                    _buildFormField(
                        controller: _orderDateController, label: 'Order Date'),
                    _buildFormField(
                        controller: _dispatchDocController,
                        label: 'Dispatched Doc No.'),
                    DropdownButtonFormField<String>(
                      value: _dispatchMode,
                      items: [
                        'Courier',
                        'By Hand',
                        'Porter',
                        'Hand Delivery',
                        'Other'
                      ]
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child:
                                  Text(e, style: GoogleFonts.poppins(fontSize: 14))))
                          .toList(),
                      onChanged: (v) => setState(() => _dispatchMode = v!),
                      decoration: InputDecoration(
                        labelText: 'Dispatch Mode',
                        labelStyle:
                            GoogleFonts.poppins(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    _buildFormField(
                      controller: _deliveryAddressController,
                      label: 'Delivery Address',
                      isMultiLine: true,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Line Items',
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
                      label: Text('Add Line Item',
                          style: GoogleFonts.poppins(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () {
                                        setState(() => _items.removeAt(index));
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  'Amount: ₹${item['amount'].toStringAsFixed(2)} | Qty: ${item['qty']}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                        controller: _bankDetailsController,
                        label: 'Bank Details',
                        isMultiLine: true),
                    _buildFormField(
                      controller: _signatoryController,
                      label: 'Authorized Signatory',
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: ₹${_totalAmount.toStringAsFixed(2)}',
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
                              child: Text('Clear',
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey[600])),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _saveInvoice,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Save & Share Invoice',
                                style: GoogleFonts.poppins(
                                    color: Colors.white, fontSize: 14),
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

  String _convertToWords(int amount) {
    // Using the number_to_words_en package for accurate conversion.
    // Add `number_to_words_en: ^1.0.2` to your pubspec.yaml
    try {
      // Capitalize the first letter of each word
      String words = NumberToWordsEnglish.convert(amount);
      return '${words.split(' ').map((e) => e[0].toUpperCase() + e.substring(1)).join(' ')} Rupees Only';
    } catch (e) {
      return '$amount Rupees Only'; // Fallback
    }
  }
}

/// Extension for adding opacity to a [PdfColor].
extension PdfColorExtension on PdfColor {
  /// Returns a new [PdfColor] with the given opacity.
  PdfColor withOpacity(double opacity) {
    return PdfColor(
      red,
      green,
      blue,
      alpha * opacity.clamp(0.0, 1.0),
    );
  }
}


















// import 'package:file_picker/file_picker.dart';
// // import 'package:open_filex/open_filex.dart';
// import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart' show rootBundle;
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:vyapar/sales_notifier.dart';
// import 'dart:typed_data';
// import 'db_helper.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';

// File? _userLogo;
// String? _logoPath;

// class InvoiceManagementScreen extends StatefulWidget {
//   const InvoiceManagementScreen({super.key});

//   @override
//   _InvoiceManagementScreenState createState() => _InvoiceManagementScreenState();
// }

// class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> with SingleTickerProviderStateMixin {
//   final _formKey = GlobalKey<FormState>();
//   final _date = DateTime.now();
//   String _invoiceNo = '';
//   final TextEditingController _deliveryNoteController = TextEditingController();
//   final TextEditingController _paymentTermsController = TextEditingController();
//   final TextEditingController _orderNoController = TextEditingController();
//   final TextEditingController _orderDateController = TextEditingController();
//   final TextEditingController _dispatchDocController = TextEditingController();
//   String _dispatchMode = 'Courier';
//   final TextEditingController _deliveryAddressController = TextEditingController();
//   int? _selectedCustomerId;
//   Map<String, dynamic>? _selectedCustomer;
//   List<Map<String, dynamic>> _customers = [];
//   final List<Map<String, dynamic>> _items = [];
//   final TextEditingController _bankDetailsController = TextEditingController();
//   final TextEditingController _signatoryController = TextEditingController();
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;

//   double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item['amount']);

//   @override
// void initState() {
//   super.initState();
//   _loadSavedLogo();
//   _animationController = AnimationController(
//     vsync: this,
//     duration: const Duration(milliseconds: 800),
//   );
//   _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
//   _animationController.forward();
//   _generateInvoiceNumber();
//   _loadCustomers();
// }

// Future<void> _loadSavedLogo() async {
//   final prefs = await SharedPreferences.getInstance();
//   _logoPath = prefs.getString('logoPath');
//   if (_logoPath != null && File(_logoPath!).existsSync()) {
//     setState(() => _userLogo = File(_logoPath!));
//   }
// }


//   @override
//   void dispose() {
//     _deliveryNoteController.dispose();
//     _paymentTermsController.dispose();
//     _orderNoController.dispose();
//     _orderDateController.dispose();
//     _dispatchDocController.dispose();
//     _deliveryAddressController.dispose();
//     _bankDetailsController.dispose();
//     _signatoryController.dispose();
//     _animationController.dispose();
//     super.dispose();
//   }

//   Future<void> _generateInvoiceNumber() async {
//     final db = await DBHelper().database;
//     final result = await db.rawQuery('SELECT COUNT(*)+1 as next FROM invoices');
//     _invoiceNo = 'INV-${DateFormat('yyyyMM').format(DateTime.now())}-${result.first['next'].toString().padLeft(4, '0')}';
//     setState(() {});
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
//         final TextEditingController hsn = TextEditingController();
//         final TextEditingController qty = TextEditingController();
//         final TextEditingController rate = TextEditingController();
//         final TextEditingController unit = TextEditingController();
//         final TextEditingController discount = TextEditingController();
//         final TextEditingController tax = TextEditingController();
//         final formKey = GlobalKey<FormState>();

//         return AlertDialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           title: Text('Add Line Item', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
//           content: SingleChildScrollView(
//             child: Form(
//               key: formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   _buildFormField(controller: desc, label: 'Description', validator: (value) => value!.trim().isEmpty ? 'Required' : null),
//                   _buildFormField(controller: hsn, label: 'HSN/SAC No.'),
//                   _buildFormField(
//                     controller: qty,
//                     label: 'Quantity',
//                     keyboardType: TextInputType.number,
//                     validator: (value) => value!.trim().isEmpty || int.tryParse(value) == null ? 'Valid number required' : null,
//                   ),
//                   _buildFormField(
//                     controller: rate,
//                     label: 'Rate',
//                     keyboardType: TextInputType.number,
//                     validator: (value) => value!.trim().isEmpty || double.tryParse(value) == null ? 'Valid number required' : null,
//                   ),
//                   _buildFormField(controller: unit, label: 'Unit'),
//                   _buildFormField(
//                     controller: discount,
//                     label: 'Discount %',
//                     keyboardType: TextInputType.number,
//                     validator: (value) => value!.trim().isEmpty || double.tryParse(value) == null ? 'Valid number required' : null,
//                   ),
//                   _buildFormField(
//                     controller: tax,
//                     label: 'Tax %',
//                     keyboardType: TextInputType.number,
//                     validator: (value) => value!.trim().isEmpty || double.tryParse(value) == null ? 'Valid number required' : null,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[600])),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (!formKey.currentState!.validate()) return;
//                 final q = int.tryParse(qty.text) ?? 0;
//                 final r = double.tryParse(rate.text) ?? 0;
//                 final d = double.tryParse(discount.text) ?? 0;
//                 final t = double.tryParse(tax.text) ?? 0;
//                 double discounted = r * q * (1 - d / 100);
//                 double taxed = discounted * (1 + t / 100);
//                 _items.add({
//                   'desc': desc.text.trim(),
//                   'hsn': hsn.text.trim(),
//                   'qty': q,
//                   'rate': r,
//                   'unit': unit.text.trim(),
//                   'discount': d,
//                   'tax': t,
//                   'amount': taxed,
//                 });
//                 setState(() {});
//                 Navigator.pop(context);
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF2C3E50),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               ),
//               child: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _saveInvoice() async {
//     if (!_formKey.currentState!.validate() || _selectedCustomer == null || _items.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(_selectedCustomer == null ? 'Please select a customer' : 'Please add at least one item'),
//           backgroundColor: Colors.red[600],
//         ),
//       );
//       return;
//     }

//     final db = await DBHelper().database;
//     final invoiceId = await db.insert('invoices', {
//       'date': DateFormat('yyyy-MM-dd').format(_date),
//       'invoice_no': _invoiceNo,
//       'delivery_note': _deliveryNoteController.text.trim(),
//       'payment_terms': _paymentTermsController.text.trim(),
//       'order_no': _orderNoController.text.trim(),
//       'order_date': _orderDateController.text.trim(),
//       'dispatch_doc_no': _dispatchDocController.text.trim(),
//       'dispatch_mode': _dispatchMode,
//       'delivery_address': _deliveryAddressController.text.trim(),
//       'buyer_id': _selectedCustomerId,
//       'gst_no': _selectedCustomer!['gst_number'],
//       'state': _selectedCustomer!['state'],
//       'state_code': _selectedCustomer!['state_code'],
//       'total_amount': _totalAmount,
//       'amount_words': _convertToWords(_totalAmount.toInt()),
//       'bank_details': _bankDetailsController.text.trim(),
//       'signatory': _signatoryController.text.trim(),
//     });

//     for (final item in _items) {
//       await db.insert('invoice_items', {
//         'invoice_id': invoiceId,
//         'description': item['desc'],
//         'hsn': item['hsn'],
//         'quantity': item['qty'],
//         'rate': item['rate'],
//         'unit': item['unit'],
//         'discount': item['discount'],
//         'tax': item['tax'],
//         'amount': item['amount'],
//       });
//     }

//     final pdf = await _generatePDF(invoiceId);
//     final Uint8List bytes = await pdf.save();
//     final directory = await getTemporaryDirectory();
//     final filePath = '${directory.path}/$_invoiceNo.pdf';
//     final file = File(filePath);
//     await file.writeAsBytes(bytes);
    

//     // ⬇️ Refresh dashboard sales total
//     Provider.of<SalesNotifier>(context, listen: false).refresh();
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Invoice saved to: $filePath'),
//         backgroundColor: Colors.green[600],
//         duration: const Duration(seconds: 5),
//         action: SnackBarAction(
//           label: 'Share',
//           onPressed: () {
//             Share.shareXFiles(
//               [XFile(filePath, name: '$_invoiceNo.pdf')],
//               text: 'Invoice $_invoiceNo',
//             );
//           },
//         ),
//       ),
//     );

//     _clearForm();
//   }

//   void _clearForm() {
//     _deliveryNoteController.clear();
//     _paymentTermsController.clear();
//     _orderNoController.clear();
//     _orderDateController.clear();
//     _dispatchDocController.clear();
//     _deliveryAddressController.clear();
//     _bankDetailsController.clear();
//     _signatoryController.clear();
//     _selectedCustomerId = null;
//     _selectedCustomer = null;
//     _items.clear();
//     _generateInvoiceNumber();
//     setState(() {});
//   }
     
//   Future<pw.Document> _generatePDF(int invoiceId) async {
//   final pdf = pw.Document();
//   formatCurrency(double val) => '₹${val.toStringAsFixed(2)}';

//   // Load user logo if exists
//   final pw.MemoryImage? logoImage;
//   if (_logoPath != null && File(_logoPath!).existsSync()) {
//     final Uint8List logoData = await File(_logoPath!).readAsBytes();
//     logoImage = pw.MemoryImage(logoData);
//   } else {
//     logoImage = null;
//   }

//   // State code comparison
//   const sellerStateCode = '27'; // Maharashtra
//   final buyerStateCode = _selectedCustomer!['state_code'].toString();
//   final isInterState = buyerStateCode != sellerStateCode;

//   pdf.addPage(
//     pw.Page(
//       margin: const pw.EdgeInsets.all(20),
//       build: (context) {
//         return pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             if (logoImage != null)
//               pw.Center(child: pw.Image(logoImage, height: 60)),
//             pw.SizedBox(height: 10),

//             pw.Text('CIS SOLUTIONS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
//             pw.Text('402 Gera Imperium I, Patto Plaza, Panjim, Goa – 403 001, INDIA.'),
//             pw.Text('GSTIN/UIN: 27ALLPD1172E1ZF'),
//             pw.SizedBox(height: 10),

//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
//                   pw.Text('Invoice No: $_invoiceNo'),
//                   pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(_date)}'),
//                   pw.Text('Delivery Note: ${_deliveryNoteController.text}'),
//                   pw.Text('Dispatch Document No: ${_dispatchDocController.text}'),
//                 ]),
//                 pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
//                   pw.Text('Buyers Order No: ${_orderNoController.text}'),
//                   pw.Text('Dated: ${_orderDateController.text}'),
//                   pw.Text('Dispatch Mode: $_dispatchMode'),
//                 ]),
//               ],
//             ),
//             pw.SizedBox(height: 10),

//             pw.Text('Buyer: ${_selectedCustomer!['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//             pw.Text('GSTIN: ${_selectedCustomer!['gst_number']}'),
//             pw.Text('Billing Address: ${_selectedCustomer!['billing_address']}'),
//             pw.Text('State Name: ${_selectedCustomer!['state']} Code: $buyerStateCode'),
//             pw.SizedBox(height: 10),

//             pw.Table.fromTextArray(
//               headers: ['Sl No.', 'Description', 'HSN/SAC', 'Qty', 'Rate', 'Per', 'Disc %', 'Amount'],
//               data: List.generate(_items.length, (i) {
//                 final item = _items[i];
//                 return [
//                   '${i + 1}',
//                   item['desc'],
//                   item['hsn'],
//                   item['qty'].toString(),
//                   formatCurrency(item['rate']),
//                   item['unit'],
//                   item['discount'].toString(),
//                   formatCurrency(item['amount']),
//                 ];
//               }),
//               headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//               cellAlignment: pw.Alignment.centerLeft,
//             ),
//             pw.SizedBox(height: 10),

//             pw.Text('Tax Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//             pw.Table.fromTextArray(
//               headers: ['Tax Type', 'Rate', 'Amount'],
//               data: _items.expand((item) {
//                 final taxableAmount = item['rate'] * item['qty'] * (1 - item['discount'] / 100);
//                 final totalTax = taxableAmount * item['tax'] / 100;
//                 final halfTax = totalTax / 2;
//                 if (isInterState) {
//                   return [['IGST', '${item['tax']}%', formatCurrency(totalTax)]];
//                 } else {
//                   return [
//                     ['CGST', '${item['tax'] / 2}%', formatCurrency(halfTax)],
//                     ['SGST', '${item['tax'] / 2}%', formatCurrency(halfTax)],
//                   ];
//                 }
//               }).toList(),
//               headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//               cellAlignment: pw.Alignment.centerLeft,
//             ),
//             pw.SizedBox(height: 10),

//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.end,
//               children: [
//                 pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
//                   pw.Text('Total: ${formatCurrency(_totalAmount)}'),
//                   pw.Text('Rounded Off: ${formatCurrency(_totalAmount.roundToDouble())}'),
//                   pw.Text('Amount in words: Rs. ${_convertToWords(_totalAmount.toInt())}'),
//                 ]),
//               ],
//             ),
//             pw.SizedBox(height: 10),

//             pw.Text('Bank Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//             pw.Text(_bankDetailsController.text),
//             pw.SizedBox(height: 10),

//             pw.Text('Declaration:'),
//             pw.Text('We declare that this invoice shows the actual price of the services/goods described and that all particulars are true and correct.'),
//             pw.SizedBox(height: 20),

//             pw.Align(
//               alignment: pw.Alignment.centerRight,
//               child: pw.Column(
//                 crossAxisAlignment: pw.CrossAxisAlignment.end,
//                 children: [
//                   pw.Text('For CIS Solutions'),
//                   pw.SizedBox(height: 30),
//                   pw.Text(_signatoryController.text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
//                   pw.Text('Authorized Signatory'),
//                 ],
//               ),
//             ),
//           ],
//         );
//       },
//     ),
//   );

//   return pdf;
// }

// Future<void> _pickAndSaveLogo() async {
//   final result = await FilePicker.platform.pickFiles(type: FileType.image);
//   if (result != null && result.files.single.path != null) {
//     final path = result.files.single.path!;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('logoPath', path);
//     setState(() {
//       _logoPath = path;
//       _userLogo = File(path);
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Logo updated successfully'), backgroundColor: Colors.green),
//     );
//   }
// }


//   Widget _buildFormField({
//     required TextEditingController controller,
//     required String label,
//     String? Function(String?)? validator,
//     bool isMultiLine = false,
//     TextInputType? keyboardType,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: TextFormField(
//         controller: controller,
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           filled: true,
//           fillColor: Colors.white,
//         ),
//         validator: validator,
//         style: GoogleFonts.poppins(fontSize: 14),
//         maxLines: isMultiLine ? 3 : 1,
//         minLines: isMultiLine ? 3 : 1,
//         keyboardType: keyboardType,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final crossAxisCount = screenWidth < 600 ? 1 : screenWidth < 900 ? 2 : 3;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         title: Text(
//           'Invoice Management',
//           style: GoogleFonts.poppins(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF2C3E50),
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh, color: Colors.white),
//             onPressed: () {
//               _clearForm();
//               _loadCustomers();
//             },
//             tooltip: 'Reset Form',
//           ),

//           IconButton(
//              icon: const Icon(Icons.image, color: Colors.white),
//             tooltip: 'Upload Logo',
//             onPressed: _pickAndSaveLogo,
//       ),

//         ],
//       ),
//       body: FadeTransition(
//         opacity: _fadeAnimation,
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Card(
//             elevation: 4,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Create Invoice #$_invoiceNo',
//                       style: GoogleFonts.poppins(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     DropdownButtonFormField<int>(
//                       value: _selectedCustomerId,
//                       items: _customers.map<DropdownMenuItem<int>>((cust) {
//                         return DropdownMenuItem<int>(
//                           value: cust['id'] as int,
//                           child: Text(cust['name'], style: GoogleFonts.poppins(fontSize: 14)),
//                           onTap: () => _selectedCustomer = cust,
//                         );
//                       }).toList(),
//                       onChanged: (val) => setState(() => _selectedCustomerId = val),
//                       decoration: InputDecoration(
//                         labelText: 'Select Customer',
//                         labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         filled: true,
//                         fillColor: Colors.white,
//                       ),
//                       validator: (value) => value == null ? 'Required' : null,
//                     ),
//                     _buildFormField(controller: _deliveryNoteController, label: 'Delivery Note'),
//                     _buildFormField(controller: _paymentTermsController, label: 'Payment Terms'),
//                     _buildFormField(controller: _orderNoController, label: 'Buyer\'s Order No.'),
//                     _buildFormField(controller: _orderDateController, label: 'Order Date'),
//                     _buildFormField(controller: _dispatchDocController, label: 'Dispatched Doc No.'),
//                     DropdownButtonFormField<String>(
//                       value: _dispatchMode,
//                       items: ['Courier', 'By Hand', 'Porter', 'Hand Delivery', 'Other']
//                           .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 14))))
//                           .toList(),
//                       onChanged: (v) => setState(() => _dispatchMode = v!),
//                       decoration: InputDecoration(
//                         labelText: 'Dispatch Mode',
//                         labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         filled: true,
//                         fillColor: Colors.white,
//                       ),
//                     ),
//                     _buildFormField(
//                       controller: _deliveryAddressController,
//                       label: 'Delivery Address',
//                       isMultiLine: true,
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       'Line Items',
//                       style: GoogleFonts.poppins(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     ElevatedButton.icon(
//                       onPressed: _addItem,
//                       icon: const Icon(Icons.add, color: Colors.white),
//                       label: Text('Add Line Item', style: GoogleFonts.poppins(color: Colors.white)),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF2C3E50),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     GridView.builder(
//                       shrinkWrap: true,
//                       physics: const NeverScrollableScrollPhysics(),
//                       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: crossAxisCount,
//                         crossAxisSpacing: 16,
//                         mainAxisSpacing: 16,
//                         childAspectRatio: 2,
//                       ),
//                       itemCount: _items.length,
//                       itemBuilder: (context, index) {
//                         final item = _items[index];
//                         return Card(
//                           elevation: 4,
//                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                           child: Padding(
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Expanded(
//                                       child: Text(
//                                         item['desc'],
//                                         style: GoogleFonts.poppins(
//                                           fontSize: 14,
//                                           fontWeight: FontWeight.w600,
//                                           color: Colors.black87,
//                                         ),
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ),
//                                     IconButton(
//                                       icon: const Icon(Icons.delete, color: Colors.red),
//                                       onPressed: () {
//                                         setState(() => _items.removeAt(index));
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                                 Text(
//                                   'Amount: ₹${item['amount'].toStringAsFixed(2)} | Qty: ${item['qty']}',
//                                   style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                     const SizedBox(height: 16),
//                     _buildFormField(controller: _bankDetailsController, label: 'Bank Details', isMultiLine: true),
//                     _buildFormField(
//                       controller: _signatoryController,
//                       label: 'Authorized Signatory',
//                       validator: (value) => value!.trim().isEmpty ? 'Required' : null,
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Total: ₹${_totalAmount.toStringAsFixed(2)}',
//                           style: GoogleFonts.poppins(
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.black87,
//                           ),
//                         ),
//                         Row(
//                           children: [
//                             TextButton(
//                               onPressed: _clearForm,
//                               child: Text('Clear', style: GoogleFonts.poppins(color: Colors.grey[600])),
//                             ),
//                             const SizedBox(width: 8),
//                             ElevatedButton(
//                               onPressed: _saveInvoice,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFF2C3E50),
//                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                               ),
//                               child: Text(
//                                 'Save & Share Invoice',
//                                 style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   String _convertToWords(int amount) {
//     // Placeholder for number-to-words conversion; consider using a package like `number_to_words`
//     return '$amount Rupees Only';
//   }
// }































// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'dart:typed_data';
// import 'db_helper.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';
// // import 'package:pdf/widgets.dart' as pw;
// // import 'package:google_fonts/google_fonts.dart' as gf;


// class InvoiceManagementScreen extends StatefulWidget {
//   @override
//   _InvoiceManagementScreenState createState() => _InvoiceManagementScreenState();
// }

// class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _date = DateTime.now();
//   String _invoiceNo = '';
//   final TextEditingController _deliveryNoteController = TextEditingController();
//   final TextEditingController _paymentTermsController = TextEditingController();
//   final TextEditingController _orderNoController = TextEditingController();
//   final TextEditingController _orderDateController = TextEditingController();
//   final TextEditingController _dispatchDocController = TextEditingController();
//   String _dispatchMode = 'Courier';
//   final TextEditingController _deliveryAddressController = TextEditingController();

//   int? _selectedCustomerId;
//   Map<String, dynamic>? _selectedCustomer;
//   List<Map<String, dynamic>> _customers = [];

//   List<Map<String, dynamic>> _items = [];

//   final TextEditingController _bankDetailsController = TextEditingController();
//   final TextEditingController _signatoryController = TextEditingController();

//   double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item['amount']);

//   @override
//   void initState() {
//     super.initState();
//     _generateInvoiceNumber();
//     _loadCustomers();
//   }

//   Future<void> _generateInvoiceNumber() async {
//     final db = await DBHelper().database;
//     final result = await db.rawQuery('SELECT COUNT(*)+1 as next FROM invoices');
//     _invoiceNo = 'INV-${result.first['next']}';
//     setState(() {});
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
//         final TextEditingController hsn = TextEditingController();
//         final TextEditingController qty = TextEditingController();
//         final TextEditingController rate = TextEditingController();
//         final TextEditingController unit = TextEditingController();
//         final TextEditingController discount = TextEditingController();
//         final TextEditingController tax = TextEditingController();

//         return AlertDialog(
//           title: Text('Add Line Item'),
//           content: SingleChildScrollView(
//             child: Column(
//               children: [
//                 TextField(controller: desc, decoration: InputDecoration(labelText: 'Description')),
//                 TextField(controller: hsn, decoration: InputDecoration(labelText: 'HSN/SAC No.')),
//                 TextField(controller: qty, decoration: InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
//                 TextField(controller: rate, decoration: InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
//                 TextField(controller: unit, decoration: InputDecoration(labelText: 'Unit')),
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
//                   'hsn': hsn.text,
//                   'qty': q,
//                   'rate': r,
//                   'unit': unit.text,
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

 

//   Future<void> _saveInvoice() async {
//   if (!_formKey.currentState!.validate() || _selectedCustomer == null || _items.isEmpty) return;

//   final db = await DBHelper().database;

//   final invoiceId = await db.insert('invoices', {
//     'date': DateFormat('yyyy-MM-dd').format(_date),
//     'invoice_no': _invoiceNo,
//     'delivery_note': _deliveryNoteController.text,
//     'payment_terms': _paymentTermsController.text,
//     'order_no': _orderNoController.text,
//     'order_date': _orderDateController.text,
//     'dispatch_doc_no': _dispatchDocController.text,
//     'dispatch_mode': _dispatchMode,
//     'delivery_address': _deliveryAddressController.text,
//     'buyer_id': _selectedCustomerId,
//     'gst_no': _selectedCustomer!['gst_number'],
//     'state': _selectedCustomer!['state'],
//     'state_code': _selectedCustomer!['state_code'],
//     'total_amount': _totalAmount,
//     'amount_words': _convertToWords(_totalAmount.toInt()),
//     'bank_details': _bankDetailsController.text,
//     'signatory': _signatoryController.text,
//   });

//   for (final item in _items) {
//     await db.insert('invoice_items', {
//       'invoice_id': invoiceId,
//       'description': item['desc'],
//       'hsn': item['hsn'],
//       'quantity': item['qty'],
//       'rate': item['rate'],
//       'unit': item['unit'],
//       'discount': item['discount'],
//       'tax': item['tax'],
//       'amount': item['amount'],
//     });
//   }

//   final pdf = await _generatePDF(invoiceId);
//   final Uint8List bytes = await pdf.save();

//   final directory = await getTemporaryDirectory();
//   final filePath = '${directory.path}/$_invoiceNo.pdf';
//   final file = File(filePath);
//   await file.writeAsBytes(bytes);

//   // ✅ Show path to user after saving
//   if (!mounted) return;

//   // Using SnackBar
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(
//       content: Text('PDF saved to: $filePath'),
//       duration: Duration(seconds: 5),
//       action: SnackBarAction(
//         label: 'Share',
//         onPressed: () {
//           Share.shareXFiles([
//             XFile(filePath, name: "$_invoiceNo.pdf")
//           ], text: "Here's your invoice $_invoiceNo");
//         },
//       ),
//     ),
//   );
//   ScaffoldMessenger.of(context).showSnackBar(
//   SnackBar(content: Text('PDF saved at:\n$filePath')),
// );

// }




//   pw.Document _generatePDF(int invoiceId) {
//   final pdf = pw.Document();

//   pdf.addPage(
//     pw.Page(
//       build: (pw.Context context) => pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.start,
//         children: [
//           pw.Text('Invoice $_invoiceNo', style: pw.TextStyle(fontSize: 24)),
//           pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(_date)}'),
//           pw.SizedBox(height: 12),
//           pw.Text('Customer: ${_selectedCustomer!['name']}'),
//           pw.Text('GST: ${_selectedCustomer!['gst_number']}'),
//           pw.Text('Address: ${_selectedCustomer!['billing_address']}'),
//           pw.SizedBox(height: 12),
//           pw.Table.fromTextArray(
//             headers: ['Desc', 'HSN', 'Qty', 'Rate', 'Disc%', 'Tax%', 'Amount'],
//             data: _items.map((item) => [
//               item['desc'],
//               item['hsn'],
//               item['qty'],
//               item['rate'],
//               item['discount'],
//               item['tax'],
//               item['amount'].toStringAsFixed(2),
//             ]).toList(),
//           ),
//           pw.SizedBox(height: 12),
//           pw.Text('Total: \$${_totalAmount.toStringAsFixed(2)}'),
//           pw.Text('In Words: ${_convertToWords(_totalAmount.toInt())}'),
//           pw.SizedBox(height: 12),
//           pw.Text('Bank: ${_bankDetailsController.text}'),
//           pw.Text('Authorized: ${_signatoryController.text}'),
//         ],
//       ),
//     ),
//   );

//   return pdf;
// }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Invoice Management')),
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
//               TextFormField(controller: _deliveryNoteController, decoration: InputDecoration(labelText: 'Delivery Note')),
//               TextFormField(controller: _paymentTermsController, decoration: InputDecoration(labelText: 'Payment Terms')),
//               TextFormField(controller: _orderNoController, decoration: InputDecoration(labelText: 'Buyer\'s Order No.')),
//               TextFormField(controller: _orderDateController, decoration: InputDecoration(labelText: 'Order Date')),
//               TextFormField(controller: _dispatchDocController, decoration: InputDecoration(labelText: 'Dispatched Doc No.')),
//               DropdownButtonFormField<String>(
//                 value: _dispatchMode,
//                 items: ['Courier', 'By Hand', 'Porter', 'Hand Delivery', 'Other']
//                     .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//                     .toList(),
//                 onChanged: (v) => setState(() => _dispatchMode = v!),
//                 decoration: InputDecoration(labelText: 'Dispatch Mode'),
//               ),
//               TextFormField(controller: _deliveryAddressController, decoration: InputDecoration(labelText: 'Delivery Address')),
//               Divider(),
//               ElevatedButton.icon(
//                 onPressed: _addItem,
//                 icon: Icon(Icons.add),
//                 label: Text('Add Line Item'),
//               ),
//               ..._items.map((item) => ListTile(
//                     title: Text(item['desc']),
//                     subtitle: Text('Amount: ₹${item['amount'].toStringAsFixed(2)}'),
//                   )),
//               Divider(),
//               TextFormField(controller: _bankDetailsController, decoration: InputDecoration(labelText: 'Bank Details')),
//               TextFormField(controller: _signatoryController, decoration: InputDecoration(labelText: 'Authorized Signatory')),
//               SizedBox(height: 12),
//               ElevatedButton(
//                 onPressed: _saveInvoice,
//                 child: Text('Save & Share Invoice'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
  
//   // _convertToWords(int int) {}
//   String _convertToWords(int amount) {
//   return "$amount Dollars Only"; // Or "Rupees" if you prefer even with "$"
// }

// }
