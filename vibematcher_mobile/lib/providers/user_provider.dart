import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

class UserProvider with ChangeNotifier {
  List<Song> _recentlyPlayed = [];
  String? _displayName;
  String? _bio;
  String? _avatar;
  String? _header;
  String? _themeColor;

  Color get accentColor {
    if (_themeColor == null) return const Color(0xFF29CC70);
    try {
      final hex = _themeColor!.replaceAll("#", "");
      return Color(int.parse("FF$hex", radix: 16));
    } catch (e) {
      return const Color(0xFF29CC70);
    }
  }

  List<Song> get recentlyPlayed => _recentlyPlayed;
  String? get displayName => _displayName;
  String? get bio => _bio;
  String? get avatar => _avatar;
  String? get header => _header;
  String? get themeColor => _themeColor;

  UserProvider() {
    _loadRecents();
  }

  void setUserData(Map<String, dynamic> data) {
    _displayName = data['display_name'];
    _bio = data['bio'];
    _avatar = data['avatar'];
    _header = data['header'];
    _themeColor = data['theme_color'];
    notifyListeners();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recentsJson = prefs.getString('recents');
    if (recentsJson != null) {
      final List<dynamic> decoded = jsonDecode(recentsJson);
      _recentlyPlayed = decoded.map((item) => Song.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<void> addToRecents(Song song) async {
    // Remove if already exists to move it to front
    _recentlyPlayed.removeWhere((s) => s.videoId == song.videoId);
    _recentlyPlayed.insert(0, song);
    
    // Limit to 20 items
    if (_recentlyPlayed.length > 20) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 20);
    }
    
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_recentlyPlayed.map((s) => s.toJson()).toList());
    await prefs.setString('recents', encoded);
  }

  void clearRecents() async {
    _recentlyPlayed = [];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recents');
  }
}
