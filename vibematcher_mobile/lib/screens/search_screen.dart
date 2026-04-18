import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/song_model.dart';
import '../providers/music_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Song> _results = [];
  bool _isSearching = false;

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    
    setState(() => _isSearching = true);
    try {
      final songs = await ApiService.searchOnline(query);
      setState(() => _results = songs);
    } catch (e) {
      debugPrint("Search failed: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildSearchBar(),
            ),
            Expanded(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: "Search songs, artists...",
          hintStyle: TextStyle(color: AppColors.textSecondary),
          icon: Icon(FontAwesomeIcons.magnifyingGlass, color: AppColors.textSecondary, size: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_results.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text("No results found.", style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final song = _results[index];
        return _SearchRow(song: song, results: _results);
      },
    );
  }
}

class _SearchRow extends StatelessWidget {
  final Song song;
  final List<Song> results;
  const _SearchRow({required this.song, required this.results});

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context, listen: false);
    
    return InkWell(
      onTap: () => music.playSong(song, newQueue: results),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: song.cover,
                width: 45,
                height: 45,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(song.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(FontAwesomeIcons.ellipsisVertical, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
