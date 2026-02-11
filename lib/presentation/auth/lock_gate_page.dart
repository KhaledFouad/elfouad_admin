import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elfouad_admin/presentation/expenses/feature.dart'
    show ExpensesCubit;
import 'package:elfouad_admin/presentation/home/app_shell.dart';
import 'package:elfouad_admin/presentation/grind/state/grind_providers.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/drinks_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/extras_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/manage_tab_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/tahwiga_cubit.dart';
import 'package:elfouad_admin/presentation/recipes/bloc/recipes_cubit.dart';
import 'package:elfouad_admin/presentation/stats/bloc/stats_cubit.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:elfouad_admin/services/auth/auth_service.dart';

class LockGatePage extends StatefulWidget {
  const LockGatePage({super.key, this.replaceOnSuccess = true});

  final bool replaceOnSuccess;
  static const routeName = '/lock-gate';

  @override
  State<LockGatePage> createState() => _LockGatePageState();
}

class _LockGatePageState extends State<LockGatePage>
    with WidgetsBindingObserver {
  static const _authEnabledKey = 'auth_enabled';
  static const _webFixedPassword = '1825';

  final AuthService _authService = AuthService();
  final TextEditingController _webPasswordController = TextEditingController();
  bool _loading = true;
  bool _authEnabled = true;
  String? _message;
  bool _authInProgress = false;
  bool _webMode = false;
  String? _webError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAndAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requireAuthOnResume();
    }
  }

  Future<void> _initAndAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_authEnabledKey) ?? true;
    if (!mounted) return;
    setState(() {
      _authEnabled = enabled;
    });

    if (!_authEnabled) {
      _goToHome();
      return;
    }
    if (kIsWeb) {
      _initWebPassword();
      return;
    }
    await _authenticate();
  }

  Future<void> _requireAuthOnResume() async {
    if (!_authEnabled ||
        _authInProgress ||
        AuthService.isRecentlyAuthed ||
        AuthService.isSessionValid) {
      return;
    }
    await _authenticate();
  }

  void _initWebPassword() {
    if (!mounted) return;
    setState(() {
      _webMode = true;
      _loading = false;
      _message = null;
      _webError = null;
    });
  }

  Future<void> _checkWebPassword() async {
    final raw = _webPasswordController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _webError = 'اكتب كلمة المرور أولًا.';
      });
      return;
    }
    if (raw != _webFixedPassword) {
      setState(() {
        _webError = 'كلمة المرور غير صحيحة.';
      });
      return;
    }
    _goToHome();
  }

  Future<void> _authenticate() async {
    if (_authInProgress) return;
    setState(() {
      _loading = true;
      _message = null;
      _authInProgress = true;
    });
    AuthService.authInProgress = true;

    final supported = await _authService.isDeviceSupported();
    if (!supported) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _authInProgress = false;
        _message = 'الجهاز لا يدعم المصادقة.';
      });
      AuthService.authInProgress = false;
      return;
    }

    final ok = await _authService.authenticateWithSystem(
      reason: 'يرجى المصادقة لفتح التطبيق',
    );

    if (!mounted) return;
    if (ok) {
      AuthService.lastAuthAt = DateTime.now();
      AuthService.authInProgress = false;
      _goToHome();
    } else {
      setState(() {
        _loading = false;
        _authInProgress = false;
        _message = 'فشل التحقق أو تم الإلغاء.';
      });
      AuthService.authInProgress = false;
    }
  }

  void _goToHome() {
    setState(() {
      _loading = false;
      _authInProgress = false;
    });
    final route = MaterialPageRoute(
      settings: const RouteSettings(name: _HomeDashboardRoot.routeName),
      builder: (_) => const _HomeDashboardRoot(),
    );
    if (widget.replaceOnSuccess) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 56, color: Colors.brown),
                const SizedBox(height: 12),
                const Text(
                  'التطبيق مقفل',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (_webMode)
                  Column(
                    children: [
                      const Text(
                        'اكتب كلمة المرور لفتح الموقع.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _webPasswordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          errorText: _webError,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _checkWebPassword(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _checkWebPassword,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('دخول'),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Text(
                        _message ??
                            (_loading
                                ? 'جاري التحقق من بصمة الجهاز...'
                                : 'يرجى التحقق لفتح التطبيق.'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const CircularProgressIndicator()
                      else
                        FilledButton.icon(
                          onPressed: _authenticate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDashboardRoot extends StatelessWidget {
  const _HomeDashboardRoot();
  static const routeName = '/home-dashboard';

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => NavCubit()),
        BlocProvider(create: (_) => ExpensesCubit()),
        BlocProvider(create: (_) => RecipesCubit()),
        BlocProvider(create: (_) => InventoryCubit()),
        BlocProvider(create: (_) => DrinksCubit()),
        BlocProvider(create: (_) => ExtrasCubit()),
        BlocProvider(create: (_) => TahwigaCubit()),
        BlocProvider(create: (_) => ManageTabCubit()..loadLastTab()),
        BlocProvider(create: (_) => GrindCubit()),
        BlocProvider(lazy: false, create: (_) => StatsCubit()),
      ],
      child: const AppShell(),
    );
  }
}
