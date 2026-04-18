import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _username;
  String? _displayName;
  String? _avatar;
  String? _header;
  String? _themeColor;
  double _volume = 1.0;
  bool _isLoading = false;

  String? get token => _token;
  String? get username => _username;
  String? get displayName => _displayName;
  String? get avatar => _avatar ?? AppConstants.defaultAvatar;
  String? get header => _header ?? AppConstants.defaultHeader;
  String? get themeColor => _themeColor;
  double get volume => _volume;
  bool get isLoading => _isLoading;

  bool get isAuthenticated => _token != null;

  Map<String, dynamic> get userDataMap => {
    'display_name': _displayName,
    'bio': '', // Default bio if not provided by backend initially
    'avatar': _avatar,
    'header': _header,
    'theme_color': _themeColor,
  };

  AuthProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _username = prefs.getString('user');
    _displayName = prefs.getString('display_name');
    _avatar = prefs.getString('avatar');
    _header = prefs.getString('header');
    _themeColor = prefs.getString('theme_color');
    _volume = prefs.getDouble('volume_$_username') ?? 1.0;
    notifyListeners();
  }

  Future<void> login(String u, String p) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.login(u, p);
      _token = data['access_token'];
      _username = data['username'];
      _displayName = data['display_name'];
      _avatar = data['avatar'];
      _header = data['header'];
      _themeColor = data['theme_color'];
      _volume = (data['volume'] as num?)?.toDouble() ?? 1.0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('user', _username!);
      await prefs.setString('display_name', _displayName ?? _username!);
      if (_avatar != null) await prefs.setString('avatar', _avatar!);
      if (_header != null) await prefs.setString('header', _header!);
      if (_themeColor != null) await prefs.setString('theme_color', _themeColor!);
      await prefs.setDouble('volume_$_username', _volume);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _token = null;
    _username = null;
    notifyListeners();
  }
}
