import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/session_provider.dart';
import 'screens/login_screen.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/staff/attendance_screen.dart';
import 'screens/splash_screen.dart';
import 'services/mssql_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await initializeBackgroundService();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SessionProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthWrapper(),
      },
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
    _checkSession();
  }

  void _checkSession() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    await session.checkSession();

    if (session.isLoggedIn) {
      // Re-establish DB Connection
      final mssql = MSSQLService();
      await mssql.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        if (!session.isLoggedIn) {
          return const LoginScreen();
        } else {
          if (session.currentUser?.role == UserRole.owner) {
            return const OwnerDashboard();
          } else {
            return const AttendanceScreen();
          }
        }
      },
    );
  }
}
