import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_media_app/main.dart';
import 'package:native_media_app/models/audio_track.dart';
import 'package:native_media_app/screens/music_screen.dart';
import 'package:native_media_app/screens/settings/pages/edit_background_demo_page.dart';
import 'package:native_media_app/widgets/album_art.dart';
import 'package:native_media_app/screens/settings/settings_screen.dart';
import 'package:native_media_app/screens/sonva_welcome_page.dart';
import 'package:native_media_app/services/app_background_service.dart';
import 'package:native_media_app/services/library_preparation_controller.dart';
import 'package:native_media_app/services/sonva_theme_service.dart';
import 'package:native_media_app/widgets/app_background_layer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App starts on the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NativeMediaApp());
    await tester.pump();

    expect(find.text('Where Sound Meets Vision'), findsOneWidget);
  });

  testWidgets('Settings screen exposes the main app sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('المظهر'), findsOneWidget);
  });

  testWidgets('Settings screen exposes the three theme modes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('داكن'), findsOneWidget);
    expect(find.text('فاتح'), findsOneWidget);
    expect(find.text('ملون'), findsOneWidget);
  });

  testWidgets('AppBackgroundLayer shows a custom image in colorful mode', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppBackgroundService.instance.initialize();
    await SonvaThemeService.instance.initialize();
    await AppBackgroundService.instance.removeBackground();

    final tempDir = await getTemporaryDirectory();
    final imageFile = File(p.join(tempDir.path, 'background.png'));
    // Write a minimal valid 1x1 PNG so Image.file can decode it reliably in tests.
    const pngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';
    await imageFile.writeAsBytes(base64Decode(pngBase64));

    await AppBackgroundService.instance.saveSettings(
      imagePath: imageFile.path,
      opacity: 0.2,
      blur: 1.0,
      accentColor: Colors.orange,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppBackgroundLayer(child: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    await SonvaThemeService.instance.setMode(SonvaThemeMode.colorful);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Background editor exposes image selection and save controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EditBackgroundDemoPage()));

    expect(find.text('تخصيص الخلفية'), findsOneWidget);
    expect(find.text('اختر صورة'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
  });

  testWidgets('Welcome page uses an injected preparation controller state', (
    WidgetTester tester,
  ) async {
    final controller = LibraryPreparationController(
      initialState: const LibraryPreparationState(
        progress: 1.0,
        currentStatus: LibraryPreparationStatus.completed,
        songsCount: 7,
        lyricsFilesCount: 3,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SonvaWelcomePage(
          preparationState: const LibraryPreparationState(),
          preparationController: controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('اكتمل التحضير بنجاح'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Welcome page updates library counts from controller changes', (
    WidgetTester tester,
  ) async {
    final controller = LibraryPreparationController(
      initialState: const LibraryPreparationState(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SonvaWelcomePage(
          preparationState: const LibraryPreparationState(),
          preparationController: controller,
        ),
      ),
    );
    await tester.pump();

    controller.state.value = controller.state.value.copyWith(
      songsCount: 7,
      lyricsFilesCount: 3,
    );
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('GlassListCard uses AlbumArt for lazy art loading', (
    WidgetTester tester,
  ) async {
    const track = AudioTrack(
      id: 'track-1',
      uri: 'content://audio/track-1',
      title: 'Song',
      artist: 'Artist',
      album: 'Album',
      albumId: 'album-1',
      albumArtUri: '',
      duration: 120000,
      displayName: 'Song',
      path: '/tmp/song.mp3',
      dateAdded: 0,
      size: 12345,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassListCard(
            title: 'Artist',
            subtitle: 'فنان',
            iconFallback: Icons.person_rounded,
            artUri: '',
            fallbackTrack: track,
            onTap: () {},
            onMore: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AlbumArt), findsOneWidget);
  });
}
