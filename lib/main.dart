import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'presentation/home/home_shell.dart';

const _primaryHex = 0xFF543824; // بني غامق
const _accentHex  = 0xFFC49A6C; // بيج فاتح

Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  runApp(const ProviderScope(child: MyApp()));
}

ColorScheme _buildScheme(Brightness brightness) {
  final primary = const Color(_primaryHex);
  final secondary = const Color(_accentHex);
  final base = ColorScheme.fromSeed(seedColor: primary, brightness: brightness);
  return base.copyWith(primary: primary, secondary: secondary);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final light = _buildScheme(Brightness.light);
    final dark = _buildScheme(Brightness.dark);
    return MaterialApp(
      title: 'Elfouad Admin',
      theme: ThemeData(
        colorScheme: light,
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      darkTheme: ThemeData(
        colorScheme: dark,
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const HomeShell(),
    );
  }
}