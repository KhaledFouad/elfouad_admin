import 'dart:async' show unawaited;
import 'package:elfouad_admin/core/utils/firestore_tuning.dart';
import 'package:elfouad_admin/presentation/auth/lock_gate_page.dart';
import 'package:elfouad_admin/presentation/stats/utils/op_day.dart'
    show opDayKeyFromLocal, kOpShiftHours;
import 'package:elfouad_admin/services/auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/services/archive/auto_archiver.dart'
    show
        DailyArchiveRunResult,
        runAutoArchiveIfNeeded,
        runDailyArchiveForClosedDayIfNeeded;
import 'package:elfouad_admin/services/archive/daily_archive_stats.dart'
    show backfillDailyArchiveForMonth, syncDailyArchiveForDay;
import 'package:elfouad_admin/services/archive/monthly_archive_stats.dart'
    show syncMonthlyArchiveForMonth;
import 'package:elfouad_admin/services/sales/deferred_sales_migration.dart'
    show migrateDeferredSalesIfNeeded;
import 'package:elfouad_admin/services/app/version_gate_service.dart';
import 'package:elfouad_admin/services/device/device_control_service.dart';
import 'package:elfouad_admin/core/widgets/app_background.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'services/firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _primaryHex = 0xFF543824;
const _accentHex = 0xFFC49A6C;
const _maintenanceLastClosedDayKey = 'maintenance_last_closed_day_key';
const _maintenanceLastArchiveMonthKey = 'maintenance_last_archive_month_key';
const _maintenanceLastClosedMonthKey = 'maintenance_last_closed_month_key';
const _maintenanceDailySchemaVersionKey = 'maintenance_daily_schema_version';
const _maintenanceRepair20260211DecemberMissingDoneKey =
    'maintenance_repair_2026_02_11_december_missing_v2_done';
const _maintenanceRepair20260211DailyStatsDoneKey =
    'maintenance_repair_2026_02_13_daily_2026_02_11_v1_done';

const _dailyArchiveSchemaVersion = 10;

Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  await configureFirestore();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _firebaseInit = _initFirebase();
  runApp(MyApp(initFuture: _firebaseInit));
}

Future<void> _scheduleMaintenance() async {
  await Future<void>.delayed(const Duration(seconds: 8));
  unawaited(migrateDeferredSalesIfNeeded());

  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  await _ensureFebruary11DailyArchiveRebuildIfNeeded(
    prefs: prefs,
    nowLocal: now,
  );

  final currentOpStart = DateTime(now.year, now.month, now.day, kOpShiftHours);
  final effectiveOpStart = now.isBefore(currentOpStart)
      ? currentOpStart.subtract(const Duration(days: 1))
      : currentOpStart;
  final closedDayStart = effectiveOpStart.subtract(const Duration(days: 1));
  final closedDayKey = opDayKeyFromLocal(closedDayStart);
  final lastClosedDayKey = prefs.getString(_maintenanceLastClosedDayKey);
  final storedSchemaVersion =
      prefs.getInt(_maintenanceDailySchemaVersionKey) ?? 0;
  final shouldRunDailyMaintenance =
      lastClosedDayKey != closedDayKey ||
      storedSchemaVersion < _dailyArchiveSchemaVersion;
  if (!shouldRunDailyMaintenance) return;

  await _ensureDecemberArchiveDailyCompleteIfNeeded(
    prefs: prefs,
    nowLocal: now,
  );

  try {
    final dailyResult = await runDailyArchiveForClosedDayIfNeeded(
      closedDayStartLocal: closedDayStart,
      prefs: prefs,
    );
    if (dailyResult == DailyArchiveRunResult.synced ||
        dailyResult == DailyArchiveRunResult.alreadySynced) {
      await prefs.setString(_maintenanceLastClosedDayKey, closedDayKey);
    }
  } catch (_) {}

  await _syncClosedMonthArchiveIfNeeded(prefs: prefs, nowLocal: now);

  await prefs.setInt(
    _maintenanceDailySchemaVersionKey,
    _dailyArchiveSchemaVersion,
  );

  if (!kReleaseMode) {
    return;
  }

  final effectiveMonthKey = _effectiveMaintenanceMonthKey(DateTime.now());
  final lastArchiveMonth = prefs.getString(_maintenanceLastArchiveMonthKey);
  if (lastArchiveMonth == effectiveMonthKey) return;

  try {
    await runAutoArchiveIfNeeded(
      adminUid: AppStrings.systemUserId,
      batchSize: 200,
    );
    await prefs.setString(_maintenanceLastArchiveMonthKey, effectiveMonthKey);
  } catch (_) {}
}

String _effectiveMaintenanceMonthKey(DateTime nowLocal) {
  return _monthKey(_effectiveMaintenanceMonth(nowLocal));
}

DateTime _effectiveMaintenanceMonth(DateTime nowLocal) {
  final monthStartLocal = DateTime(
    nowLocal.year,
    nowLocal.month,
    1,
    kOpShiftHours,
  );
  final effectiveMonth = nowLocal.isBefore(monthStartLocal)
      ? DateTime(nowLocal.year, nowLocal.month - 1, 1)
      : DateTime(nowLocal.year, nowLocal.month, 1);
  return effectiveMonth;
}

String _monthKey(DateTime month) {
  final m = month.month.toString().padLeft(2, '0');
  return '${month.year}-$m';
}

Future<void> _syncClosedMonthArchiveIfNeeded({
  required SharedPreferences prefs,
  required DateTime nowLocal,
}) async {
  final effectiveMonth = _effectiveMaintenanceMonth(nowLocal);
  final closedMonth = DateTime(
    effectiveMonth.year,
    effectiveMonth.month - 1,
    1,
  );
  final closedMonthKey = _monthKey(closedMonth);
  final lastClosedMonthKey = prefs.getString(_maintenanceLastClosedMonthKey);
  if (lastClosedMonthKey == closedMonthKey) return;

  try {
    await syncMonthlyArchiveForMonth(month: closedMonth, force: true);
    await prefs.setString(_maintenanceLastClosedMonthKey, closedMonthKey);
  } catch (_) {}
}

Future<void> _backfillDecemberMissingDays(DateTime nowLocal) async {
  final targetYear = nowLocal.month >= 12 ? nowLocal.year : nowLocal.year - 1;
  final december = DateTime(targetYear, 12, 1);
  await backfillDailyArchiveForMonth(
    month: december,
    includeLiveSales: true,
    refreshExisting: true,
    writeEmptyDays: true,
  );
  await syncMonthlyArchiveForMonth(month: december, force: true);
}

Future<void> _ensureFebruary11DailyArchiveRebuildIfNeeded({
  required SharedPreferences prefs,
  required DateTime nowLocal,
}) async {
  final alreadyDone =
      prefs.getBool(_maintenanceRepair20260211DailyStatsDoneKey) ?? false;
  if (alreadyDone) return;

  final targetDayStart = DateTime(2026, 2, 11, kOpShiftHours);
  final closedAt = targetDayStart.add(const Duration(days: 1));
  if (nowLocal.isBefore(closedAt)) return;

  try {
    await syncDailyArchiveForDay(dayLocal: targetDayStart);
    await syncMonthlyArchiveForMonth(month: DateTime(2026, 2, 1), force: true);
    await prefs.setBool(_maintenanceRepair20260211DailyStatsDoneKey, true);
  } catch (_) {
    // Will retry next launch.
  }
}

late final Future<void> _firebaseInit;

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

Future<void> _ensureDecemberArchiveDailyCompleteIfNeeded({
  required SharedPreferences prefs,
  required DateTime nowLocal,
}) async {
  final alreadyDone =
      prefs.getBool(_maintenanceRepair20260211DecemberMissingDoneKey) ?? false;
  if (alreadyDone) return;

  final targetYear = nowLocal.month >= 12 ? nowLocal.year : nowLocal.year - 1;
  final expectedDays = DateUtils.getDaysInMonth(targetYear, 12);

  try {
    final existing = await FirebaseFirestore.instance
        .collection('archive_daily')
        .doc('$targetYear')
        .collection('12')
        .get();
    if (existing.docs.length >= expectedDays) {
      await prefs.setBool(
        _maintenanceRepair20260211DecemberMissingDoneKey,
        true,
      );
      return;
    }
  } catch (_) {
    // Will retry next launch.
    return;
  }

  try {
    await _backfillDecemberMissingDays(nowLocal);
    await prefs.setBool(_maintenanceRepair20260211DecemberMissingDoneKey, true);
  } catch (_) {
    // Will retry next launch.
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate({required this.initFuture});

  final Future<void> initFuture;

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  late final Future<_BootstrapDecision> _bootFuture;
  DeviceControlService? _deviceControlService;
  Widget? _app;

  @override
  void initState() {
    super.initState();
    _bootFuture = _boot();
  }

  Widget _buildApp() => const LockGatePage();

  Future<_BootstrapDecision> _boot() async {
    await widget.initFuture;
    _deviceControlService ??= DeviceControlService(
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );
    final device = await _deviceControlService!.bootstrap();
    final versionGate = await checkAppVersionGate();
    if (!versionGate.blocked && !device.blocked) {
      unawaited(_scheduleMaintenance());
    }
    return _BootstrapDecision(versionGate: versionGate, deviceBlocked: device);
  }

  @override
  void dispose() {
    _deviceControlService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapDecision>(
      future: _bootFuture,
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
        final decision = snapshot.data;
        if (decision != null && decision.versionGate.blocked) {
          return _ForceUpdateScreen(result: decision.versionGate);
        }
        if (decision != null && decision.deviceBlocked.blocked) {
          return _DeviceDisabledScreen(uid: decision.deviceBlocked.uid);
        }
        final service = _deviceControlService;
        if (service == null) {
          return const _SplashScreen();
        }
        return ValueListenableBuilder<bool>(
          valueListenable: service.blockedListenable,
          builder: (context, blocked, _) {
            if (blocked) {
              return _DeviceDisabledScreen(uid: service.uid ?? '');
            }
            return _app ??= _buildApp();
          },
        );
      },
    );
  }
}

class _BootstrapDecision {
  const _BootstrapDecision({
    required this.versionGate,
    required this.deviceBlocked,
  });

  final AppVersionGateResult versionGate;
  final DeviceControlBootstrapResult deviceBlocked;
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

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({required this.result});

  final AppVersionGateResult result;

  @override
  Widget build(BuildContext context) {
    final message = result.message.trim().isEmpty
        ? 'هذه النسخة قديمة وتم إيقافها. رجاءً حدّث التطبيق إلى أحدث نسخة.'
        : result.message.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.system_update_alt_rounded,
                        size: 48,
                        color: Color(0xFF5D4037),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'يتطلب تحديث التطبيق',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'النسخة الحالية: ${result.currentBuild}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'النسخة المطلوبة: ${result.requiredBuild}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () {
                          SystemNavigator.pop();
                        },
                        child: const Text('إغلاق التطبيق'),
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

class _DeviceDisabledScreen extends StatelessWidget {
  const _DeviceDisabledScreen({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        size: 48,
                        color: Color(0xFFB71C1C),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'تم إيقاف هذا الجهاز',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'تم تعطيل صلاحية هذا الجهاز من لوحة التحكم.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.4),
                      ),
                      if (uid.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Device UID: $uid',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () {
                          SystemNavigator.pop();
                        },
                        child: const Text('إغلاق التطبيق'),
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
