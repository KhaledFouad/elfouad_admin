import 'dart:async' show unawaited;
import 'package:elfouad_admin/core/firestore_tuning.dart'
    show configureFirestore;
import 'package:elfouad_admin/presentation/Expenses/bloc/expenses_cubit.dart';
import 'package:elfouad_admin/presentation/grind/state/grind_providers.dart';
import 'package:elfouad_admin/presentation/home/app_shell.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/drinks_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/extras_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/manage_tab_cubit.dart';
import 'package:elfouad_admin/presentation/recipes/bloc/recipes_cubit.dart';
import 'package:elfouad_admin/presentation/stats/bloc/stats_cubit.dart';
import 'package:elfouad_admin/services/archive/auto_archiver.dart.dart'
    show runAutoArchiveIfNeeded;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'services/firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:elfouad_admin/core/app_strings.dart';

const _primaryHex = 0xFF543824;
const _accentHex = 0xFFC49A6C;

Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureFirestore();
}

Future<void> _scheduleAutoArchive() async {
  if (!kReleaseMode) return;
  await Future<void>.delayed(const Duration(seconds: 8));
  unawaited(
    runAutoArchiveIfNeeded(
      adminUid: AppStrings.systemUserId,
      everyNDays: 5,
      daysThreshold: 40,
      batchSize: 200,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

ThemeData _lightTheme() {
  final primary = const Color(_primaryHex);
  final secondary = const Color(_accentHex);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(primary: primary, secondary: secondary, surface: Colors.white),
    scaffoldBackgroundColor: Colors.white,
    textTheme: GoogleFonts.cairoTextTheme(),

    // appBarTheme: const AppBarTheme(
    //   centerTitle: true,
    //   backgroundColor: Colors.white,
    //   foregroundColor: Colors.white,
    // ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: Colors.white,
      ),
    ),
  );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: secondary),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      color: WidgetStateProperty.all(secondary.withAlpha(38)),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      locale: const Locale(AppStrings.localeAr),
      supportedLocales: const [
        Locale(AppStrings.localeAr),
        Locale(AppStrings.localeEn),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      theme: _lightTheme(),
      debugShowCheckedModeBanner: false,
      home: const _BootstrapGate(),
    );
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  late final Future<void> _initFuture;
  Widget? _app;

  @override
  void initState() {
    super.initState();
    _initFuture = _initFirebase();
    _initFuture.then((_) => unawaited(_scheduleAutoArchive()));
  }

  Widget _buildApp() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavCubit()),
        BlocProvider(create: (_) => ExpensesCubit()),
        BlocProvider(create: (_) => RecipesCubit()),
        BlocProvider(create: (_) => InventoryCubit()),
        BlocProvider(create: (_) => DrinksCubit()),
        BlocProvider(create: (_) => ExtrasCubit()),
        BlocProvider(create: (_) => ManageTabCubit()),
        BlocProvider(create: (_) => GrindCubit()),
        BlocProvider(create: (_) => StatsCubit()),
      ],
      child: const AppShell(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppStrings.loadFailedSimple(snapshot.error ?? 'unknown'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _app ??= _buildApp();
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final logoSize = (shortest * 0.35).clamp(120.0, 200.0);

    return Scaffold(
      body: Center(
        child: RotationTransition(
          turns: _controller,
          child: Image.asset(
            'assets/logo2.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
