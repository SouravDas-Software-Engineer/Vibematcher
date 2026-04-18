import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../providers/auth_provider.dart';
import '../providers/music_provider.dart';
import '../providers/user_provider.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  void _refresh() => setState(() {});

  Future<void> _showCreatePlaylistDialog() async {
    final TextEditingController controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgMain,
        title: const Text("Create Playlist"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Playlist Name", hintStyle: TextStyle(color: Colors.white24)),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final navigator = Navigator.of(context);
                await ApiService.createPlaylist(controller.text);
                if (!context.mounted) return;
                navigator.pop();
                _refresh();
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = Provider.of<UserProvider>(context);
    final music = Provider.of<MusicProvider>(context);
    
    final username = user.displayName ?? auth.username;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: user.accentColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, username ?? "User"),
                const SizedBox(height: 32),
                if (user.recentlyPlayed.isNotEmpty) ...[
                  _buildSectionTitle("RECENTLY PLAYED"),
                  const SizedBox(height: 16),
                  _buildRecentList(user.recentlyPlayed, music, user),
                  const SizedBox(height: 32),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle("YOUR PLAYLISTS"),
                    IconButton(
                      icon: Icon(Icons.add, size: 20, color: user.accentColor), 
                      onPressed: _showCreatePlaylistDialog
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (auth.username != null)
                  _buildPlaylistGrid(auth, music, user)
                else
                  const Center(child: Text("Please log in to see playlists.")),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String username) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(FontAwesomeIcons.magnifyingGlass, size: 20),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
            ),
            IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
          ],
        ),
        const SizedBox(height: 16),
        Text("${_getGreeting()},", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
        Text(username, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textSecondary,
        letterSpacing: 2,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRecentList(List<Song> songs, MusicProvider music, UserProvider user) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: songs.length,
        itemBuilder: (context, index) => _SongCard(
          song: songs[index],
          onTap: () => music.playSong(songs[index], newQueue: songs, onPlay: user.addToRecents),
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid(AuthProvider auth, MusicProvider music, UserProvider user) {
    return FutureBuilder<List<Playlist>>(
      future: ApiService.getPlaylists(auth.username!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error loading playlists: ${snapshot.error}"));
        }
        
        final playlists = snapshot.data ?? [];
        if (playlists.isEmpty) return const Text("No playlists found.");

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) => _PlaylistCard(
            playlist: playlists[index],
            onDelete: () async {
              final ok = await ApiService.deletePlaylist(playlists[index].id);
              if (ok) _refresh();
            },
          ),
        );
      },
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: song.cover,
                fit: BoxFit.cover,
                height: 136,
                width: 136,
                placeholder: (context, url) => Container(color: Colors.white10),
                errorWidget: (context, url, error) => Container(
                  color: Colors.white10,
                  child: const Icon(Icons.music_note, color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(song.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onDelete;
  const _PlaylistCard({required this.playlist, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: playlist.songs.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: playlist.songs.first.cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(color: Colors.white10),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white10,
                          child: const Icon(Icons.playlist_play, color: Colors.white24),
                        ),
                      )
                    : Container(color: Colors.white10),
                ),
              ),
              const SizedBox(height: 12),
              Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text("${playlist.songs.length} Tracks", style: TextStyle(color: user.accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline, size: 16, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
