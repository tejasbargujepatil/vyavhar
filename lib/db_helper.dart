import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  Future<Database> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'business_app.db');

    return await openDatabase(
      path,
      version: 2, // ✅ UPGRADED VERSION
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        amount REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        category TEXT,
        amount REAL,
        approved_by TEXT,
        mode TEXT,
        employee_name TEXT,
        expense_type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE employees(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        joining_date TEXT,
        age INTEGER,
        role TEXT,
        salary REAL,
        contact TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE leaves(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER,
        leave_date TEXT,
        reason TEXT,
        FOREIGN KEY(employee_id) REFERENCES employees(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        hsn TEXT,
        price REAL,
        gst REAL,
        stock INTEGER,
        min_alert_stock INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        gst_number TEXT,
        billing_address TEXT,
        shipping_address TEXT,
        emails TEXT,
        contact_person TEXT,
        contact_numbers TEXT,
        state TEXT,
        state_code TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        invoice_no TEXT,
        delivery_note TEXT,
        payment_terms TEXT,
        order_no TEXT,
        order_date TEXT,
        dispatch_doc_no TEXT,
        dispatch_mode TEXT,
        delivery_address TEXT,
        buyer_id INTEGER,
        gst_no TEXT,
        state TEXT,
        state_code TEXT,
        total_amount REAL,
        amount_words TEXT,
        bank_details TEXT,
        signatory TEXT,
        status TEXT DEFAULT 'Invoiced', -- ✅ NEW COLUMN
        FOREIGN KEY(buyer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        description TEXT,
        hsn TEXT,
        quantity INTEGER,
        rate REAL,
        unit TEXT,
        discount REAL,
        tax REAL,
        amount REAL,
        FOREIGN KEY(invoice_id) REFERENCES invoices(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendor TEXT,
        date TEXT,
        invoice_no TEXT,
        payment_mode TEXT,
        total REAL,
        tax REAL,
        tax_amount REAL,
        amount REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER,
        product_name TEXT,
        hsn TEXT,
        quantity INTEGER,
        rate REAL,
        tax REAL,
        tax_amount REAL,
        amount REAL,
        FOREIGN KEY(purchase_id) REFERENCES purchases(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE offers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        validity TEXT,
        product_list TEXT,
        tax REAL,
        discount REAL,
        converted_to_invoice INTEGER,
        FOREIGN KEY(customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        amount REAL,
        order_no TEXT,
        utr_no TEXT,
        date TEXT,
        mode TEXT,
        FOREIGN KEY(customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT,
        quantity INTEGER,
        description TEXT,
        brand TEXT,
        purchase_date TEXT,
        buy_price REAL,
        sell_price REAL,
        hsn_code TEXT,
        min_alert_qty INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_ledger(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT,
        movement_type TEXT,
        quantity INTEGER,
        date TEXT,
        reference TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE trials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        start_date TEXT,
        end_date TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // ✅ Add status column to invoices table if not present
      final existingColumns = await db.rawQuery("PRAGMA table_info(invoices)");
      final hasStatus = existingColumns.any((col) => col['name'] == 'status');
      if (!hasStatus) {
        await db.execute("ALTER TABLE invoices ADD COLUMN status TEXT DEFAULT 'Invoiced'");
      }
    }
  }

  // Dashboard support methods
  Future<double> getTotalPurchases() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(total) as total FROM purchases');
    return result.first['total'] != null ? result.first['total'] as double : 0.0;
  }

  Future<int> getEmployeeCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM employees');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getStockValue() async {
    final db = await database;
    final stockData = await db.rawQuery('SELECT quantity, buy_price FROM inventory');
    double stockValue = 0;
    for (var row in stockData) {
      final qty = row['quantity'] as int;
      final price = row['buy_price'] is num ? (row['buy_price'] as num).toDouble() : 0.0;
      stockValue += qty * price;
    }
    return stockValue;
  }
}



































// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';

// class DBHelper {
//   static final DBHelper _instance = DBHelper._internal();
//   factory DBHelper() => _instance;
//   DBHelper._internal();

//   static Database? _db;

//   Future<Database> get database async {
//     if (_db != null) return _db!;
//     _db = await initDB();
//     return _db!;
//   }

//   Future<Database> initDB() async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, 'business_app.db');

//     return await openDatabase(
//       path,
//       version: 1,
//       onCreate: _onCreate,
//       onUpgrade: _onUpgrade,
//     );
//   }

//   Future<void> _onCreate(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE sales(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         date TEXT,
//         amount REAL
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE expenses(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         date TEXT,
//         category TEXT,
//         amount REAL,
//         approved_by TEXT,
//         mode TEXT,
//         employee_name TEXT,
//         expense_type TEXT
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE employees(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         name TEXT,
//         joining_date TEXT,
//         age INTEGER,
//         role TEXT,
//         salary REAL,
//         contact TEXT
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE leaves(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         employee_id INTEGER,
//         leave_date TEXT,
//         reason TEXT,
//         FOREIGN KEY(employee_id) REFERENCES employees(id)
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE products(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         name TEXT,
//         description TEXT,
//         hsn TEXT,
//         price REAL,
//         gst REAL,
//         stock INTEGER,
//         min_alert_stock INTEGER
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE customers(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         name TEXT,
//         gst_number TEXT,
//         billing_address TEXT,
//         shipping_address TEXT,
//         emails TEXT,
//         contact_person TEXT,
//         contact_numbers TEXT,
//         state TEXT,
//         state_code TEXT
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE invoices(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         date TEXT,
//         invoice_no TEXT,
//         delivery_note TEXT,
//         payment_terms TEXT,
//         order_no TEXT,
//         order_date TEXT,
//         dispatch_doc_no TEXT,
//         dispatch_mode TEXT,
//         delivery_address TEXT,
//         buyer_id INTEGER,
//         gst_no TEXT,
//         state TEXT,
//         state_code TEXT,
//         total_amount REAL,
//         amount_words TEXT,
//         bank_details TEXT,
//         signatory TEXT,
//         FOREIGN KEY(buyer_id) REFERENCES customers(id)
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE invoice_items(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         invoice_id INTEGER,
//         description TEXT,
//         hsn TEXT,
//         quantity INTEGER,
//         rate REAL,
//         unit TEXT,
//         discount REAL,
//         tax REAL,
//         amount REAL,
//         FOREIGN KEY(invoice_id) REFERENCES invoices(id)
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE purchases(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         vendor TEXT,
//         date TEXT,
//         invoice_no TEXT,
//         payment_mode TEXT,
//         total REAL,
//         tax REAL,
//         tax_amount REAL,
//         amount REAL
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE purchase_items(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         purchase_id INTEGER,
//         product_name TEXT,
//         hsn TEXT,
//         quantity INTEGER,
//         rate REAL,
//         tax REAL,
//         tax_amount REAL,
//         amount REAL,
//         FOREIGN KEY(purchase_id) REFERENCES purchases(id)
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE offers(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         customer_id INTEGER,
//         validity TEXT,
//         product_list TEXT,
//         tax REAL,
//         discount REAL,
//         converted_to_invoice INTEGER,
//         FOREIGN KEY(customer_id) REFERENCES customers(id)
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE payments(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         customer_id INTEGER,
//         amount REAL,
//         order_no TEXT,
//         utr_no TEXT,
//         date TEXT,
//         mode TEXT,
//         FOREIGN KEY(customer_id) REFERENCES customers(id)
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE inventory(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         product_name TEXT,
//         quantity INTEGER,
//         description TEXT,
//         brand TEXT,
//         purchase_date TEXT,
//         buy_price REAL,
//         sell_price REAL,
//         hsn_code TEXT,
//         min_alert_qty INTEGER
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE stock_ledger(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         product_name TEXT,
//         movement_type TEXT,
//         quantity INTEGER,
//         date TEXT,
//         reference TEXT
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE users(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         name TEXT,
//         email TEXT UNIQUE,
//         password TEXT
//       )
//     ''');

//     await db.execute('''
//       CREATE TABLE trials(
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         user_id INTEGER,
//         start_date TEXT,
//         end_date TEXT,
//         FOREIGN KEY(user_id) REFERENCES users(id)
//       )
//     ''');
//   }

//   Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
//     // No-op for now
//     await deleteDatabase(join(await getDatabasesPath(), 'business_app.db'));
//     await _onCreate(db, newVersion);
//   }


// // Exposing a method to display data on the dashboard
//   Future<double> getTotalPurchases() async {
//   final db = await database;
//   final result = await db.rawQuery('SELECT SUM(total) as total FROM purchases');
//   return result.first['total'] != null ? result.first['total'] as double : 0.0;
// }
//   Future<int> getEmployeeCount() async {
//     final db = await database;
//     final result = await db.rawQuery('SELECT COUNT(*) as count FROM employees');
//     return Sqflite.firstIntValue(result) ?? 0;
//   }

//   Future<double> getStockValue() async {
//     final db = await database;
//     final stockData = await db.rawQuery('SELECT quantity, buying_price FROM inventory');
//     double stockValue = 0;
//     for (var row in stockData) {
//       final qty = row['quantity'] as int;
//       final price = row['buying_price'] is num ? (row['buying_price'] as num).toDouble() : 0.0;
//       stockValue += qty * price;
//     }
//     return stockValue;
//   }
// }
