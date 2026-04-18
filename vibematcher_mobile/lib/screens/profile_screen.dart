import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../core/api_service.dart';
import '../core/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _showEditProfileDialog(UserProvider user) async {
    final nameController = TextEditingController(text: user.displayName);
    final bioController = TextEditingController(text: user.bio);
    final themeController = TextEditingController(text: user.themeColor ?? "#29CC70");

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgMain,
        title: const Text("Customize Vibe"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEditField(nameController, "Display Name"),
              const SizedBox(height: 16),
              _buildEditField(bioController, "Bio", lines: 3),
              const SizedBox(height: 16),
              _buildEditField(themeController, "Theme Color (Hex)"),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final ok = await ApiService.updateProfile({
                'display_name': nameController.text,
                'bio': bioController.text,
                'theme_color': themeController.text,
              });
              if (ok && context.mounted) {
                user.setUserData({
                  'display_name': nameController.text,
                  'bio': bioController.text,
                  'theme_color': themeController.text,
                  'avatar': user.avatar,
                  'header': user.header,
                });
                navigator.pop();
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, {int lines = 1}) {
    return TextField(
      controller: controller,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(auth, user),
            const SizedBox(height: 16),
            _buildUserInfo(auth, user),
            const SizedBox(height: 24),
            _buildStats(auth, user),
            const SizedBox(height: 24),
            _buildTabSection(),
            const SizedBox(height: 16),
            _buildActions(),
            const SizedBox(height: 100), 
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth, UserProvider user) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        CachedNetworkImage(
          imageUrl: user.header ?? AppConstants.defaultHeader,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.white10),
          errorWidget: (context, url, error) => Container(
            color: Colors.white10,
            child: const Icon(Icons.broken_image, color: Colors.white24),
          ),
        ),
        Container(height: 200, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.black87]))),
        Positioned(
          bottom: -50,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.bgMain, shape: BoxShape.circle),
            child: CachedNetworkImage(
              imageUrl: user.avatar ?? AppConstants.defaultAvatar,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.person),
              imageBuilder: (context, imageProvider) => CircleAvatar(
                radius: 54,
                backgroundImage: imageProvider,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          right: 20,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: user.accentColor, width: 1.5)),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text("Customize Vibe", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _showEditProfileDialog(user),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo(AuthProvider auth, UserProvider user) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Text(user.displayName ?? auth.username ?? "Anonymous", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(user.bio!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: user.accentColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text("Music Lover", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildStats(AuthProvider auth, UserProvider user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem("0", "PLAYLISTS"),
            Container(width: 1, height: 30, color: Colors.white10),
            _buildStatItem(user.recentlyPlayed.length.toString(), "HISTORY"),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildTabSection() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: "Playlists"),
            Tab(text: "History"),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.accent, width: 0.5)),
            ),
            onPressed: () {},
            child: const Text("+ New Playlist", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
