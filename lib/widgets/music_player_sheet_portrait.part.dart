// ignore_for_file: deprecated_member_use

part of 'music_player_sheet.dart';

// واجهة المشغل في الوضع العمودي.
class _PortraitPlayer extends StatelessWidget {
  final AudioTrack track;
  final int positionMs;
  final int durationMs;
  final bool playing;
  final bool isFavorite;
  final int repeatMode;
  final bool shuffleMode;
  final double progressValue;
  final String Function(int ms) formatDuration;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekEnd;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onShuffle;
  final Future<void> Function() onRepeat;
  final Future<void> Function() onFavorite;
  final Future<void> Function() onShare;
  final Future<void> Function() onQueue;
  final Future<void> Function() onSearch;
  final Future<void> Function() onOpenLyrics;
  final Future<void> Function() onOpenQueuePage;
  final Future<void> Function() onOpenEqualizerPage;
  final Future<void> Function() onOpenCutterPage;
  final Widget lyricsPreview;

  const _PortraitPlayer({
    required this.track,
    required this.positionMs,
    required this.durationMs,
    required this.playing,
    required this.isFavorite,
    required this.repeatMode,
    required this.shuffleMode,
    required this.progressValue,
    required this.formatDuration,
    required this.onSeekStart,
    required this.onSeekEnd,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
    required this.onFavorite,
    required this.onShare,
    required this.onQueue,
    required this.onSearch,
    required this.onOpenLyrics,
    required this.onOpenQueuePage,
    required this.onOpenEqualizerPage,
    required this.onOpenCutterPage,
    required this.lyricsPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon:
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite ? const Color(0xFFE65E69) : Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.playlist_add,
                  color: Colors.white70,
                ),
                tooltip: 'إضافة للقائمة',
                onPressed: () => _showAddToPlaylistDialog(
                  context,
                  track,
                ),
              ),
            ],
          ),
          AlbumArt(
            uri: track.albumArtUri,
            size: 280,
            radius: 20,
            lazyFetchUri: () =>
                MediaService.instance.fetchAlbumArtUriForTrack(track),
          ),
          const SizedBox(height: 17),
          Text(
            track.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            track.displayArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(formatDuration(positionMs),
                  style: const TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: progressValue,
                  min: 0,
                  max: 1,
                  onChanged: onSeekStart,
                  onChangeEnd: onSeekEnd,
                ),
              ),
              Text(formatDuration(durationMs),
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onOpenLyrics,
            child: Container(
              height: 80, // 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: lyricsPreview,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onShuffle,
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: shuffleMode
                      ? Theme.of(context).primaryColor
                      : Colors.white70,
                ),
              ),
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous_rounded,
                    color: Colors.white, size: 34),
              ),
              InkWell(
                onTap: onPlayPause,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 34,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.skip_next_rounded,
                    color: Colors.white, size: 34),
              ),
              IconButton(
                onPressed: onRepeat,
                icon: Icon(
                  repeatMode == 0
                      ? Icons.repeat_rounded
                      : repeatMode == 1
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                  color: repeatMode == 0
                      ? Colors.white70
                      : Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: onOpenQueuePage,
                icon: const Icon(
                  Icons.format_list_bulleted,
                  color: Colors.white70,
                ),
              ),
              IconButton(
                onPressed: onOpenEqualizerPage,
                icon: const Icon(
                  Icons.equalizer_rounded,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: onOpenCutterPage,
                icon: const Icon(Icons.content_cut, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showAddToPlaylistDialog(BuildContext context, AudioTrack track) {
  Future<void> addTrackToPlaylist(String name) async {
    await PlaylistStorage.addTrackToPlaylist(name, track.id);
  }

  Future<void> showCreatePlaylistDialog() async {
    final TextEditingController nameController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (createDialogContext) {
        return AlertDialog(
          title: const Text('إنشاء قائمة تشغيل'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'اسم قائمة التشغيل'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(createDialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                await PlaylistStorage.createPlaylist(name);

                await addTrackToPlaylist(name);

                if (!context.mounted) return;
                Navigator.of(createDialogContext).pop();
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('تم إنشاء القائمة وإضافة الأغنية إلى "$name"'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('إنشاء'),
            ),
          ],
        );
      },
    );
  }

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          final prefs = snapshot.data;
          final customPlaylists = prefs == null
              ? const <String>[]
              : prefs.getStringList(PlaylistStorage.customPlaylistsKey) ??
                  const <String>[];
          final playlists = <String>[
            'المشغلة مؤخرًا',
            'المفضلة',
            ...customPlaylists,
          ];

          return AlertDialog(
            title: const Text('إضافة إلى قائمة تشغيل'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else if (playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'لا توجد قوائم تشغيل.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final name = playlists[index];
                          final isRecentSmart = name == 'المشغلة مؤخرًا';
                          final isFavoriteSmart = name == 'المفضلة';

                          int songsCount;
                          if (isRecentSmart) {
                            songsCount =
                                MediaService.instance.popularTracks.length;
                          } else if (isFavoriteSmart) {
                            songsCount =
                                MediaService.instance.favoriteTracks.length;
                          } else {
                            final key = PlaylistStorage.playlistTracksKey(name);
                            songsCount = prefs?.getStringList(key)?.length ?? 0;
                          }

                          return ListTile(
                            leading: const Icon(Icons.queue_music),
                            title: Text(name),
                            subtitle: Text('$songsCount عنصر'),
                            onTap: () async {
                              if (isRecentSmart) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('هذه قائمة ذكية وتُحدّث تلقائيًا'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              if (isFavoriteSmart) {
                                if (!MediaService.instance
                                    .isFavorite(track.id)) {
                                  await MediaService.instance
                                      .toggleFavoriteById(
                                    track.id,
                                  );
                                }
                              } else {
                                await addTrackToPlaylist(name);
                              }

                              if (!context.mounted) return;
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تمت إضافة العنصر إلى "$name"'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('إنشاء قائمة تشغيل جديدة'),
                      onPressed: () => showCreatePlaylistDialog(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
            ],
          );
        },
      );
    },
  );
}
