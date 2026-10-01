import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_media_app/services/app_background_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final directory = Directory('/tmp/native_media_app_test_docs');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return directory.path;
        }
        return null;
      },
    );
    await AppBackgroundService.instance.removeBackground();
  });

  test(
      'saveSettings keeps the existing background when no new image is provided',
      () async {
    final service = AppBackgroundService.instance;
    final directory = await getApplicationDocumentsDirectory();
    final sourceFile = File(p.join(directory.path, 'source_image.png'));
    await sourceFile.writeAsBytes([1, 2, 3, 4]);

    await service.saveSettings(
      imagePath: sourceFile.path,
      opacity: 0.2,
      blur: 1.0,
      accentColor: Colors.blue,
    );

    final firstSavedPath = service.backgroundFile?.path;
    expect(firstSavedPath, isNotNull);

    await service.saveSettings(
      imagePath: null,
      opacity: 0.4,
      blur: 2.0,
      accentColor: Colors.red,
    );

    expect(service.backgroundFile?.path, firstSavedPath);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('background_image_path'), firstSavedPath);
  });

  test(
      'saveSettings does not fail when the selected path is the saved background',
      () async {
    final service = AppBackgroundService.instance;
    final directory = await getApplicationDocumentsDirectory();
    final sourceFile = File(p.join(directory.path, 'source_image.png'));
    await sourceFile.writeAsBytes([1, 2, 3, 4]);

    await service.saveSettings(
      imagePath: sourceFile.path,
      opacity: 0.2,
      blur: 1.0,
      accentColor: Colors.blue,
    );

    expect(service.backgroundFile, isNotNull);

    await service.saveSettings(
      imagePath: service.backgroundFile!.path,
      opacity: 0.5,
      blur: 2.0,
      accentColor: Colors.green,
    );

    expect(service.backgroundFile!.existsSync(), isTrue);
    expect(service.backgroundFile!.path, isNotEmpty);
  });
}
