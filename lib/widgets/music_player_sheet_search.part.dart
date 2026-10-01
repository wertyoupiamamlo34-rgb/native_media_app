part of 'music_player_sheet.dart';

// واجهة بحث الأغاني لاختيار عنصر وتشغيله.
class _TrackSearchDelegate extends SearchDelegate<AudioTrack?> {
  final List<AudioTrack> tracks;

  _TrackSearchDelegate(this.tracks);

  List<AudioTrack> _filteredTracks(String input) {
    final q = input.trim().toLowerCase();
    if (q.isEmpty) return tracks;
    return tracks.where((track) {
      return track.displayTitle.toLowerCase().contains(q) ||
          track.displayArtist.toLowerCase().contains(q) ||
          track.album.toLowerCase().contains(q);
    }).toList();
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = _filteredTracks(query);
    if (results.isEmpty) {
      return const Center(
        child: Text('No results', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final track = results[index];
        return ListTile(
          title: Text(track.displayTitle),
          subtitle: Text(track.displayArtist),
          onTap: () => close(context, track),
        );
      },
    );
  }
}
