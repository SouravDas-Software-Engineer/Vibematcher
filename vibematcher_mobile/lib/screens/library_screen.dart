import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/playlist_model.dart';
import '../providers/auth_provider.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Your Library", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: Icon(FontAwesomeIcons.circlePlus, color: AppColors.textSecondary),
                    onPressed: () {}, // Implementation for create playlist modal
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text("PLAYLISTS", style: TextStyle(color: AppColors.textSecondary, letterSpacing: 1.5, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Playlist>>(
                  future: ApiService.getPlaylists(auth.username ?? ""),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                    final playlists = snapshot.data!;
                    if (playlists.isEmpty) return const Center(child: Text("No playlists yet.", style: TextStyle(color: AppColors.textSecondary)));

                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) => _PlaylistCard(playlist: playlists[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to playlist details
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: playlist.songs.isNotEmpty
                  ? CachedNetworkImage(imageUrl: playlist.songs.first.cover, fit: BoxFit.cover)
                  : Container(color: Colors.white10, child: Icon(FontAwesomeIcons.music, color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 12),
            Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text("${playlist.songs.length} Tracks", style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
