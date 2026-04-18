import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/music_provider.dart';
import '../providers/user_provider.dart';
import '../core/constants.dart';
import 'queue_sheet.dart';

class FullPlayer extends StatelessWidget {
  const FullPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final music = Provider.of<MusicProvider>(context);
    final user = Provider.of<UserProvider>(context);
    final song = music.currentSong;
    final accent = user.accentColor;

    if (song == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black87,
              AppColors.bgMain,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildHeader(context),
                const Spacer(),
                _buildAlbumArt(song.cover, accent),
                const Spacer(),
                _buildSongInfo(song),
                const SizedBox(height: 32),
                _buildProgressBar(music, accent),
                const SizedBox(height: 32),
                _buildControls(music, accent),
                const SizedBox(height: 32),
                _buildVolumeSlider(music, accent),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.expand_more, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        const Text("NOW PLAYING", style: TextStyle(letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        IconButton(
          icon: const Icon(Icons.list, size: 28), 
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const QueueSheet(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlbumArt(String url, Color accent) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 320,
          height: 320,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.white10),
          errorWidget: (context, url, error) => Container(
            color: Colors.white10,
            child: const Icon(Icons.music_note, size: 80, color: Colors.white24),
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(dynamic song) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(song.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(song.artist, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(FontAwesomeIcons.heart, color: Colors.white, size: 22),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(FontAwesomeIcons.folderPlus, color: Colors.white, size: 20),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildProgressBar(MusicProvider music, Color accent) {
    return StreamBuilder<Duration>(
      stream: music.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: music.durationStream,
          builder: (context, dSnapshot) {
            final dur = dSnapshot.data ?? Duration.zero;
            return ProgressBar(
              progress: pos,
              total: dur,
              onSeek: music.seek,
              barHeight: 5,
              baseBarColor: Colors.white10,
              progressBarColor: accent,
              thumbColor: Colors.white,
              thumbRadius: 8,
              timeLabelTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            );
          },
        );
      },
    );
  }

  Widget _buildControls(MusicProvider music, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(FontAwesomeIcons.shuffle, size: 18, color: music.isShuffle ? accent : Colors.white),
          onPressed: music.toggleShuffle,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 42),
          onPressed: music.prev,
        ),
        _buildPlayPauseButton(music),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 42),
          onPressed: music.next,
        ),
        _buildRepeatButton(music, accent),
      ],
    );
  }

  Widget _buildPlayPauseButton(MusicProvider music) {
    return StreamBuilder(
      stream: music.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return GestureDetector(
          onTap: music.togglePlay,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
              size: 40,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRepeatButton(MusicProvider music, Color accent) {
    IconData icon;
    Color color;
    switch (music.loopMode) {
      case LoopMode.all:
        icon = FontAwesomeIcons.repeat;
        color = accent;
        break;
      case LoopMode.one:
        icon = Icons.repeat_one;
        color = accent;
        break;
      default:
        icon = FontAwesomeIcons.repeat;
        color = Colors.white;
    }
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      onPressed: music.cycleRepeat,
    );
  }

  Widget _buildVolumeSlider(MusicProvider music, Color accent) {
    return Row(
      children: [
        const Icon(Icons.volume_down, size: 20, color: AppColors.textSecondary),
        Expanded(
          child: Slider(
            value: music.player.volume,
            onChanged: music.setVolume,
            activeColor: accent,
            inactiveColor: Colors.white10,
          ),
        ),
        const Icon(Icons.volume_up, size: 20, color: AppColors.textSecondary),
      ],
    );
  }
}
