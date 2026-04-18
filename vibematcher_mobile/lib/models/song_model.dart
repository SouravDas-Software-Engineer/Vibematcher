class Song {
  final String title;
  final String artist;
  String filename;
  String cover;
  final String source;
  String videoId;

  Song({
    required this.title,
    required this.artist,
    required this.filename,
    required this.cover,
    required this.source,
    required this.videoId,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      filename: json['filename'] ?? '',
      cover: json['cover'] ?? '',
      source: json['source'] ?? 'saavn',
      videoId: json['videoId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'filename': filename,
      'cover': cover,
      'source': source,
      'videoId': videoId,
    };
  }

  // Helper for deep copy and manual mutation
  Song copyWith({String? filename, String? cover, String? videoId}) {
    return Song(
      title: title,
      artist: artist,
      filename: filename ?? this.filename,
      cover: cover ?? this.cover,
      source: source,
      videoId: videoId ?? this.videoId,
    );
  }
}
