import 'dart:async' show unawaited;
import 'package:elfouad_admin/core/utils/firestore_tuning.dart';
import 'package:elfouad_admin/presentation/auth/lock_gate_page.dart';
import 'package:elfouad_admin/services/auth/auth_service.dart';
import 'package:elfouad_admin/services/archive/auto_archiver.dart.dart'
    show runAutoArchiveIfNeeded;
import 'package:elfouad_admin/core/widgets/app_background.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'services/firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    runAutoArchiveIfNeeded(adminUid: AppStrings.systemUserId, batchSize: 200),
  );
}

late final Future<void> _firebaseInit;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _firebaseInit = _initFirebase();
  runApp(MyApp(initFuture: _firebaseInit));
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
    scaffoldBackgroundColor: Colors.transparent,
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

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initFuture});

  final Future<void> initFuture;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  final _RouteTracker _routeTracker = _RouteTracker();
  static const Duration _minBackgroundLockDuration = Duration(seconds: 20);
  DateTime? _lastPausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeTracker.onRouteChanged = _handleRouteChanged;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String? _currentRouteName;

  void _handleRouteChanged(String? name) {
    _currentRouteName = name;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final pausedAt = _lastPausedAt;
      _lastPausedAt = null;
      if (pausedAt == null) return;
      if (DateTime.now().difference(pausedAt) < _minBackgroundLockDuration) {
        return;
      }
      _showLockGateIfEnabled();
    }
  }

  Future<void> _showLockGateIfEnabled() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('auth_enabled') ?? true;
    if (!enabled) return;
    if (AuthService.authInProgress ||
        AuthService.isRecentlyAuthed ||
        AuthService.isSessionValid) {
      return;
    }
    if (_currentRouteName == LockGatePage.routeName) return;
    final navigator = _navKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: LockGatePage.routeName),
        builder: (_) => const LockGatePage(replaceOnSuccess: false),
      ),
    );
  }

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
      builder: (context, child) {
        final responsive = ResponsiveBreakpoints.builder(
          child: child ?? const SizedBox.shrink(),
          breakpoints: const [
            Breakpoint(start: 0, end: 450, name: MOBILE),
            Breakpoint(start: 451, end: 800, name: TABLET),
            Breakpoint(start: 801, end: 1920, name: DESKTOP),
            Breakpoint(start: 1921, end: double.infinity, name: '4K'),
          ],
        );
        return AppBackgroundShell(child: responsive);
      },
      theme: _lightTheme(),
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      navigatorObservers: [_routeTracker],
      home: _BootstrapGate(initFuture: widget.initFuture),
    );
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate({required this.initFuture});

  final Future<void> initFuture;

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  late final Future<void> _initFuture;
  Widget? _app;

  @override
  void initState() {
    super.initState();
    _initFuture = widget.initFuture;
    _initFuture.then((_) => unawaited(_scheduleAutoArchive()));
  }

  Widget _buildApp() => const LockGatePage();

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

class _RouteTracker extends NavigatorObserver {
  void Function(String? name)? onRouteChanged;

  void _notify(Route<dynamic>? route) {
    onRouteChanged?.call(route?.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _notify(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _notify(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _notify(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
