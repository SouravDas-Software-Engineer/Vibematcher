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

class LikedSongsScreen extends StatelessWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final music = Provider.of<MusicProvider>(context);
    final user = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: FutureBuilder<List<Playlist>>(
          future: ApiService.getPlaylists(auth.username ?? ""),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final playlists = snapshot.data!;
            final likedPlaylist = playlists.firstWhere(
              (p) => p.name.toLowerCase() == "liked songs",
              orElse: () => Playlist(id: "fake", name: "Liked Songs", username: "user", songs: [], createdAt: DateTime.now()),
            );

            return CustomScrollView(
              slivers: [
                _buildSliverHeader(likedPlaylist),
                if (likedPlaylist.songs.isEmpty)
                  _buildEmptyState()
                else
                  _buildSongsList(likedPlaylist.songs, music, user),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverHeader(Playlist playlist) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.3), blurRadius: 40)],
              ),
              child: const Icon(FontAwesomeIcons.solidHeart, color: Colors.white, size: 80),
            ),
            const SizedBox(height: 32),
            const Text("Liked Songs", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            Text("${playlist.songs.length} Tracks", style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SliverFillRemaining(
      child: Center(
        child: Text("No liked songs yet.", style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildSongsList(List<Song> songs, MusicProvider music, UserProvider user) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = songs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => music.playSong(song, newQueue: songs, onPlay: user.addToRecents),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                tileColor: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: song.cover, width: 48, height: 48, fit: BoxFit.cover),
                ),
                title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text(song.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                trailing: const Icon(FontAwesomeIcons.solidHeart, color: AppColors.accent, size: 16),
              ),
            );
          },
          childCount: songs.length,
        ),
      ),
    );
  }
}
