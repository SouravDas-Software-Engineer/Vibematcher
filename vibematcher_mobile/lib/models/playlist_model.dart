import 'song_model.dart';

class Playlist {
  final String id;
  final String name;
  final String username;
  final List<Song> songs;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.username,
    required this.songs,
    required this.createdAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Playlist',
      username: json['username'] ?? '',
      songs: (json['songs'] as List? ?? [])
          .map((s) => Song.fromJson(s))
          .toList(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
}
