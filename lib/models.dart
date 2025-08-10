// models.dart

class Product {
  int? id;
  String name;
  String description;
  String hsnCode;
  double price;
  double gst;
  int quantity;
  int minStock;

  Product({
    this.id,
    required this.name,
    required this.description,
    required this.hsnCode,
    required this.price,
    required this.gst,
    required this.quantity,
    required this.minStock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'hsn': hsnCode,                  // MAPPED to DB field
      'price': price,
      'gst': gst,
      'stock': quantity,               // MAPPED to DB field
      'min_alert_stock': minStock      // MAPPED to DB field
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      hsnCode: map['hsn'],             // MAPPED to DB field
      price: map['price'],
      gst: map['gst'],
      quantity: map['stock'],          // MAPPED to DB field
      minStock: map['min_alert_stock'] // MAPPED to DB field
    );
  }
}


class Customer {
  int? id;
  String name;
  String gstNumber;
  String billingAddress;
  String shippingAddress;
  String emails; // comma-separated
  String contactPerson;
  String contacts; // comma-separated
  String state;
  String stateCode;

  Customer({
    this.id,
    required this.name,
    required this.gstNumber,
    required this.billingAddress,
    required this.shippingAddress,
    required this.emails,
    required this.contactPerson,
    required this.contacts,
    required this.state,
    required this.stateCode,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'gst_number': gstNumber,
        'billing_address': billingAddress,
        'shipping_address': shippingAddress,
        'emails': emails,
        'contact_person': contactPerson,
        'contacts': contacts,
        'state': state,
        'state_code': stateCode,
      };

  static Customer fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'],
        name: map['name'],
        gstNumber: map['gst_number'],
        billingAddress: map['billing_address'],
        shippingAddress: map['shipping_address'],
        emails: map['emails'],
        contactPerson: map['contact_person'],
        contacts: map['contacts'],
        state: map['state'],
        stateCode: map['state_code'],
      );
}

class Expense {
  int? id;
  String employeeName;
  String expenseType;
  String description;
  double amount;
  String approvedBy;
  String date;
  String paymentMode;

  Expense({
    this.id,
    required this.employeeName,
    required this.expenseType,
    required this.description,
    required this.amount,
    required this.approvedBy,
    required this.date,
    required this.paymentMode,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'employee_name': employeeName,
        'expense_type': expenseType,
        'description': description,
        'amount': amount,
        'approved_by': approvedBy,
        'date': date,
        'payment_mode': paymentMode,
      };

  static Expense fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'],
        employeeName: map['employee_name'],
        expenseType: map['expense_type'],
        description: map['description'],
        amount: map['amount'],
        approvedBy: map['approved_by'],
        date: map['date'],
        paymentMode: map['payment_mode'],
      );
}

class Employee {
  int? id;
  String name;
  String joiningDate;
  int age;
  String role;
  double salary;
  String contact;

  Employee({
    this.id,
    required this.name,
    required this.joiningDate,
    required this.age,
    required this.role,
    required this.salary,
    required this.contact,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'joining_date': joiningDate,
        'age': age,
        'role': role,
        'salary': salary,
        'contact': contact,
      };

  static Employee fromMap(Map<String, dynamic> map) => Employee(
        id: map['id'],
        name: map['name'],
        joiningDate: map['joining_date'],
        age: map['age'],
        role: map['role'],
        salary: map['salary'],
        contact: map['contact'],
      );
}

// Add other models similarly like Invoice, Purchase, Inventory etc.