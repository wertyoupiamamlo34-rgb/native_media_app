import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_media_app/glass_app_bar.dart';
import 'package:native_media_app/screens/settings/settings_screen.dart';
import '../widgets/app_background_layer.dart';
import '../widgets/mini_player.dart';
import 'music_screen.dart';

/// الشاشة الرئيسية: قسمان منفصلان (موسيقى / فيديو) عبر BottomNavigationBar.
/// - في قسم الموسيقى يظهر Mini Player في الأسفل فوق شريط التنقّل.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _index = 0;

  @override
  void initState() {
    super.initState();
    // تقييد الشاشة على الوضع العمودي فقط
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    // السماح بكل الاتجاهات عند الخروج من الشاشة
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackgroundLayer(
        child: SafeArea(
          child: Column(
            children: [
              GlassAppBar(
                image: 'assets/images/Circle.png',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                title: 'SONVA',
                subtitle: 'Your personal media player',
                icon: Icons.settings,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: const [
                    _MusicSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// تركيب يجمع شاشة الموسيقى مع Mini Player في الأسفل.
class _MusicSection extends StatelessWidget {
  const _MusicSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(child: MusicScreen()),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: MiniPlayer(),
        ),
      ],
    );
  }
}
