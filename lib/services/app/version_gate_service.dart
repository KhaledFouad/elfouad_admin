import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionGateResult {
  const AppVersionGateResult({
    required this.blocked,
    required this.currentBuild,
    required this.requiredBuild,
    required this.message,
  });

  const AppVersionGateResult.allowed()
    : blocked = false,
      currentBuild = 0,
      requiredBuild = 0,
      message = '';

  final bool blocked;
  final int currentBuild;
  final int requiredBuild;
  final String message;
}

Future<AppVersionGateResult> checkAppVersionGate({
  FirebaseFirestore? firestore,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;

  final PackageInfo info;
  try {
    info = await PackageInfo.fromPlatform();
  } catch (_) {
    return const AppVersionGateResult.allowed();
  }
  final currentBuild = int.tryParse(info.buildNumber.trim()) ?? 0;

  Map<String, dynamic>? data;
  try {
    final snap = await db.collection('meta').doc('app_policy').get();
    data = snap.data();
  } catch (_) {
    return const AppVersionGateResult.allowed();
  }
  if (data == null || data.isEmpty) {
    return const AppVersionGateResult.allowed();
  }

  final minBuild = _readMinBuildForCurrentPlatform(data);
  if (minBuild <= 0) return const AppVersionGateResult.allowed();
  final blocked = currentBuild < minBuild;
  if (!blocked) {
    return AppVersionGateResult(
      blocked: false,
      currentBuild: currentBuild,
      requiredBuild: minBuild,
      message: '',
    );
  }

  final message = _readMessage(data);
  return AppVersionGateResult(
    blocked: true,
    currentBuild: currentBuild,
    requiredBuild: minBuild,
    message: message,
  );
}

String _platformKey() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

int _readMinBuildForCurrentPlatform(Map<String, dynamic> data) {
  final platform = _platformKey();
  final platformCandidates = <String>[
    'min_build_$platform',
    'min_build_number_$platform',
    '${platform}_min_build',
    '${platform}_min_build_number',
    'minBuild$platform',
  ];

  for (final key in platformCandidates) {
    final parsed = _parseInt(data[key]);
    if (parsed > 0) return parsed;
  }

  final genericCandidates = <String>[
    'min_build',
    'min_build_number',
    'minBuild',
  ];
  for (final key in genericCandidates) {
    final parsed = _parseInt(data[key]);
    if (parsed > 0) return parsed;
  }

  return 0;
}

String _readMessage(Map<String, dynamic> data) {
  final keys = <String>[
    'message_ar',
    'force_update_message_ar',
    'forceUpdateMessageAr',
    'message',
    'force_update_message',
  ];
  for (final key in keys) {
    final text = (data[key] ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return 'هذه النسخة قديمة وتم إيقافها. رجاءً حدّث التطبيق إلى أحدث نسخة.';
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}
