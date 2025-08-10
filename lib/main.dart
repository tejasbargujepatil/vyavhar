import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_io/io.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_settings.dart';

// Screens
import 'registration.dart';
import 'login.dart';
import 'Dashboard.dart';
import 'productManagement.dart';
import 'customerManagement.dart';
import 'invoice_management.dart';
import 'purchase_management.dart';
import 'offerManagement.dart';
import 'expenseManagement.dart';
import 'employeeManagement.dart';
import 'payment_tracking.dart';
import 'inventryManagement.dart';

// Providers
import 'purchase_notifier.dart';
import 'sales_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database for desktop
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print("Desktop environment detected. Skipping Firebase.");
  } else {
    await Firebase.initializeApp();
    print("Firebase initialized for mobile.");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PurchaseNotifier()),
        ChangeNotifierProvider(create: (_) => SalesNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIS Solutions ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2C3E50),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50),
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C3E50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2C3E50),
            side: const BorderSide(color: Color(0xFF2C3E50)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        // cardTheme: CardTheme(
        //   elevation: 4,
        //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // For desktop platforms, go directly to app
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return const AppDrawerWrapper();
    }

    // For mobile platforms, check Firebase auth
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        
        if (snapshot.hasData) {
          return const AppDrawerWrapper();
        } else {
          return const AuthSelectionScreen();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.business_center,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CIS Solutions',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ERP System',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthSelectionScreen extends StatelessWidget {
  const AuthSelectionScreen({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWideScreen ? 32 : 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFFAFBFC)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.business_center,
                          size: 48,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Welcome Text
                      Text(
                        'Welcome to',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CIS Solutions',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ERP Management System',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Streamline your business operations with our comprehensive ERP solution',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _navigateTo(context, const RegistrationScreen()),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: const Color(0xFF2C3E50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Create New Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _navigateTo(context, const LoginScreen()),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            side: const BorderSide(color: Color(0xFF2C3E50), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.login, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Sign In to Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Features Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Key Features',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Invoice & Purchase Management\n• Customer & Inventory Tracking\n• Expense & Employee Management\n• Real-time Analytics & Reports',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppDrawerWrapper extends StatelessWidget {
  const AppDrawerWrapper({super.key});

  void _logout(BuildContext context) async {
    // Only logout from Firebase on mobile platforms
    if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      await FirebaseAuth.instance.signOut();
    }
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'CIS Solutions ERP',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(Icons.business, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CIS Solutions',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'ERP System',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _drawerTile(context, 'Dashboard', Icons.dashboard, const Dashboard(), Colors.blue),
                  const Divider(height: 1),
                  _drawerTile(context, 'Product Management', Icons.inventory_2, const ProductManagementScreen(), Colors.green),
                  _drawerTile(context, 'Customer Management', Icons.people, const CustomerManagementScreen(), Colors.orange),
                  _drawerTile(context, 'Invoice Management', Icons.receipt, const InvoiceManagementScreen(), Colors.purple),
                  const Divider(height: 1),
                  _drawerTile(context, 'Purchase Management', Icons.shopping_cart, const PurchaseManagementScreen(), Colors.indigo),
                  _drawerTile(context, 'Offer / Quotation', Icons.local_offer, const OfferQuotationScreen(), Colors.teal),
                  const Divider(height: 1),
                  _drawerTile(context, 'Expense Management', Icons.money_off, const ExpenseManagementScreen(), Colors.red),
                  _drawerTile(context, 'Employee Management', Icons.person, const EmployeeManagementScreen(), Colors.brown),
                  _drawerTile(context, 'Payment Tracking', Icons.payment, const PaymentTrackingScreen(), Colors.cyan),
                  _drawerTile(context, 'Inventory Management', Icons.warehouse, const InventoryManagementScreen(), Colors.amber),
                  const Divider(height: 1),
                  _drawerTile(context, 'Settings / Profile', Icons.settings, const SettingsProfileScreen(), Colors.grey),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _logout(context),
              ),
            ),
          ],
        ),
      ),
      body: const Dashboard(),
    );
  }

  ListTile _drawerTile(BuildContext context, String title, IconData icon, Widget screen, Color iconColor) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}










// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:universal_io/io.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'profile_settings.dart';

// // Screens
// import 'registration.dart';
// import 'login.dart';
// // import 'trial.dart';
// import 'Dashboard.dart';
// import 'productManagement.dart';
// import 'customerManagement.dart';
// import 'invoice_management.dart';
// import 'purchase_management.dart';
// import 'offerManagement.dart';
// import 'expenseManagement.dart';
// import 'employeeManagement.dart';
// import 'payment_tracking.dart';
// import 'inventryManagement.dart';

// // Providers
// import 'purchase_notifier.dart';
// import 'sales_notifier.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // Initialize database for desktop
//   if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
//     sqfliteFfiInit();
//     databaseFactory = databaseFactoryFfi;
//     print("Desktop environment detected. Skipping Firebase.");
//   } else {
//     await Firebase.initializeApp();
//     print("Firebase initialized for mobile.");
//   }

//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => PurchaseNotifier()),
//         ChangeNotifierProvider(create: (_) => SalesNotifier()),
//       ],
//       child: const MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Business App',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primaryColor: const Color(0xFF2C3E50),
//         scaffoldBackgroundColor: const Color(0xFFF5F7FA),
//         elevatedButtonTheme: ElevatedButtonThemeData(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: const Color(0xFF2C3E50),
//             foregroundColor: Colors.white,
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
//           ),
//         ),
//         textTheme: GoogleFonts.poppinsTextTheme(),
//       ),
//       home: const TrialWrapper(),
//     );
//   }
// }

// class TrialWrapper extends StatefulWidget {
//   const TrialWrapper({super.key});

//   @override
//   State<TrialWrapper> createState() => _TrialWrapperState();
// }

// class _TrialWrapperState extends State<TrialWrapper> {
//   bool _accessGranted = false;
//   bool _isLoggedIn = false;

//   @override
//   void initState() {
//     super.initState();
//     _checkTrialAndAuth();
//   }

//   Future<void> _checkTrialAndAuth() async {
//     final prefs = await SharedPreferences.getInstance();
//     final paid = prefs.getBool('paid_user') ?? false;

//     bool loggedIn = false;

//     if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
//       final currentUser = FirebaseAuth.instance.currentUser;
//       loggedIn = currentUser != null;
//     }

//     setState(() {
//       _accessGranted = paid || Platform.isLinux || Platform.isWindows || Platform.isMacOS;
//       _isLoggedIn = loggedIn || (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
//     });
//   }

//   void _grantAccess() {
//     bool loggedIn = false;

//     if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
//       final user = FirebaseAuth.instance.currentUser;
//       loggedIn = user != null;
//     }

//     setState(() {
//       _accessGranted = true;
//       _isLoggedIn = loggedIn || (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return _accessGranted
//         ? (_isLoggedIn ? const AppDrawerWrapper() : const AuthSelectionScreen())
//         : TrialScreen(onAccessGranted: _grantAccess);
//   }
// }

// class AuthSelectionScreen extends StatelessWidget {
//   const AuthSelectionScreen({super.key});

//   void _navigateTo(BuildContext context, Widget screen) {
//     Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isWideScreen = screenWidth > 600;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         title: Text(
//           'Welcome',
//           style: GoogleFonts.poppins(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF2C3E50),
//         elevation: 0,
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: EdgeInsets.all(isWideScreen ? 32 : 16),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 500),
//             child: Card(
//               elevation: 4,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.business_center, size: 48, color: Color(0xFF2C3E50)),
//                     const SizedBox(height: 16),
//                     Text(
//                       'Business App',
//                       style: GoogleFonts.poppins(
//                         fontSize: 24,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Manage your business with ease',
//                       style: GoogleFonts.poppins(
//                         fontSize: 16,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                     ElevatedButton(
//                       onPressed: () => _navigateTo(context, const RegistrationScreen()),
//                       style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
//                       child: const Text('Register'),
//                     ),
//                     const SizedBox(height: 16),
//                     OutlinedButton(
//                       onPressed: () => _navigateTo(context, const LoginScreen()),
//                       style: OutlinedButton.styleFrom(
//                         minimumSize: const Size(double.infinity, 50),
//                         side: const BorderSide(color: Color(0xFF2C3E50)),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
//                       ),
//                       child: const Text('Login'),
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
// }

// class AppDrawerWrapper extends StatelessWidget {
//   const AppDrawerWrapper({super.key});

//   void _logout(BuildContext context) async {
//     await FirebaseAuth.instance.signOut();
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => const AuthSelectionScreen()),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         title: Text(
//           'Dashboard',
//           style: GoogleFonts.poppins(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF2C3E50),
//         elevation: 0,
//       ),
//       drawer: Drawer(
//         child: Column(
//           children: [
//             DrawerHeader(
//               decoration: const BoxDecoration(color: Color(0xFF2C3E50)),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.business, size: 48, color: Colors.white),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Business App',
//                     style: GoogleFonts.poppins(
//                       fontSize: 24,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: ListView(
//                 children: [
//                   _drawerTile(context, 'Dashboard', Icons.dashboard, const Dashboard()),
//                   _drawerTile(context, 'Product Management', Icons.inventory_2, const ProductManagementScreen()),
//                   _drawerTile(context, 'Customer Management', Icons.people, const CustomerManagementScreen()),
//                   _drawerTile(context, 'Invoice Management', Icons.receipt, const InvoiceManagementScreen()),
//                   _drawerTile(context, 'Purchase Management', Icons.shopping_cart, const PurchaseManagementScreen()),
//                   _drawerTile(context, 'Offer / Quotation', Icons.local_offer, const OfferQuotationScreen()),
//                   _drawerTile(context, 'Expense Management', Icons.money_off, const ExpenseManagementScreen()),
//                   _drawerTile(context, 'Employee Management', Icons.person, const EmployeeManagementScreen()),
//                   _drawerTile(context, 'Payment Tracking', Icons.payment, const PaymentTrackingScreen()),
//                   _drawerTile(context, 'Inventory Management', Icons.warehouse, const InventoryManagementScreen()),
//                   _drawerTile(context, 'Settings / Profile', Icons.settings, const SettingsProfileScreen()),

//                 ],
//               ),
//             ),
//             ListTile(
//               leading: const Icon(Icons.logout, color: Colors.red),
//               title: Text(
//                 'Logout',
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   color: Colors.red,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               onTap: () => _logout(context),
//             ),
//           ],
//         ),
//       ),
//       body: const Dashboard(),
//     );
//   }

//   ListTile _drawerTile(BuildContext context, String title, IconData icon, Widget screen) {
//     return ListTile(
//       leading: Icon(icon, color: const Color(0xFF2C3E50)),
//       title: Text(
//         title,
//         style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
//       ),
//       onTap: () {
//         Navigator.pop(context); // Close drawer
//         Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
//       },
//     );
//   }
// }




















// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:universal_io/io.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:vyapar/sales_notifier.dart';

// // Screens
// import 'registration.dart';
// import 'login.dart';
// import 'trial.dart';
// import 'Dashboard.dart';
// import 'productManagement.dart';
// import 'customerManagement.dart';
// import 'invoice_management.dart';
// import 'purchase_management.dart';
// import 'offerManagement.dart';
// import 'expenseManagement.dart';
// import 'employeeManagement.dart';
// import 'payment_tracking.dart';
// import 'inventryManagement.dart';

// // Providers
// import 'purchase_notifier.dart';

// // Future<void> main() async {
// //   if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
// //     sqfliteFfiInit();
// //     databaseFactory = databaseFactoryFfi;
// //   }

// //   WidgetsFlutterBinding.ensureInitialized();
// //   await Firebase.initializeApp();

// //   runApp(
// //     ChangeNotifierProvider(
// //       create: (_) => PurchaseNotifier(),
// //       child: const MyApp(),
// //     ),
// //   );
// // }



// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
//     sqfliteFfiInit();
//     databaseFactory = databaseFactoryFfi;

//     print("Running on desktop. Skipping Firebase initialization.");
//   } else {
//     await Firebase.initializeApp();
//     print("Firebase initialized successfully.");
//   }

//   runApp(
//     ChangeNotifierProvider(
//       create: (_) => PurchaseNotifier(),
//       child: const MyApp(),
//     ),
//   );
// }


// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Business App',
//       theme: ThemeData(
//         primaryColor: const Color(0xFF2C3E50),
//         scaffoldBackgroundColor: const Color(0xFFF5F7FA),
//         elevatedButtonTheme: ElevatedButtonThemeData(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: const Color(0xFF2C3E50),
//             foregroundColor: Colors.white,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//             textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
//           ),
//         ),
//         textTheme: GoogleFonts.poppinsTextTheme(),
//       ),
//       home: const TrialWrapper(),
//     );
//   }


// // Multiprovider setup for PurchaseNotifier and SalesNotifier
//   // This allows both notifiers to be available throughout the app
//   @override

//  void main() {
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => PurchaseNotifier()),
//         ChangeNotifierProvider(create: (_) => SalesNotifier()),
//       ],
//       child: const MyApp(),
//     ),
//   );
// }


// }

// class TrialWrapper extends StatefulWidget {
//   const TrialWrapper({super.key});

//   @override
//   State<TrialWrapper> createState() => _TrialWrapperState();
// }

// class _TrialWrapperState extends State<TrialWrapper> {
//   bool _accessGranted = false;
//   bool _isLoggedIn = false;

//   @override
//   void initState() {
//     super.initState();
//     _checkTrialAndAuth();
//   }

//   // Future<void> _checkTrialAndAuth() async {
//   //   final prefs = await SharedPreferences.getInstance();
//   //   final paid = prefs.getBool('paid_user') ?? false;
//   //   final currentUser = FirebaseAuth.instance.currentUser;

//   //   if (paid) {
//   //     setState(() {
//   //       _accessGranted = true;
//   //       _isLoggedIn = currentUser != null;
//   //     });
//   //   }
//   // }


// //   Future<void> _checkTrialAndAuth() async {
// //   final prefs = await SharedPreferences.getInstance();
// //   final paid = prefs.getBool('paid_user') ?? false;

// //   if (Platform.isAndroid || Platform.isIOS) {
// //     // Firebase is initialized only on mobile
// //     final currentUser = FirebaseAuth.instance.currentUser;

// //     setState(() {
// //       _accessGranted = paid;
// //       _isLoggedIn = currentUser != null;
// //     });
// //   } else {
// //     // Simulate logic for desktop
// //     setState(() {
// //       _accessGranted = paid;
// //       _isLoggedIn = true; // Simulate a "logged in" user on Linux
// //     });
// //   }
// // }
//       Future<void> _checkTrialAndAuth() async {
//   final prefs = await SharedPreferences.getInstance();
//   final paid = prefs.getBool('paid_user') ?? false;

//   bool loggedIn = false;

//   if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
//     final currentUser = FirebaseAuth.instance.currentUser;
//     loggedIn = currentUser != null;
//   }

//   if (paid || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
//     setState(() {
//       _accessGranted = true;
//       _isLoggedIn = loggedIn;
//     });
//   }
// }


//   @override
//   Widget build(BuildContext context) {
//     return _accessGranted
//         ? (_isLoggedIn ? const AppDrawerWrapper() : const AuthSelectionScreen())
//         : TrialScreen(onAccessGranted: _grantAccess);
//   }

//   // void _grantAccess() {
//   //   final user = FirebaseAuth.instance.currentUser;
//   //   setState(() {
//   //     _accessGranted = true;
//   //     _isLoggedIn = user != null;
//   //   });
//   // }
//   // void _grantAccess() {
//   // if (Platform.isAndroid || Platform.isIOS) {
//   //   final user = FirebaseAuth.instance.currentUser;
//   //   setState(() {
//   //     _accessGranted = true;
//   //     _isLoggedIn = user != null;
//   //   });
//   // } else {
//   //   // Simulate login success for desktop debugging
//   //   setState(() {
//   //     _accessGranted = true;
//   //     _isLoggedIn = true;
//   //   });
//   // }
// // }
//      void _grantAccess() {
//   bool loggedIn = false;

//   if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
//     final user = FirebaseAuth.instance.currentUser;
//     loggedIn = user != null;
//   }

//   setState(() {
//     _accessGranted = true;
//     _isLoggedIn = loggedIn;
//   });
// }


// }

// class AuthSelectionScreen extends StatelessWidget {
//   const AuthSelectionScreen({super.key});

//   void _navigateTo(BuildContext context, Widget screen) {
//     Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isWideScreen = screenWidth > 600;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         title: Text(
//           'Welcome',
//           style: GoogleFonts.poppins(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF2C3E50),
//         elevation: 0,
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: EdgeInsets.all(isWideScreen ? 32 : 16),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 500),
//             child: Card(
//               elevation: 4,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.business_center, size: 48, color: Color(0xFF2C3E50)),
//                     const SizedBox(height: 16),
//                     Text(
//                       'Business App',
//                       style: GoogleFonts.poppins(
//                         fontSize: 24,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.black87,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Manage your business with ease',
//                       style: GoogleFonts.poppins(
//                         fontSize: 16,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                     ElevatedButton(
//                       onPressed: () => _navigateTo(context, const RegistrationScreen()),
//                       style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
//                       child: const Text('Register'),
//                     ),
//                     const SizedBox(height: 16),
//                     OutlinedButton(
//                       onPressed: () => _navigateTo(context, const LoginScreen()),
//                       style: OutlinedButton.styleFrom(
//                         minimumSize: const Size(double.infinity, 50),
//                         side: const BorderSide(color: Color(0xFF2C3E50)),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
//                       ),
//                       child: const Text('Login'),
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
// }

// class AppDrawerWrapper extends StatelessWidget {
//   const AppDrawerWrapper({super.key});

//   void _logout(BuildContext context) async {
//     await FirebaseAuth.instance.signOut();
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => const AuthSelectionScreen()),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         title: Text(
//           'Dashboard',
//           style: GoogleFonts.poppins(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF2C3E50),
//         elevation: 0,
//       ),
//       drawer: Drawer(
//         child: Column(
//           children: [
//             DrawerHeader(
//               decoration: const BoxDecoration(color: Color(0xFF2C3E50)),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Icon(Icons.business, size: 48, color: Colors.white),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Business App',
//                     style: GoogleFonts.poppins(
//                       fontSize: 24,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: ListView(
//                 padding: EdgeInsets.zero,
//                 children: [
//                   _drawerTile(context, 'Dashboard', Icons.dashboard, const Dashboard()),
//                   _drawerTile(context, 'Product Management', Icons.inventory_2, const ProductManagementScreen()),
//                   _drawerTile(context, 'Customer Management', Icons.people, const CustomerManagementScreen()),
//                   _drawerTile(context, 'Invoice Management', Icons.receipt, const InvoiceManagementScreen()),
//                   _drawerTile(context, 'Purchase Management', Icons.shopping_cart, const PurchaseManagementScreen()),
//                   _drawerTile(context, 'Offer / Quotation', Icons.local_offer, const OfferQuotationScreen()),
//                   _drawerTile(context, 'Expense Management', Icons.money_off, const ExpenseManagementScreen()),
//                   _drawerTile(context, 'Employee Management', Icons.person, const EmployeeManagementScreen()),
//                   _drawerTile(context, 'Payment Tracking', Icons.payment, const PaymentTrackingScreen()),
//                   _drawerTile(context, 'Inventory Management', Icons.warehouse, const InventoryManagementScreen()),
//                 ],
//               ),
//             ),
//             ListTile(
//               leading: const Icon(Icons.logout, color: Colors.red),
//               title: Text(
//                 'Logout',
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   color: Colors.red,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               onTap: () => _logout(context),
//             ),
//           ],
//         ),
//       ),
//       body: const Dashboard(),
//     );
//   }

//   ListTile _drawerTile(BuildContext context, String title, IconData icon, Widget screen) {
//     return ListTile(
//       leading: Icon(icon, color: const Color(0xFF2C3E50)),
//       title: Text(
//         title,
//         style: GoogleFonts.poppins(
//           fontSize: 16,
//           color: Colors.black87,
//         ),
//       ),
//       onTap: () {
//         Navigator.pop(context); // Close drawer
//         Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
//       },
//     );
//   }
// }
// The following code is commented out as it was part of the original context but not needed in the final implementation.
// Uncomment if you need to use these imports or functionalities in the future.
