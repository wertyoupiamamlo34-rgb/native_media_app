import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionRequestHelper {
  static Future<Map<Permission, PermissionStatus>>? _currentRequest;

  static Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) {
    if (_currentRequest != null) {
      return _currentRequest!;
    }

    _currentRequest = _performRequest(permissions);
    return _currentRequest!;
  }

  static Future<Map<Permission, PermissionStatus>> _performRequest(
    List<Permission> permissions,
  ) async {
    try {
      return await permissions.request();
    } on PlatformException catch (e) {
      final msg = e.message ?? '';
      if (msg.contains('already running')) {
        return const <Permission, PermissionStatus>{};
      }
      rethrow;
    } finally {
      _currentRequest = null;
    }
  }
}
