import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/provision_screen.dart';
import 'screens/control_screen.dart';
import 'screens/home_screen.dart';
import 'services/background_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeBackgroundScheduler();
  runApp(const Esp01App());
}

class Esp01App extends StatelessWidget {
  const Esp01App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP-01 Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060A0F),
        primaryColor: const Color(0xFF00F5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F5FF),
          secondary: Color(0xFF7C3AED),
          surface: Color(0xFF0D1117),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/scan': (context) => const ScanScreen(), // '/' → '/scan' oldu
        '/home': (context) => const HomeScreen(),
        '/provision': (context) => const ProvisionScreen(),
        '/control': (context) => const ControlScreen(),
      },
    );
  }
}

// Kullanıcı giriş yapmışsa Home, yapmamışsa Login'e yönlendir
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF060A0F),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00F5FF)),
            ),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
