import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import 'constants.dart';

class ApiService {
  static final String _baseUrl = AppConstants.apiBaseUrl;

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Authorization': 'Bearer ${token ?? ""}',
      'Content-Type': 'application/json',
    };
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Login failed');
  }

  static Future<List<Song>> searchOnline(String query) async {
    final res = await http.get(Uri.parse('$_baseUrl/search_online?q=${Uri.encodeComponent(query)}'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((item) => Song.fromJson(item)).toList();
    }
    return [];
  }

  static Future<List<Song>> getRecommendations({String? videoId, String? title, String? artist}) async {
    String url = '$_baseUrl/recommendations?';
    if (videoId != null) {
      url += 'video_id=$videoId';
    } else if (title != null) {
      url += 'title=${Uri.encodeComponent(title)}&artist=${Uri.encodeComponent(artist ?? '')}';
    }
    
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((item) => Song.fromJson(item)).toList();
    }
    return [];
  }

  // Playlists
  static Future<List<Playlist>> getPlaylists(String username) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/playlists/$username'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((item) => Playlist.fromJson(item)).toList();
    }
    return [];
  }

  static Future<bool> createPlaylist(String name) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/playlists/create'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    return res.statusCode == 200;
  }

  static Future<bool> deletePlaylist(String playlistId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/playlists/$playlistId'),
      headers: await _headers(),
    );
    return res.statusCode == 200;
  }

  static Future<bool> addSongToPlaylist(String playlistId, Song song) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/playlists/add_song'),
      headers: await _headers(),
      body: jsonEncode({'playlist_id': playlistId, 'song': song.toJson()}),
    );
    return res.statusCode == 200;
  }

  // Profile & Volume
  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/update_profile'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return res.statusCode == 200;
  }

  static Future<bool> updateVolume(double volume) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/update_volume'),
      headers: await _headers(),
      body: jsonEncode({'volume': volume}),
    );
    return res.statusCode == 200;
  }
}
