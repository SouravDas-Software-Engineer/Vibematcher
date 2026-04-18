import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AppColors {
  static const Color bgMain = Color(0xFF09090B);
  static const Color glassBg = Color(0xA618181B); // rgba(24, 24, 27, 0.65)
  static const Color glassBorder = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color accent = Color(0xFF29CC70);
  static const Color accentGlow = Color(0x6629CC70);

  // Animated Orbs
  static const Color orb1 = Color(0xFF4F46E5);
  static const Color orb2 = Color(0xFFDB2777);
  static const Color orb3 = Color(0xFF2DD4BF);
}

class AppConstants {
  // Automatically switches between Localhost and Render
  static String get apiBaseUrl {
    if (kDebugMode) {
      // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for Desktop/Web
      if (defaultTargetPlatform == TargetPlatform.android) {
        return "http://10.0.2.2:8000";
      }
      return "http://127.0.0.1:8000";
    }
    return "https://vibematcher.onrender.com";
  }
  
  static const String defaultAvatar = "https://ui-avatars.com/api/?name=User&background=29CC70&color=fff";
  static const String defaultHeader = "https://images.unsplash.com/photo-1614149162883-504ce4d13909?q=80&w=1000&auto=format&fit=crop";
}
