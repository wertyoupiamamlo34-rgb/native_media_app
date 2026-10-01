// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:native_media_app/screens/settings/pages/edit_background_demo_page.dart';
import 'package:native_media_app/screens/settings/pages/notifications_settings_page.dart';
import 'package:native_media_app/widgets/accent_color_section.dart';

import '../../glass_app_bar.dart';
import '../../widgets/app_background_layer.dart';
import '../../services/sonva_theme_service.dart';
import '../../services/app_background_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  static const _userNameKey = 'sonva_user_name';
  final TextEditingController _nameController = TextEditingController();
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  SonvaThemeMode _selectedMode = SonvaThemeMode.colorful;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _selectedMode = SonvaThemeService.instance.mode;
    SonvaThemeService.instance.addListener(_handleThemeChanged);
    AppBackgroundService.instance.addListener(_handleAccentChanged);
    _loadUserName();
    _animationController.forward();
  }

  @override
  void dispose() {
    SonvaThemeService.instance.removeListener(_handleThemeChanged);
    AppBackgroundService.instance.removeListener(_handleAccentChanged);
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleThemeChanged() {
    if (!mounted) return;
    setState(() => _selectedMode = SonvaThemeService.instance.mode);
  }

  void _handleAccentChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _nameController.text = prefs.getString(_userNameKey) ?? '';
  }

  Future<void> _saveUserName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: AppBackgroundLayer(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const SizedBox(height: 20),
              GlassAppBar(
                image: 'assets/images/Circle.png',
                onPressed: () {
                  Navigator.of(context).pop();
                },
                title: 'Music',
                subtitle: 'Settings & Preferences',
                icon: Icons.arrow_forward_ios,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _GlassContainer(
                        child: Column(
                      children: [
                        _buildProfileSection(textColor),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              _buildThemeTab(
                                icon: Icons.dark_mode_outlined,
                                label: 'داكن',
                                selected: _selectedMode == SonvaThemeMode.dark,
                                onTap: () async {
                                  await SonvaThemeService.instance
                                      .setMode(SonvaThemeMode.dark);
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildThemeTab(
                                icon: Icons.light_mode_outlined,
                                label: 'فاتح',
                                selected: _selectedMode == SonvaThemeMode.light,
                                onTap: () async {
                                  await SonvaThemeService.instance
                                      .setMode(SonvaThemeMode.light);
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildThemeTab(
                                icon: Icons.palette_outlined,
                                label: 'ملون',
                                selected:
                                    _selectedMode == SonvaThemeMode.colorful,
                                onTap: () async {
                                  await SonvaThemeService.instance
                                      .setMode(SonvaThemeMode.colorful);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    )),
                    const SizedBox(height: 24),
                    _GlassContainer(child: _buildThemeSection(primaryColor)),
                    const SizedBox(height: 24),
                    _GlassContainer(
                      child: _buildExtraFeaturesSection(primaryColor),
                    ),
                    const SizedBox(height: 24),
                    _GlassContainer(
                      child: _buildAboutSection(primaryColor, textColor),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircleAvatar(
              maxRadius: 80,
              backgroundColor: Colors.grey,
              child: Icon(
                Icons.person_sharp,
                size: 60,
              )),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            onChanged: (value) => _saveUserName(value),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              hintText: 'اسمك هنا',
              hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        AccentColorSection(
          selected: AppBackgroundService.instance.accentColor,
          accent: AppBackgroundService.instance.accentColor,
          showDescription: false,
          onChanged: (color) async {
            await AppBackgroundService.instance.setAccentColor(color);
          },
        ),
        if (_selectedMode == SonvaThemeMode.colorful)
          _buildTile(
            Icons.wallpaper,
            'الخلفية ',
            'تخصيص المظهر ',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EditBackgroundDemoPage(),
                ),
              );
            },
          ),
        _buildTile(Icons.language, 'اللغة', 'العربية'),
      ],
    );
  }

  Widget _buildExtraFeaturesSection(Color primaryColor) {
    return Column(
      children: [
        _buildTile(
          Icons.notifications_active_outlined,
          'الإشعارات',
          'إعدادات إشعارات الأغاني الجديدة',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsSettingsPage(),
              ),
            );
          },
        ),
        Divider(color: primaryColor.withOpacity(0.2)),
        _buildTile(Icons.schedule, 'التشغيل المجدول', 'وقت محدد'),
        Divider(color: primaryColor.withOpacity(0.2)),
        _buildTile(Icons.star_rate, 'تقييم التطبيق', 'ادعمنا بتقييم'),
        Divider(color: primaryColor.withOpacity(0.2)),
        _buildTile(Icons.share, 'مشاركة التطبيق', 'شارك التطبيق مع أصدقائك'),
      ],
    );
  }

  Widget _buildAboutSection(Color primaryColor, Color textColor) {
    return InkWell(
      onTap: () {},
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset('assets/images/Circle.png'),
        ),
        title: Text(
          'SONVA',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          'Version 1.0.0\nDeveloped by Mahmoud',
          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildThemeTab({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final tabColor = selected
        ? Theme.of(context).primaryColor
        : Theme.of(context).cardColor.withOpacity(0.55);
    final tabBorderColor = selected
        ? Theme.of(context).primaryColor
        : Theme.of(context).dividerColor.withOpacity(0.45);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: tabColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tabBorderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Icon(icon, color: Theme.of(context).primaryColor, size: 28),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;

  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.2)
                : Colors.black.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}
