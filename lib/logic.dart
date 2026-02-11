// logic.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final String? coverLocalPath;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.coverLocalPath,
  });
}

class AppSettings {
  final ThemeMode themeMode;
  final String appTitle;

  const AppSettings({
    required this.themeMode,
    required this.appTitle,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? appTitle,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      appTitle: appTitle ?? this.appTitle,
    );
  }
}

class AppLogic extends ChangeNotifier {
  static const _kPrefTheme = 'settings.themeMode';
  static const _kPrefTitle = 'settings.appTitle';

  late SharedPreferences _prefs;

  AppSettings settings = const AppSettings(
    themeMode: ThemeMode.dark,
    appTitle: 'Local Player',
  );

  final List<Track> library = [];
  final Set<String> favorites = {};
  final Map<String, List<String>> playlists = {
    'Demo Playlist': [],
  };

  String? _currentTrackId;
  bool isPlaying = false;

  bool loopOne = false;
  bool continuousPlay = true;

  Duration position = Duration.zero;

  final _positionCtrl = StreamController<Duration>.broadcast();
  Timer? _tick;

  Stream<Duration> get positionStream => _positionCtrl.stream;

  Track? get currentTrack {
    if (_currentTrackId == null) return null;
    final idx = library.indexWhere((t) => t.id == _currentTrackId);
    if (idx < 0) return library.isEmpty ? null : library.first;
    return library[idx];
  }

  Duration get currentDuration =>
      currentTrack?.duration ?? const Duration(seconds: 1);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    _seedDemo();
    _ensureTick();
  }

  void _seedDemo() {
    if (library.isNotEmpty) return;

    library.addAll(const [
      Track(
          id: 't1',
          title: 'Orange Wave',
          artist: 'Local Demo',
          duration: Duration(minutes: 3, seconds: 42)),
      Track(
          id: 't2',
          title: 'Midnight Drive',
          artist: 'Local Demo',
          duration: Duration(minutes: 4, seconds: 8)),
      Track(
          id: 't3',
          title: 'Bass & Blur',
          artist: 'Local Demo',
          duration: Duration(minutes: 2, seconds: 55)),
    ]);

    playlists['Demo Playlist'] = library.map((e) => e.id).toList();

    _currentTrackId = library.first.id;
    position = Duration.zero;
    notifyListeners();
  }

  void _loadSettings() {
    final themeStr = _prefs.getString(_kPrefTheme) ?? 'dark';
    final titleStr = _prefs.getString(_kPrefTitle) ?? 'Local Player';

    settings = AppSettings(
      themeMode: switch (themeStr) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      appTitle: titleStr,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    settings = settings.copyWith(themeMode: mode);
    await _prefs.setString(
      _kPrefTheme,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        _ => 'dark'
      },
    );
    notifyListeners();
  }

  Future<void> setAppTitle(String title) async {
    final t = title.trim().isEmpty ? 'Local Player' : title.trim();
    settings = settings.copyWith(appTitle: t);
    await _prefs.setString(_kPrefTitle, settings.appTitle);
    notifyListeners();
  }

  void playPause() {
    isPlaying = !isPlaying;
    _ensureTick();
    notifyListeners();
  }

  void toggleLoopOne() {
    loopOne = !loopOne;
    notifyListeners();
  }

  void toggleContinuous() {
    continuousPlay = !continuousPlay;
    notifyListeners();
  }

  void setCurrent(String trackId) {
    _currentTrackId = trackId;
    position = Duration.zero;
    notifyListeners();
  }

  void next() {
    if (library.isEmpty) return;
    final idx = library.indexWhere((t) => t.id == _currentTrackId);
    final nextIdx = (idx < 0) ? 0 : (idx + 1) % library.length;
    _currentTrackId = library[nextIdx].id;
    position = Duration.zero;
    notifyListeners();
  }

  void previous() {
    if (library.isEmpty) return;
    final idx = library.indexWhere((t) => t.id == _currentTrackId);
    final prevIdx = (idx <= 0) ? library.length - 1 : idx - 1;
    _currentTrackId = library[prevIdx].id;
    position = Duration.zero;
    notifyListeners();
  }

  void seek(Duration to) {
    final d = currentDuration;
    if (to < Duration.zero) to = Duration.zero;
    if (to > d) to = d;
    position = to;
    _positionCtrl.add(position);
    notifyListeners();
  }

  void toggleFavorite(String trackId) {
    if (favorites.contains(trackId)) {
      favorites.remove(trackId);
    } else {
      favorites.add(trackId);
    }
    notifyListeners();
  }

  void _ensureTick() {
    _tick ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!isPlaying) {
        _positionCtrl.add(position);
        return;
      }

      final d = currentDuration;
      position += const Duration(milliseconds: 100);

      if (position >= d) {
        if (loopOne) {
          position = Duration.zero;
        } else if (continuousPlay) {
          next();
        } else {
          position = d;
          isPlaying = false;
        }
      }

      _positionCtrl.add(position);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _positionCtrl.close();
    super.dispose();
  }
}
