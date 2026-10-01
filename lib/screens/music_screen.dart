// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_track.dart';
import '../services/media_service.dart';
import '../services/playlist_storage.dart';
import '../services/sonva_theme_service.dart';
import '../utils/formatters.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';

/// قسم الموسيقى بتصميم زجاجي (Glass) متطابق مع HomeScreen.
/// - TabBar: الفيديو | الشائعة | الكل | المفضلة | الفنانون
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabsLabels = <String>[
    'All Songs',
    'Artists',
    'Playlists',
  ];

  @override
  void initState() {
    super.initState();
    // تقييد الشاشة على الوضع العمودي فقط
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _tabController = TabController(
      length: _tabsLabels.length,
      vsync: this,
      initialIndex: 0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      MediaService.instance.loadAudio();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: MediaService.instance,
      builder: (context, _) {
        final svc = MediaService.instance;

        return Column(
          children: [
            // ================= TabBar زجاجي =================
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                tabs: _tabsLabels
                    .map((t) => _CustomTab(text: t))
                    .toList(growable: false),
              ),
            ),

            // ================= TabBarView بحاويات زجاجية =================
            Expanded(
              child: svc.loadingAudio && svc.audioTracks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _GlassContainer(
                          enableBlur: true,
                          child: _AllTracksTab(tracks: svc.recentTracks),
                        ),
                        _GlassContainer(
                          enableBlur: true,
                          child: _ArtistsTab(grouped: svc.tracksByArtist),
                        ),
                        _GlassContainer(
                          enableBlur: true,
                          child: _PlaylistsTab(
                            popularTracks: svc.popularTracks,
                            favoriteTracks: svc.favoriteTracks,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ────────────────────────── Custom Tab ──────────────────────────
class _CustomTab extends StatelessWidget {
  final String text;
  const _CustomTab({required this.text});

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 25,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: Text(text)),
      ),
    );
  }
}

// ────────────────────────── Glass Container ──────────────────────────
class _GlassContainer extends StatelessWidget {
  final Widget child;
  final bool enableBlur;
  const _GlassContainer({required this.child, this.enableBlur = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: enableBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: child,
              )
            : child,
      ),
    );
  }
}

// ────────────────────────── Themed Background Layer ──────────────────────────
// طبقة خلفية موحدة تستخدم داخل كل الشاشات الفرعية، تتكيف تلقائيًا مع
// وضع الثيم الحالي (فاتح/داكن/ملون) — لا ألوان ثابتة.
class _ThemedBackground extends StatelessWidget {
  final Widget child;
  const _ThemedBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isColorful =
        SonvaThemeService.instance.mode == SonvaThemeMode.colorful;

    final Color bgBase = isColorful
        ? Colors.transparent
        : (isDark
            ? const Color(0xFF0E0A1A).withOpacity(0.55)
            : theme.colorScheme.surface.withOpacity(0.85));

    return Container(
      decoration: BoxDecoration(
        color: bgBase,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

// ────────────────────────── Glass Song Card ──────────────────────────
// بطاقة أغنية زجاجية قابلة لإعادة الاستخدام في كل التبويبات والشاشات.
class GlassSongCard extends StatelessWidget {
  final AudioTrack song;
  final bool isPlaying;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final bool draggable;
  final Widget? dragHandle;

  const GlassSongCard({
    super.key,
    required this.song,
    required this.onTap,
    required this.onMore,
    this.isPlaying = false,
    this.isSelected = false,
    this.draggable = false,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.white.withOpacity(0.55);

    final borderColor = isPlaying
        ? theme.primaryColor.withOpacity(0.75)
        : (isDark
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.9));

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onMore,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: isPlaying
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.25),
                        blurRadius: 14,
                        spreadRadius: 0.5,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AlbumArt(
                          uri: song.albumArtUri,
                          size: 58,
                          radius: 12,
                          lazyFetchUri: () => MediaService.instance
                              .fetchAlbumArtUriForTrack(song),
                        ),
                      ),
                      if (isPlaying)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.equalizer_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPlaying
                              ? theme.primaryColor
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            formatDuration(song.duration),
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              song.displayArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (draggable && dragHandle != null) dragHandle!,
                IconButton(
                  tooltip: 'المزيد',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  onPressed: onMore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Tinted Icon Helpers ──────────────────────────
Icon _tinted(BuildContext context, IconData icon) {
  final c = Theme.of(context).colorScheme.onSurface;
  return Icon(icon, color: c);
}

// ────────────────────────── Shared Song Info Sheet ──────────────────────────
Future<void> showSongInfoSheet(
  BuildContext context,
  AudioTrack song,
) async {
  final theme = Theme.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'معلومات الأغنية',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                song.displayTitle,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                song.displayArtist,
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              const Divider(height: 24),
              _kv(theme, 'المدة', formatDuration(song.duration)),
              _kv(theme, 'الألبوم', song.album.isEmpty ? '—' : song.album),
              _kv(theme, 'الحجم', formatFileSize(song.size)),
              _kv(theme, 'المسار', song.path ?? 'غير متوفر'),
            ],
          ),
        ),
      );
    },
  );
}

Widget _kv(ThemeData theme, String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            k,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
        ),
      ],
    ),
  );
}

// ────────────────────────── Add To Playlist Sheet ──────────────────────────
Future<String?> showAddToPlaylistSheet(
  BuildContext context,
  AudioTrack song,
) async {
  final playlistNames = await PlaylistStorage.loadPlaylistNames();
  final theme = Theme.of(context);

  if (!context.mounted) return null;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _tinted(sheetContext, Icons.playlist_add_rounded),
                  const SizedBox(width: 8),
                  Text(
                    'إضافة إلى قائمة تشغيل',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (playlistNames.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'لا توجد قوائم تشغيل بعد. أنشئ واحدة من تبويبة "Playlists".',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlistNames.length,
                  itemBuilder: (_, i) {
                    final name = playlistNames[i];
                    return ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(name),
                      onTap: () => Navigator.of(sheetContext).pop(name),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

// ────────────────────────── Shared Song Actions Sheet ──────────────────────────
Future<void> showCommonSongActions(
  BuildContext context, {
  required AudioTrack song,
  required List<AudioTrack> playlist,
}) async {
  final theme = Theme.of(context);
  final svc = MediaService.instance;
  final isFav = svc.isFavorite(song.id);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: _tinted(sheetContext, Icons.play_arrow_rounded),
              title: const Text('تشغيل الآن'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final idx = playlist.indexWhere((t) => t.id == song.id);
                svc.playQueue(playlist, startIndex: idx >= 0 ? idx : 0);
              },
            ),
            ListTile(
              leading: _tinted(sheetContext, Icons.queue_play_next_rounded),
              title: const Text('تشغيل بعد الحالي'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final list = [...playlist, song];
                final idx = list.length - 1;
                svc.playQueue(list, startIndex: idx);
              },
            ),
            ListTile(
              leading: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? theme.primaryColor : null,
              ),
              title: Text(isFav ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                svc.toggleFavoriteById(song.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFav
                            ? 'تمت الإزالة من المفضلة'
                            : 'تمت الإضافة إلى المفضلة',
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: _tinted(sheetContext, Icons.playlist_add_rounded),
              title: const Text('إضافة إلى قائمة تشغيل'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final name = await showAddToPlaylistSheet(context, song);
                if (name != null && name.isNotEmpty) {
                  await PlaylistStorage.addTrackToPlaylist(name, song.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تمت الإضافة إلى "$name"')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: _tinted(sheetContext, Icons.share_rounded),
              title: const Text('مشاركة'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('خاصية المشاركة قريبًا')),
                );
              },
            ),
            ListTile(
              leading: _tinted(sheetContext, Icons.info_outline_rounded),
              title: const Text('معلومات الأغنية'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showSongInfoSheet(context, song);
              },
            ),
          ],
        ),
      );
    },
  );
}

// ────────────────────────── Playlists ──────────────────────────
class _PlaylistsTab extends StatefulWidget {
  final List<AudioTrack> popularTracks;
  final List<AudioTrack> favoriteTracks;

  const _PlaylistsTab({
    required this.popularTracks,
    required this.favoriteTracks,
  });

  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab> {
  final List<String> _customPlaylistNames = [];
  final Map<String, List<String>> _customPlaylistTrackIds = {};

  @override
  void initState() {
    super.initState();
    _restoreCustomPlaylists();
  }

  Future<void> _restoreCustomPlaylists() async {
    final names = await PlaylistStorage.loadPlaylistNames();
    if (!mounted) return;
    final tracksByPlaylist = await PlaylistStorage.loadAllPlaylistTrackIds();

    setState(() {
      _customPlaylistNames
        ..clear()
        ..addAll(names);
      _customPlaylistTrackIds
        ..clear()
        ..addAll(tracksByPlaylist);
    });
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final nameController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء قائمة تشغيل'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم القائمة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              if (_customPlaylistNames.contains(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('القائمة موجودة مسبقًا')),
                );
                return;
              }

              setState(() => _customPlaylistNames.add(name));
              _customPlaylistTrackIds[name] = const <String>[];
              await PlaylistStorage.createPlaylist(name);
              if (context.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlaylistActions(
    BuildContext context,
    String name,
    List<AudioTrack> songs,
  ) async {
    final svc = MediaService.instance;
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _tinted(sheetContext, Icons.play_arrow_rounded),
                title: Text('تشغيل $name'),
                onTap: songs.isEmpty
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        await svc.playQueue(songs);
                      },
              ),
              ListTile(
                leading: _tinted(sheetContext, Icons.shuffle_rounded),
                title: const Text('تشغيل عشوائي'),
                onTap: songs.isEmpty
                    ? null
                    : () async {
                        Navigator.of(sheetContext).pop();
                        final shuffled = [...songs]..shuffle();
                        await svc.playQueue(shuffled);
                      },
              ),
              ListTile(
                leading: _tinted(sheetContext, Icons.edit_rounded),
                title: const Text('إعادة تسمية'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _showRenamePlaylistDialog(context, name);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'حذف القائمة',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _confirmDeletePlaylist(context, name);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenamePlaylistDialog(
      BuildContext context, String oldName) async {
    final controller = TextEditingController(text: oldName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة تسمية القائمة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == oldName) {
                Navigator.of(dialogContext).pop();
                return;
              }
              setState(() {
                final i = _customPlaylistNames.indexOf(oldName);
                if (i >= 0) _customPlaylistNames[i] = newName;
                final ids = _customPlaylistTrackIds.remove(oldName);
                if (ids != null) _customPlaylistTrackIds[newName] = ids;
              });
              final oldNames = await PlaylistStorage.loadPlaylistNames();
              if (!oldNames.contains(oldName)) {
                Navigator.of(dialogContext).pop();
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              final updated =
                  oldNames.map((n) => n == oldName ? newName : n).toList();
              await prefs.setStringList(
                  PlaylistStorage.customPlaylistsKey, updated);
              // نقل قائمة الأغاني إلى المفتاح الجديد
              await prefs.setStringList(
                  PlaylistStorage.playlistTracksKey(newName),
                  prefs.getStringList(
                          PlaylistStorage.playlistTracksKey(oldName)) ??
                      const <String>[]);
              await prefs.remove(PlaylistStorage.playlistTracksKey(oldName));
              if (context.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم تغيير الاسم إلى "$newName"')),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePlaylist(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف القائمة؟'),
        content: Text('هل تريد حذف قائمة "$name" نهائيًا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _customPlaylistNames.remove(name);
      _customPlaylistTrackIds.remove(name);
    });
    final prefs = await SharedPreferences.getInstance();
    final names = await PlaylistStorage.loadPlaylistNames();
    await prefs.setStringList(
      PlaylistStorage.customPlaylistsKey,
      names.where((n) => n != name).toList(),
    );
    await prefs.remove(PlaylistStorage.playlistTracksKey(name));
  }

  @override
  Widget build(BuildContext context) {
    final svc = MediaService.instance;
    final smartPlaylists = <Map<String, dynamic>>[
      {
        'name': 'المشغلة مؤخرًا',
        'subtitle': 'الأحدث تشغيلًا ثم الأكثر تشغيلًا',
        'icon': Icons.history_rounded,
        'tracks': widget.popularTracks,
      },
      {
        'name': 'المفضلة',
        'subtitle': 'الأغاني التي قمت بتفضيلها',
        'icon': Icons.favorite_rounded,
        'tracks': widget.favoriteTracks,
      },
    ];

    final customPlaylists = _customPlaylistNames.map(
      (name) {
        final ids = _customPlaylistTrackIds[name] ?? const <String>[];
        final tracks = ids
            .map<AudioTrack?>(
              (id) => svc.audioTracks.cast<AudioTrack?>().firstWhere(
                    (t) => t != null && t.id == id,
                    orElse: () => null,
                  ),
            )
            .whereType<AudioTrack>()
            .toList(growable: false);

        return {
          'name': name,
          'subtitle': 'قائمة مخصصة',
          'icon': Icons.queue_music_rounded,
          'tracks': tracks,
        };
      },
    ).toList(growable: false);

    final allPlaylists = [...smartPlaylists, ...customPlaylists];

    return RefreshIndicator(
      onRefresh: () async {
        await svc.loadAudio(force: true);
        await _restoreCustomPlaylists();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 60),
        itemCount: allPlaylists.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CreatePlaylistTile(
              onTap: () => _showCreatePlaylistDialog(context),
            );
          }

          final playlist = allPlaylists[index - 1];
          final name = playlist['name'] as String;
          final subtitle = playlist['subtitle'] as String;
          final icon = playlist['icon'] as IconData;
          final tracks =
              ((playlist['tracks'] as List<dynamic>?) ?? const <dynamic>[])
                  .map<AudioTrack?>((item) {
                    if (item is AudioTrack) return item;
                    if (item is Map) return AudioTrack.fromMap(item);
                    return null;
                  })
                  .whereType<AudioTrack>()
                  .toList(growable: false);
          final firstArt = tracks.isNotEmpty ? tracks.first.albumArtUri : null;

          return GlassListCard(
            title: name,
            subtitle: subtitle,
            extraInfo: '${tracks.length} أغنية',
            artUri: firstArt,
            iconFallback: icon,
            fallbackTrack: tracks.isNotEmpty ? tracks.first : null,
            isPlaying: svc.snapshot.playing &&
                tracks.any((t) => t.id == svc.snapshot.currentTrackId),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailsScreen(
                    playlistName: name,
                    tracks: tracks,
                  ),
                ),
              );
            },
            onPlay: tracks.isEmpty ? null : () => svc.playQueue(tracks),
            onMore: () => _showPlaylistActions(context, name, tracks),
          );
        },
      ),
    );
  }
}

// ────────────────────────── Create Playlist Tile (glass) ──────────────────────────
class _CreatePlaylistTile extends StatelessWidget {
  final VoidCallback onTap;
  const _CreatePlaylistTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.45),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 36,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إنشاء قائمة تشغيل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أنشئ قائمة جديدة من اختيارك',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Glass List Card (للاستخدام العام) ──────────────────────────
// بطاقة زجاجية كبيرة تُستخدم لعرض الفنانين، قوائم التشغيل، إلخ.
class GlassListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? extraInfo;
  final String? artUri;
  final IconData iconFallback;
  final AudioTrack? fallbackTrack;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback onMore;

  const GlassListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconFallback,
    required this.onTap,
    required this.onMore,
    this.extraInfo,
    this.artUri,
    this.fallbackTrack,
    this.isPlaying = false,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.white.withOpacity(0.55);
    final borderColor = isPlaying
        ? theme.primaryColor.withOpacity(0.75)
        : (isDark
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.9));

    final shouldUseLazyArt =
        (artUri != null && artUri!.isNotEmpty) || fallbackTrack != null;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            FocusScope.of(context).unfocus();
            onTap();
          },
          onLongPress: onMore,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: isPlaying
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.22),
                        blurRadius: 14,
                        spreadRadius: 0.5,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: shouldUseLazyArt
                            ? AlbumArt(
                                uri: artUri,
                                size: 92,
                                radius: 16,
                                lazyFetchUri: fallbackTrack == null
                                    ? null
                                    : () => MediaService.instance
                                        .fetchAlbumArtUriForTrack(
                                            fallbackTrack!),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  iconFallback,
                                  size: 44,
                                  color: theme.primaryColor.withOpacity(0.85),
                                ),
                              ),
                      ),
                      if (isPlaying)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.equalizer_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: isPlaying
                              ? theme.primaryColor
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.65),
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (extraInfo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          extraInfo!,
                          style: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (onPlay != null)
                      IconButton(
                        tooltip: 'تشغيل',
                        icon: Icon(
                          Icons.play_circle_fill_rounded,
                          size: 36,
                          color: theme.primaryColor,
                        ),
                        onPressed: onPlay,
                      ),
                    IconButton(
                      tooltip: 'المزيد',
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      onPressed: onMore,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── Playlist Details Screen (متاح للملاحة من تبويبات أخرى) ──────────────────────────
// نُصدّر النسخة العامة ليتم الإشارة إليها من تبويبة Playlists.
class PlaylistDetailsScreen extends StatefulWidget {
  final String playlistName;
  final List<AudioTrack> tracks;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlistName,
    required this.tracks,
  });

  @override
  State<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends State<PlaylistDetailsScreen> {
  late List<AudioTrack> _displayedSongs;

  @override
  void initState() {
    super.initState();
    _displayedSongs = List<AudioTrack>.from(widget.tracks);
  }

  void _playSong(AudioTrack song) {
    final idx = _displayedSongs.indexWhere((s) => s.id == song.id);
    final startIndex = idx >= 0 ? idx : 0;
    MediaService.instance.playQueue(_displayedSongs, startIndex: startIndex);
  }

  void _playAll() {
    if (_displayedSongs.isEmpty) return;
    _playSong(_displayedSongs.first);
  }

  void _shufflePlay() {
    if (_displayedSongs.isEmpty) return;
    final randomSong =
        _displayedSongs[math.Random().nextInt(_displayedSongs.length)];
    _playSong(randomSong);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _displayedSongs.removeAt(oldIndex);
      _displayedSongs.insert(newIndex, item);
    });
  }

  Future<void> _removeSongFromPlaylist(AudioTrack song) async {
    setState(() => _displayedSongs.removeWhere((t) => t.id == song.id));
    final prefs = await SharedPreferences.getInstance();
    final key = PlaylistStorage.playlistTracksKey(widget.playlistName);
    final ids = (prefs.getStringList(key) ?? const <String>[]).toList();
    ids.removeWhere((id) => id == song.id);
    await prefs.setStringList(key, ids);
  }

  @override
  Widget build(BuildContext context) {
    final svc = MediaService.instance;
    final snap = svc.snapshot;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isColorful =
        SonvaThemeService.instance.mode == SonvaThemeMode.colorful;
    final firstArt =
        _displayedSongs.isNotEmpty ? _displayedSongs.first.albumArtUri : null;

    return Scaffold(
      backgroundColor: isDark
          ? Colors.black.withOpacity(0.35)
          : Colors.grey.withOpacity(0.55),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.playlistName),
        backgroundColor: isColorful
            ? Colors.transparent
            : (isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.white.withOpacity(0.55)),
        elevation: 0,
      ),
      body: _ThemedBackground(
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 16),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          theme.primaryColor.withOpacity(0.05),
                          Colors.transparent
                        ]
                      : [
                          theme.primaryColor.withOpacity(0.45),
                          theme.primaryColor.withOpacity(0.15),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: _displayedSongs.isNotEmpty
                        ? AlbumArt(
                            uri: firstArt,
                            size: 120,
                            radius: 14,
                            lazyFetchUri: () => MediaService.instance
                                .fetchAlbumArtUriForTrack(
                                    _displayedSongs.first),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.album_rounded,
                              size: 70,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'عدد الأغاني: ${_displayedSongs.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play All'),
                            onPressed:
                                _displayedSongs.isEmpty ? null : _playAll,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            )),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle'),
                          onPressed:
                              _displayedSongs.isEmpty ? null : _shufflePlay,
                          style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _displayedSongs.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد أغاني متاحة',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 80),
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      onReorder: _onReorder,
                      itemCount: _displayedSongs.length,
                      itemBuilder: (_, index) {
                        final song = _displayedSongs[index];
                        final isPlaying =
                            snap.playing && snap.currentTrackId == song.id;
                        return GlassSongCard(
                          key: ValueKey('pl-${song.id}'),
                          song: song,
                          isPlaying: isPlaying,
                          onTap: () => _playSong(song),
                          onMore: () => _showPlaylistSongActions(song),
                          draggable: true,
                          dragHandle: ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.55),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlaylistSongActions(AudioTrack song) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _tinted(sheetContext, Icons.play_arrow_rounded),
                title: const Text('تشغيل'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _playSong(song);
                },
              ),
              ListTile(
                leading: Icon(
                  MediaService.instance.isFavorite(song.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: MediaService.instance.isFavorite(song.id)
                      ? theme.primaryColor
                      : null,
                ),
                title: Text(
                  MediaService.instance.isFavorite(song.id)
                      ? 'إزالة من المفضلة'
                      : 'إضافة إلى المفضلة',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  MediaService.instance.toggleFavoriteById(song.id);
                  setState(() {});
                },
              ),
              ListTile(
                leading: _tinted(sheetContext, Icons.playlist_add_rounded),
                title: const Text('إضافة إلى قائمة تشغيل أخرى'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final name = await showAddToPlaylistSheet(context, song);
                  if (name != null && name.isNotEmpty) {
                    await PlaylistStorage.addTrackToPlaylist(name, song.id);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'إزالة من القائمة',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removeSongFromPlaylist(song);
                },
              ),
              ListTile(
                leading: _tinted(sheetContext, Icons.info_outline_rounded),
                title: const Text('معلومات الأغنية'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showSongInfoSheet(context, song);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────── الكل ──────────────────────────
class _AllTracksTab extends StatefulWidget {
  final List<AudioTrack> tracks;
  const _AllTracksTab({required this.tracks});

  @override
  State<_AllTracksTab> createState() => _AllTracksTabState();
}

class _AllTracksTabState extends State<_AllTracksTab> {
  String _query = '';
  String _sortBy = 'default'; // default | title | artist
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  List<AudioTrack> _filteredAndSortedSongs(List<AudioTrack> songs) {
    final q = _query.trim().toLowerCase();
    final filtered = songs.where((song) {
      if (q.isEmpty) return true;
      return song.displayTitle.toLowerCase().contains(q) ||
          song.displayArtist.toLowerCase().contains(q);
    }).toList();

    switch (_sortBy) {
      case 'title':
        filtered.sort(
          (a, b) => a.displayTitle
              .toLowerCase()
              .compareTo(b.displayTitle.toLowerCase()),
        );
        break;
      case 'artist':
        filtered.sort(
          (a, b) => a.displayArtist
              .toLowerCase()
              .compareTo(b.displayArtist.toLowerCase()),
        );
        break;
      case 'default':
      default:
        break;
    }

    return filtered;
  }

  void _onReorder(List<AudioTrack> currentList, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = currentList.removeAt(oldIndex);
      currentList.insert(newIndex, item);
    });
  }

  void _onSongTap(AudioTrack song, List<AudioTrack> current) {
    // إخفاء لوحة المفاتيح تلقائياً
    FocusScope.of(context).unfocus();
    final idx = current.indexWhere((t) => t.id == song.id);
    MediaService.instance.playQueue(current, startIndex: idx >= 0 ? idx : 0);
  }

  @override
  Widget build(BuildContext context) {
    final svc = MediaService.instance;
    final snap = svc.snapshot;
    final theme = Theme.of(context);

    final displayedSongs = _filteredAndSortedSongs([
      ...widget.tracks,
    ]);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              // إخفاء لوحة المفاتيح عند الضغط على Enter
              FocusScope.of(context).unfocus();
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search songs...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play All'),
                  onPressed: displayedSongs.isEmpty
                      ? null
                      : () => svc.playQueue(displayedSongs, startIndex: 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Shuffle'),
                  onPressed: displayedSongs.isEmpty
                      ? null
                      : () {
                          final randomIndex =
                              math.Random().nextInt(displayedSongs.length);
                          svc.playQueue(
                            displayedSongs,
                            startIndex: randomIndex,
                          );
                        },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort Songs',
                onSelected: (value) {
                  setState(() => _sortBy = value);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'default', child: Text('Default')),
                  PopupMenuItem(value: 'title', child: Text('By Title')),
                  PopupMenuItem(value: 'artist', child: Text('By Artist')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: widget.tracks.isEmpty
              ? const EmptyState(
                  icon: Icons.library_music_rounded,
                  title: 'لا توجد ملفات صوتية',
                  subtitle: 'تأكد من منح التطبيق صلاحية الوصول للوسائط',
                )
              : displayedSongs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _query.isNotEmpty
                                ? Icons.search_off
                                : Icons.music_note,
                            size: 80,
                            color: theme.primaryColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _query.isNotEmpty
                                ? 'No songs found'
                                : 'No songs available',
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.9),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _query.isNotEmpty
                                ? 'Try different keywords'
                                : 'Add some songs to start listening',
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_query.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear Search'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 80),
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      onReorder: (oldIndex, newIndex) =>
                          _onReorder(displayedSongs, oldIndex, newIndex),
                      itemCount: displayedSongs.length,
                      itemBuilder: (_, i) {
                        final song = displayedSongs[i];
                        final isPlaying =
                            snap.playing && snap.currentTrackId == song.id;
                        return GlassSongCard(
                          key: ValueKey('tr-${song.id}'),
                          song: song,
                          isPlaying: isPlaying,
                          onTap: () => _onSongTap(song, displayedSongs),
                          onMore: () => showCommonSongActions(context,
                              song: song, playlist: displayedSongs),
                          draggable: true,
                          dragHandle: ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.55),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ────────────────────────── الفنانون ──────────────────────────
class _ArtistsTab extends StatefulWidget {
  final Map<String, List<AudioTrack>> grouped;
  const _ArtistsTab({required this.grouped});

  @override
  State<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends State<_ArtistsTab> {
  Future<void> _showArtistActions(
    BuildContext context,
    String artist,
    List<AudioTrack> tracks,
  ) async {
    final svc = MediaService.instance;
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _tinted(sheetContext, Icons.play_arrow_rounded),
                title: Text('تشغيل أغاني $artist'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await svc.playQueue(tracks);
                },
              ),
              ListTile(
                leading: _tinted(sheetContext, Icons.shuffle_rounded),
                title: const Text('تشغيل عشوائي'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final shuffled = [...tracks]..shuffle();
                  await svc.playQueue(shuffled);
                },
              ),
              ListTile(
                leading: _tinted(sheetContext, Icons.queue_music_rounded),
                title: const Text('إضافة كل الأغاني إلى قائمة تشغيل'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final names = await PlaylistStorage.loadPlaylistNames();
                  if (!context.mounted) return;
                  final name = await showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: theme.colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (c) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (names.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                  'لا توجد قوائم. أنشئ واحدة من تبويبة Playlists.'),
                            )
                          else
                            ...names.map(
                              (n) => ListTile(
                                leading: const Icon(Icons.playlist_add),
                                title: Text(n),
                                onTap: () => Navigator.of(c).pop(n),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (name != null && name.isNotEmpty) {
                    for (final t in tracks) {
                      await PlaylistStorage.addTrackToPlaylist(name, t.id);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تمت إضافة ${tracks.length} أغنية إلى "$name"',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.grouped.isEmpty) {
      return const EmptyState(
        icon: Icons.person_outline_rounded,
        title: 'لا فنانين بعد',
        subtitle: 'أضف ملفات موسيقى ليتم تصنيفها حسب الفنان',
      );
    }

    final entries = widget.grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 60),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final firstArt = e.value.isNotEmpty ? e.value.first.albumArtUri : null;
        final isPlayingArtist = MediaService.instance.snapshot.playing &&
            e.value.any(
                (t) => t.id == MediaService.instance.snapshot.currentTrackId);
        return GlassListCard(
          title: e.key.trim().isEmpty ? 'Unknown Artist' : e.key,
          subtitle: 'فنان',
          extraInfo: '${e.value.length} أغنية',
          artUri: firstArt,
          iconFallback: Icons.person_rounded,
          fallbackTrack: e.value.isNotEmpty ? e.value.first : null,
          isPlaying: isPlayingArtist,
          onTap: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ArtistDetailScreen(
                artist: e.key,
                tracks: e.value,
              ),
            ));
          },
          onPlay: e.value.isEmpty
              ? null
              : () => MediaService.instance.playQueue(e.value),
          onMore: () => _showArtistActions(context, e.key, e.value),
        );
      },
    );
  }
}

// ────────────────────────── Artist Detail Screen (متاحة للملاحة) ──────────────────────────
class ArtistDetailScreen extends StatefulWidget {
  final String artist;
  final List<AudioTrack> tracks;
  const ArtistDetailScreen(
      {super.key, required this.artist, required this.tracks});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  late List<AudioTrack> _displayedSongs;

  @override
  void initState() {
    super.initState();
    _displayedSongs = List<AudioTrack>.from(widget.tracks);
  }

  void _playSong(AudioTrack song) {
    final index = _displayedSongs.indexWhere((t) => t.id == song.id);
    final startIndex = index >= 0 ? index : 0;
    MediaService.instance.playQueue(_displayedSongs, startIndex: startIndex);
  }

  void _playAll() {
    if (_displayedSongs.isEmpty) return;
    _playSong(_displayedSongs.first);
  }

  void _shufflePlay() {
    if (_displayedSongs.isEmpty) return;
    final randomSong =
        _displayedSongs[math.Random().nextInt(_displayedSongs.length)];
    _playSong(randomSong);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _displayedSongs.removeAt(oldIndex);
      _displayedSongs.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = MediaService.instance;
    final snap = svc.snapshot;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isColorful =
        SonvaThemeService.instance.mode == SonvaThemeMode.colorful;
    final firstArt =
        _displayedSongs.isNotEmpty ? _displayedSongs.first.albumArtUri : null;

    return Scaffold(
      backgroundColor: isDark
          ? Colors.black.withOpacity(0.35)
          : Colors.grey.withOpacity(0.55),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
            widget.artist.trim().isEmpty ? 'Unknown Artist' : widget.artist),
        backgroundColor: isColorful
            ? Colors.transparent
            : (isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.white.withOpacity(0.55)),
        elevation: 0,
      ),
      body: _ThemedBackground(
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 16),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          theme.primaryColor.withOpacity(0.05),
                          Colors.transparent
                        ]
                      : [
                          theme.primaryColor.withOpacity(0.45),
                          theme.primaryColor.withOpacity(0.15),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: _displayedSongs.isNotEmpty
                        ? AlbumArt(
                            uri: firstArt,
                            size: 140,
                            radius: 16,
                            lazyFetchUri: () => MediaService.instance
                                .fetchAlbumArtUriForTrack(
                                    _displayedSongs.first),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 70,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.artist.trim().isEmpty
                        ? 'Unknown Artist'
                        : widget.artist,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_displayedSongs.length} أغنية',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play All'),
                            onPressed:
                                _displayedSongs.isEmpty ? null : _playAll,
                            style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.shuffle_rounded),
                            label: const Text('Shuffle'),
                            onPressed:
                                _displayedSongs.isEmpty ? null : _shufflePlay,
                            style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _displayedSongs.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد أغاني متاحة',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 80),
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      onReorder: _onReorder,
                      itemCount: _displayedSongs.length,
                      itemBuilder: (_, index) {
                        final song = _displayedSongs[index];
                        final isPlaying =
                            snap.playing && snap.currentTrackId == song.id;
                        return GlassSongCard(
                          key: ValueKey('ar-${song.id}'),
                          song: song,
                          isPlaying: isPlaying,
                          onTap: () => _playSong(song),
                          onMore: () => showCommonSongActions(context,
                              song: song, playlist: _displayedSongs),
                          draggable: true,
                          dragHandle: ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.55),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
