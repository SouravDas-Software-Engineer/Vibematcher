import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song_model.dart';
import '../core/api_service.dart';
import '../core/constants.dart';

class MusicProvider with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  
  // Reference items for repair
  bool _isRepairing = false;

  AudioPlayer get player => _player;
  List<Song> get queue => _queue;
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  bool get isRepairing => _isRepairing;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  MusicProvider() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      notifyListeners();
    });
  }

  Future<void> playSong(Song song, {List<Song>? newQueue, Function(Song)? onPlay}) async {
    if (newQueue != null) {
      _queue = List.from(newQueue);
      if (_isShuffle) _queue.shuffle();
    }
    
    _currentIndex = _queue.indexWhere((s) => s.videoId == song.videoId);
    if (_currentIndex == -1) {
      _queue.insert(0, song);
      _currentIndex = 0;
    }

    if (onPlay != null) onPlay(song);
    
    await _loadAndPlay(_queue[_currentIndex]);
  }

  Future<void> _loadAndPlay(Song song, {Function(Song)? onPlay}) async {
    try {
      String url = song.filename;
      if (url.startsWith('/')) {
        url = "${AppConstants.apiBaseUrl}$url";
      }
      
      await _player.setUrl(url);
      _player.play();
      if (onPlay != null) onPlay(song);
      notifyListeners();
    } catch (e) {
      debugPrint("Playback error, attempting repair: $e");
      _repairAndPlay(song, onPlay: onPlay);
    }
  }

  Future<void> _repairAndPlay(Song song, {Function(Song)? onPlay}) async {
    _isRepairing = true;
    notifyListeners();
    
    try {
      final results = await ApiService.searchOnline("${song.title} ${song.artist}");
      if (results.isNotEmpty) {
        final mirror = results.first;
        _queue[_currentIndex] = mirror;
        await _loadAndPlay(mirror, onPlay: onPlay);
      }
    } catch (e) {
      debugPrint("Repair failed: $e");
    } finally {
      _isRepairing = false;
      notifyListeners();
    }
  }

  void togglePlay() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    notifyListeners();
  }

  void next() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _loadAndPlay(_queue[_currentIndex]);
    } else {
      // Auto-fill or repeat
      if (_loopMode == LoopMode.all) {
        _currentIndex = 0;
        _loadAndPlay(_queue[0]);
      }
    }
  }

  void prev() {
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      _loadAndPlay(_queue[_currentIndex]);
    }
  }

  void seek(Duration pos) => _player.seek(pos);
  
  void setVolume(double vol) => _player.setVolume(vol);

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle) {
      final current = currentSong;
      _queue.shuffle();
      if (current != null) {
        _queue.removeWhere((s) => s.videoId == current.videoId);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
    }
    notifyListeners();
  }

  void cycleRepeat() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    _player.setLoopMode(_loopMode);
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
