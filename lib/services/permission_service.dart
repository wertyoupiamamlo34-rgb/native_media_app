import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Helper to request runtime media/storage permissions on Android.
class PermissionService {
  /// Ensure the app has permission to read device media.
  /// Returns true if granted.
  static Future<bool> ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 13+ uses READ_MEDIA_AUDIO instead of legacy storage permission.
    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    // For older Android versions, fall back to legacy storage permission.
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return true;

    // If a broader managed-storage grant is available, accept it.
    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) return true;

    return (await Permission.audio.isGranted) ||
        (await Permission.storage.isGranted) ||
        (await Permission.manageExternalStorage.isGranted);
  }
}
