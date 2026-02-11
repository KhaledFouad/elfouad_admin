import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceControlBootstrapResult {
  const DeviceControlBootstrapResult({
    required this.blocked,
    required this.uid,
  });

  final bool blocked;
  final String uid;
}

class DeviceControlService {
  DeviceControlService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  final ValueNotifier<bool> _isBlocked = ValueNotifier<bool>(false);
  ValueListenable<bool> get blockedListenable => _isBlocked;
  bool get isBlocked => _isBlocked.value;
  String? get uid => _uid;

  String? _uid;
  Timer? _lastSeenTimer;
  Timer? _enabledPollTimer;
  _DevicePayload? _cachedPayload;

  static const Duration _lastSeenInterval = Duration(minutes: 12);
  static const Duration _enabledPollInterval = Duration(minutes: 1);

  Future<DeviceControlBootstrapResult> bootstrap() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Anonymous auth is required before device bootstrap.');
    }
    _uid = user.uid;

    _cachedPayload ??= await _buildPayload();
    await _upsertDeviceDoc();
    await _checkEnabled();

    _startTimers();
    return DeviceControlBootstrapResult(
      blocked: _isBlocked.value,
      uid: _uid ?? '',
    );
  }

  Future<void> _upsertDeviceDoc() async {
    final id = _uid;
    final payload = _cachedPayload;
    if (id == null || payload == null) return;

    final ref = _firestore.collection('devices').doc(id);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'enabled': true,
          'platform': payload.platform,
          'model': payload.model,
          'appVersion': payload.appVersion,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }
      tx.set(ref, {
        'platform': payload.platform,
        'model': payload.model,
        'appVersion': payload.appVersion,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _updateLastSeen() async {
    final id = _uid;
    final payload = _cachedPayload;
    if (id == null || payload == null) return;
    final ref = _firestore.collection('devices').doc(id);
    try {
      await ref.set({
        'platform': payload.platform,
        'model': payload.model,
        'appVersion': payload.appVersion,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // If blocked by rules, the enabled check will flip app state to blocked.
    }
  }

  Future<void> _checkEnabled() async {
    final id = _uid;
    if (id == null) return;
    final ref = _firestore.collection('devices').doc(id);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        _isBlocked.value = false;
        return;
      }
      final enabled = (snap.data()?['enabled'] == true);
      _isBlocked.value = !enabled;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _isBlocked.value = true;
        return;
      }
      _isBlocked.value = true;
    } catch (_) {
      _isBlocked.value = true;
    }
  }

  void _startTimers() {
    _lastSeenTimer?.cancel();
    _enabledPollTimer?.cancel();

    _lastSeenTimer = Timer.periodic(_lastSeenInterval, (_) {
      unawaited(_updateLastSeen());
    });
    _enabledPollTimer = Timer.periodic(_enabledPollInterval, (_) {
      unawaited(_checkEnabled());
    });
  }

  Future<_DevicePayload> _buildPayload() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final platform = _platformName();
    final model = await _readModel(platform);
    final appVersion =
        '${packageInfo.version.trim()}+${packageInfo.buildNumber.trim()}';
    return _DevicePayload(
      platform: platform,
      model: model,
      appVersion: appVersion,
    );
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<String> _readModel(String platform) async {
    if (kIsWeb) return 'web';
    final info = DeviceInfoPlugin();
    try {
      switch (platform) {
        case 'android':
          final a = await info.androidInfo;
          return '${a.manufacturer} ${a.model}'.trim();
        case 'ios':
          final i = await info.iosInfo;
          return '${i.name} ${i.model}'.trim();
        case 'windows':
          final w = await info.windowsInfo;
          return '${w.computerName} ${w.productName}'.trim();
        case 'macos':
          final m = await info.macOsInfo;
          return '${m.model} ${m.osRelease}'.trim();
        case 'linux':
          final l = await info.linuxInfo;
          return '${l.prettyName} ${l.machineId}'.trim();
        default:
          return platform;
      }
    } catch (_) {
      return platform;
    }
  }

  void dispose() {
    _lastSeenTimer?.cancel();
    _enabledPollTimer?.cancel();
    _isBlocked.dispose();
  }
}

class _DevicePayload {
  const _DevicePayload({
    required this.platform,
    required this.model,
    required this.appVersion,
  });

  final String platform;
  final String model;
  final String appVersion;
}
