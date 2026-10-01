import 'package:flutter_test/flutter_test.dart';
import 'package:native_media_app/services/sonva_theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SonvaThemeService.instance.initialize();
  });

  test('switches between dark, light, and colorful themes', () async {
    final service = SonvaThemeService.instance;

    expect(service.mode, SonvaThemeMode.dark);

    await service.setMode(SonvaThemeMode.light);
    expect(service.mode, SonvaThemeMode.light);

    await service.setMode(SonvaThemeMode.colorful);
    expect(service.mode, SonvaThemeMode.colorful);
  });
}
