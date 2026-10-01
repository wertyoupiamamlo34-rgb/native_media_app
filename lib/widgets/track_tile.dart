import 'package:flutter/material.dart';

import '../models/audio_track.dart';
import '../services/media_service.dart';
import '../utils/formatters.dart';
import 'album_art.dart';

/// عنصر قائمة لمسار صوتي.
class TrackTile extends StatelessWidget {
  final AudioTrack track;
  final VoidCallback onTap;
  final bool isPlaying;
  final bool showFavorite;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final int? leadingNumber; // لعرض ترتيب في الشائعة

  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.isPlaying = false,
    this.showFavorite = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.leadingNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (leadingNumber != null) ...[
              SizedBox(
                width: 28,
                child: Text(
                  '$leadingNumber',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: leadingNumber! <= 3
                        ? theme.colorScheme.primary
                        : Colors.white54,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            AlbumArt(
              uri: track.albumArtUri,
              lazyFetchUri: () =>
                  MediaService.instance.fetchAlbumArtUriForTrack(track),
              size: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isPlaying ? theme.colorScheme.primary : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatDuration(track.duration),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (showFavorite)
              IconButton(
                onPressed: onFavoriteToggle,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color:
                      isFavorite ? theme.colorScheme.secondary : Colors.white54,
                ),
                splashRadius: 22,
              ),
          ],
        ),
      ),
    );
  }
}

/// عرض حالة فارغة لطيف.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                )),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38)),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// إجراء سريع لتشغيل مسار يستخدمه السكرين.
Future<void> playTrackFromList({
  required List<AudioTrack> source,
  required int index,
}) async {
  if (index < 0 || index >= source.length) return;
  await MediaService.instance.playQueue(source, startIndex: index);
}
