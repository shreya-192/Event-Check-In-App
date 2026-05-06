import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/checkin_page.dart';
import 'pages/event_setup_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/my_events_page.dart';
import 'pages/signup_page.dart';
import 'pages/user_dashboard_page.dart';
import 'services/local_storage_service.dart';

const supabaseUrl = 'https://axhfabrrfpworvqtikct.supabase.co';
const supabaseAnonKey = 'sb_publishable_qGZGmfoe0pmbStEIquAT2A_Kaj4vtop';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalStorageService.initialize();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const SmartCheckinApp());
}

class SmartCheckinApp extends StatelessWidget {
  const SmartCheckinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Event Check-in',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.lightBlue.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const LoginPage(),
        '/signup': (_) => const SignupPage(),
        '/home': (_) => const HomePage(),
        '/admin-dashboard': (_) => const AdminDashboardPage(),
        '/user-dashboard': (_) => const UserDashboardPage(),
        '/my-events': (_) => const MyEventsPage(),
        '/checkin': (_) => const CheckinPage(),
        '/event-setup': (_) => const EventSetupPage(),
      },
    );
  }
}
