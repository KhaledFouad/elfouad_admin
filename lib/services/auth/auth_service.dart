import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static const Duration gracePeriod = Duration(seconds: 8);
  static const Duration sessionDuration = Duration(minutes: 5);
  static DateTime? lastAuthAt;
  static bool authInProgress = false;

  AuthService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticateWithSystem({
    String reason = 'Please authenticate to continue',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  static bool get isRecentlyAuthed {
    final ts = lastAuthAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < gracePeriod;
  }

  static bool get isSessionValid {
    final ts = lastAuthAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < sessionDuration;
  }
}
