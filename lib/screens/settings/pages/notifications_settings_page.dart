// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:native_media_app/services/sonva_theme_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../glass_app_bar.dart';
import '../../../widgets/app_background_layer.dart';

const _newSongNotificationsEnabledKey = 'new_song_notifications_enabled';
const _newSongNotificationsSoundEnabledKey =
    'new_song_notifications_sound_enabled';
const _newSongNotificationToneKey = 'new_song_notification_tone_key';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final AudioPlayer _previewPlayer;

  bool _newSongNotificationsEnabled = true;
  bool _newSongNotificationsSoundEnabled = true;
  String _newSongNotificationTone = 'tone_one';

  @override
  void initState() {
    super.initState();

    _previewPlayer = AudioPlayer();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _newSongNotificationsEnabled =
          prefs.getBool(_newSongNotificationsEnabledKey) ?? true;
      _newSongNotificationsSoundEnabled =
          prefs.getBool(_newSongNotificationsSoundEnabledKey) ?? true;
      _newSongNotificationTone =
          prefs.getString(_newSongNotificationToneKey) ?? 'tone_one';
    });
  }

  Future<void> _playTonePreview(String toneKey) async {
    final assetPath = switch (toneKey) {
      'tone_two' => 'assets/audio/Sonva_Energy_Aura_1.mp3',
      'tone_three' => 'assets/audio/Sonva_Energy_Aura_2.mp3',
      _ => 'assets/audio/Sonva_Energy_Aura_0.mp3',
    };

    try {
      await _previewPlayer.stop();
      await _previewPlayer.setAsset(assetPath);
      await _previewPlayer.play();
    } catch (_) {
      // Preview failures should not block the selection flow.
    }
  }

  Future<void> _setNewSongNotificationsEnabled(bool enabled) async {
    if (enabled) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('إذن الإشعارات مطلوب'),
            content: const Text(
              'يحتاج التطبيق إلى إذن الإشعارات من النظام قبل تفعيل هذه الميزة.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('حسنًا'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await openAppSettings();
                },
                child: const Text('فتح الإعدادات'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        setState(() {
          _newSongNotificationsEnabled = false;
        });
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newSongNotificationsEnabledKey, enabled);
    if (!mounted) return;
    setState(() {
      _newSongNotificationsEnabled = enabled;
    });
  }

  Future<void> _setNewSongNotificationsSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newSongNotificationsSoundEnabledKey, enabled);
    if (!mounted) return;
    setState(() {
      _newSongNotificationsSoundEnabled = enabled;
    });
  }

  Future<void> _setNewSongNotificationTone(String toneKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_newSongNotificationToneKey, toneKey);
    if (!mounted) return;
    setState(() {
      _newSongNotificationTone = toneKey;
    });
  }

  String _toneLabel(String toneKey) {
    switch (toneKey) {
      case 'tone_two':
        return 'نغمة هادئة';
      case 'tone_three':
        return 'نغمة قصيرة';
      default:
        return 'نغمة التطبيق';
    }
  }

  @override
  void dispose() {
    _previewPlayer.dispose().catchError((_) {});
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final themeMode = SonvaThemeService.instance.mode;
    return AppBackgroundLayer(
      child: Scaffold(
        backgroundColor: themeMode == SonvaThemeMode.colorful
            ? Colors.transparent
            : Theme.of(context).scaffoldBackgroundColor,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const SizedBox(height: 20),
              GlassAppBar(
                image: 'assets/images/Circle.png',
                onPressed: () => Navigator.pop(context),
                title: 'الإشعارات',
                subtitle: 'New Song Notifications',
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildSwitchTile(
                              icon: Icons.notifications_active_outlined,
                              title: 'إشعارات الأغاني الجديدة',
                              subtitle:
                                  'تنبيه عند وصول أغنية جديدة إلى مكتبة الجهاز',
                              value: _newSongNotificationsEnabled,
                              onChanged: _setNewSongNotificationsEnabled,
                            ),
                            Divider(color: primaryColor.withOpacity(0.2)),
                            _buildSwitchTile(
                              icon: Icons.volume_up_outlined,
                              title: 'صوت الإشعار',
                              subtitle:
                                  'تشغيل أو إسكات صوت إشعارات الأغاني الجديدة',
                              value: _newSongNotificationsSoundEnabled,
                              onChanged: _setNewSongNotificationsSoundEnabled,
                            ),
                            Divider(color: primaryColor.withOpacity(0.2)),
                            _buildTile(
                              icon: Icons.music_note,
                              title: 'نغمة الإشعار',
                              subtitle: _toneLabel(_newSongNotificationTone),
                              onTap: () async {
                                if (!_newSongNotificationsSoundEnabled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('فعّل صوت الإشعار أولًا'),
                                    ),
                                  );
                                  return;
                                }

                                final selected = await showDialog<String>(
                                  context: context,
                                  builder: (dialogContext) => SimpleDialog(
                                    title: const Text('اختر نغمة الإشعار'),
                                    children: [
                                      RadioListTile<String>(
                                        value: 'tone_one',
                                        groupValue: _newSongNotificationTone,
                                        title: const Text('نغمة التطبيق'),
                                        onChanged: (value) async {
                                          if (value == null) return;
                                          await _setNewSongNotificationTone(
                                              value);
                                          await _playTonePreview(value);
                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext)
                                                .pop(value);
                                          }
                                        },
                                      ),
                                      RadioListTile<String>(
                                        value: 'tone_two',
                                        groupValue: _newSongNotificationTone,
                                        title: const Text('نغمة هادئة'),
                                        onChanged: (value) async {
                                          if (value == null) return;
                                          await _setNewSongNotificationTone(
                                              value);
                                          await _playTonePreview(value);
                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext)
                                                .pop(value);
                                          }
                                        },
                                      ),
                                      RadioListTile<String>(
                                        value: 'tone_three',
                                        groupValue: _newSongNotificationTone,
                                        title: const Text('نغمة قصيرة'),
                                        onChanged: (value) async {
                                          if (value == null) return;
                                          await _setNewSongNotificationTone(
                                              value);
                                          await _playTonePreview(value);
                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext)
                                                .pop(value);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );

                                if (selected != null) {
                                  await _setNewSongNotificationTone(selected);
                                  await _playTonePreview(selected);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'يمكنك أيضًا تغيير صوت الإشعار من هذه الصفحة فقط، بدل الرجوع إلى إعدادات النظام.',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      secondary: Icon(icon, color: Theme.of(context).primaryColor, size: 28),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      value: value,
      activeColor: Theme.of(context).primaryColor,
      onChanged: onChanged,
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;

  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: child,
        ),
      ),
    );
  }
}
