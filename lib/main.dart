import 'dart:async' show unawaited;
import 'package:elfouad_admin/core/firestore_tuning.dart'
    show configureFirestore;
import 'package:elfouad_admin/presentation/Expenses/state/expenses_providers.dart';
import 'package:elfouad_admin/presentation/grind/state/grind_providers.dart';
import 'package:elfouad_admin/presentation/home/app_shell.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:elfouad_admin/presentation/inventory/providers.dart';
import 'package:elfouad_admin/presentation/manage/state/drinks_provider.dart';
import 'package:elfouad_admin/presentation/manage/state/extras_provider.dart';
import 'package:elfouad_admin/presentation/manage/state/manage_tab_cubit.dart';
import 'package:elfouad_admin/presentation/stats/state/stats_data_provider.dart';
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
  await _initFirebase();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavCubit()),
        BlocProvider(create: (_) => ExpensesCubit()),
        BlocProvider(create: (_) => InventoryCubit()),
        BlocProvider(create: (_) => DrinksCubit()),
        BlocProvider(create: (_) => ExtrasCubit()),
        BlocProvider(create: (_) => ManageTabCubit()),
        BlocProvider(create: (_) => GrindCubit()),
        BlocProvider(create: (_) => StatsCubit()),
      ],
      child: const MyApp(),
    ),
  );
  unawaited(_scheduleAutoArchive());
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
      home: const AppShell(),
    );
  }
}
