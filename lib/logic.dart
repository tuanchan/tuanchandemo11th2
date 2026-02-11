// logic.dart
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// ===============================
/// DB schema (single file, no hardcode)
/// ===============================
class TrackRow {
  final String id;
  final String title;
  final String artist;
  final String localPath; // path in app Documents (copied)
  final String signature; // for dedupe
  final String? coverPath; // path in app Documents/Images
  final int durationMs; // cached duration
  final int createdAt;

  TrackRow({
    required this.id,
    required this.title,
    required this.artist,
    required this.localPath,
    required this.signature,
    required this.coverPath,
    required this.durationMs,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'localPath': localPath,
        'signature': signature,
        'coverPath': coverPath,
        'durationMs': durationMs,
        'createdAt': createdAt,
      };

  static TrackRow fromMap(Map<String, Object?> m) => TrackRow(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        artist: (m['artist'] as String?) ?? '',
        localPath: m['localPath'] as String,
        signature: m['signature'] as String,
        coverPath: m['coverPath'] as String?,
        durationMs: (m['durationMs'] as int?) ?? 0,
        createdAt: (m['createdAt'] as int?) ?? 0,
      );
}

class PlaylistRow {
  final String id;
  final String name;
  final int createdAt;

  PlaylistRow({required this.id, required this.name, required this.createdAt});

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'createdAt': createdAt};

  static PlaylistRow fromMap(Map<String, Object?> m) => PlaylistRow(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        createdAt: (m['createdAt'] as int?) ?? 0,
      );
}

class PlaybackStateRow {
  final String? currentTrackId;
  final int positionMs;
  final bool isPlaying;
  final bool loopOne;
  final bool continuous;

  PlaybackStateRow({
    required this.currentTrackId,
    required this.positionMs,
    required this.isPlaying,
    required this.loopOne,
    required this.continuous,
  });

  Map<String, Object?> toMap() => {
        'k': 1,
        'currentTrackId': currentTrackId,
        'positionMs': positionMs,
        'isPlaying': isPlaying ? 1 : 0,
        'loopOne': loopOne ? 1 : 0,
        'continuous': continuous ? 1 : 0,
      };

  static PlaybackStateRow fromMap(Map<String, Object?> m) => PlaybackStateRow(
        currentTrackId: m['currentTrackId'] as String?,
        positionMs: (m['positionMs'] as int?) ?? 0,
        isPlaying: ((m['isPlaying'] as int?) ?? 0) == 1,
        loopOne: ((m['loopOne'] as int?) ?? 0) == 1,
        continuous: ((m['continuous'] as int?) ?? 1) == 1,
      );
}

/// ===============================
/// Settings
/// ===============================
class AppSettings {
  final ThemeMode themeMode;
  final String appTitle;

  const AppSettings({required this.themeMode, required this.appTitle});

  AppSettings copyWith({ThemeMode? themeMode, String? appTitle}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        appTitle: appTitle ?? this.appTitle,
      );
}

/// ===============================
/// AudioHandler (just_audio + audio_service)
/// ===============================
class PlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final void Function(Duration position) onPosition;
  final void Function(PlaybackEvent e)? onEvent;

  PlayerHandler({required this.onPosition, this.onEvent}) {
    _wire();
  }

  AudioPlayer get player => _player;

  void _wire() {
    // Position stream
    _player.positionStream.listen((pos) {
      onPosition(pos);
    });

    _player.playbackEventStream.listen((event) {
      onEvent?.call(event);
      playbackState.add(_transformEvent(event));
    });

    // Auto set mediaItem when current index changes
    _player.currentIndexStream.listen((i) async {
      if (i == null) return;
      final q = queue.value;
      if (i >= 0 && i < q.length) {
        mediaItem.add(q[i]);
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent e) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    );
  }

  Future<void> setQueueFromTracks(
    List<MediaItem> items, {
    int startIndex = 0,
    Duration? startPos,
  }) async {
    queue.add(items);

    final sources = items.map((mi) {
      final uri = Uri.file(mi.extras?['path'] as String);
      return AudioSource.uri(uri, tag: mi);
    }).toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: startIndex,
    );

    if (startPos != null) {
      await _player.seek(startPos);
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  Future<void> setLoopOne(bool on) async {
    await _player.setLoopMode(on ? LoopMode.one : LoopMode.off);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await super.stop();
  }
}

/// ===============================
/// AppLogic (single file state)
/// ===============================
class AppLogic extends ChangeNotifier {
  static const _kPrefTheme = 'settings.themeMode';
  static const _kPrefTitle = 'settings.appTitle';

  late SharedPreferences _prefs;
  Database? _db;

  // Storage folders
  late Directory _rootDir;
  late Directory audioDir;
  late Directory imageDir;
  late Directory playlistDir;
  late Directory favoritesDir;

  AppSettings settings =
      const AppSettings(themeMode: ThemeMode.dark, appTitle: 'Local Player');

  // Data in memory
  final List<TrackRow> library = [];
  final Set<String> favorites = {};
  final List<PlaylistRow> playlists = [];
  final Map<String, List<String>> playlistItems = {}; // playlistId -> trackIds

  // Player
  late final PlayerHandler handler;
  Duration position = Duration.zero;

  bool loopOne = false;
  bool continuousPlay = true;

  TrackRow? _current;
  TrackRow? get currentTrack => _current;

  Duration get currentDuration =>
      Duration(milliseconds: _current?.durationMs ?? 0);

  // throttle save playback
  Timer? _saveTimer;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();

    await _initFolders();
    await _initDb();
    await _loadAllFromDb();

    // Audio session for background playback
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    handler = await AudioService.init(
      builder: () => PlayerHandler(
        onPosition: (pos) {
          position = pos;
          _scheduleSavePlayback();
          notifyListeners();
        },
        onEvent: (_) {
          _scheduleSavePlayback();
        },
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tuanchan.localplayer.audio',
        androidNotificationChannelName: 'Local Player',
        androidNotificationOngoing: true,
      ),
    );

    await _restorePlaybackState();
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

  Future<void> _initFolders() async {
    // Use Documents to appear in Files app ("On My iPhone")
    final docs = await getApplicationDocumentsDirectory();

    _rootDir = Directory(p.join(docs.path, 'AppMusicVol2'));
    audioDir = Directory(p.join(_rootDir.path, 'Audio'));
    imageDir = Directory(p.join(_rootDir.path, 'Images'));
    playlistDir = Directory(p.join(_rootDir.path, 'Playlists'));
    favoritesDir = Directory(p.join(_rootDir.path, 'Favorites'));

    for (final d in [_rootDir, audioDir, imageDir, playlistDir, favoritesDir]) {
      if (!await d.exists()) await d.create(recursive: true);
    }
  }

  Future<void> _initDb() async {
    final dbPath = p.join(_rootDir.path, 'app.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tracks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            localPath TEXT NOT NULL,
            signature TEXT NOT NULL UNIQUE,
            coverPath TEXT,
            durationMs INTEGER NOT NULL,
            createdAt INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE favorites (
            trackId TEXT PRIMARY KEY
          );
        ''');

        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE playlist_items (
            playlistId TEXT NOT NULL,
            trackId TEXT NOT NULL,
            pos INTEGER NOT NULL,
            PRIMARY KEY (playlistId, trackId)
          );
        ''');

        await db.execute('''
          CREATE TABLE playback_state (
            k INTEGER PRIMARY KEY,
            currentTrackId TEXT,
            positionMs INTEGER NOT NULL,
            isPlaying INTEGER NOT NULL,
            loopOne INTEGER NOT NULL,
            continuous INTEGER NOT NULL
          );
        ''');

        await db.insert(
          'playback_state',
          PlaybackStateRow(
            currentTrackId: null,
            positionMs: 0,
            isPlaying: false,
            loopOne: false,
            continuous: true,
          ).toMap(),
        );
      },
    );
  }

  Future<void> _loadAllFromDb() async {
    final db = _db!;
    library
      ..clear()
      ..addAll((await db.query('tracks', orderBy: 'createdAt DESC'))
          .map(TrackRow.fromMap));

    favorites
      ..clear()
      ..addAll(
          (await db.query('favorites')).map((m) => m['trackId'] as String));

    playlists
      ..clear()
      ..addAll((await db.query('playlists', orderBy: 'createdAt DESC'))
          .map(PlaylistRow.fromMap));

    playlistItems.clear();
    for (final pl in playlists) {
      final items = await db.query(
        'playlist_items',
        where: 'playlistId=?',
        whereArgs: [pl.id],
        orderBy: 'pos ASC',
      );
      playlistItems[pl.id] = items.map((m) => m['trackId'] as String).toList();
    }

    notifyListeners();
  }

  /// ===============================
  /// Import audio (mp3/m4a) + dedupe + copy into Documents
  /// ===============================
  Future<void> importAudioFiles() async {
    // iOS may not need storage permission; Android does. Keep safe:
    if (!kIsWeb && (Platform.isAndroid)) {
      final st = await Permission.audio.request();
      if (!st.isGranted) return;
    }

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a'],
      withData: false,
    );

    if (res == null || res.files.isEmpty) return;

    int imported = 0;
    for (final f in res.files) {
      final srcPath = f.path;
      if (srcPath == null) continue;

      final ext = p.extension(srcPath).toLowerCase();
      if (ext != '.mp3' && ext != '.m4a') {
        // ignore wrong types without crash
        continue;
      }

      final file = File(srcPath);
      if (!await file.exists()) continue;

      final stat = await file.stat();
      final signature = '${p.basename(srcPath)}::${stat.size}';

      // dedupe by signature
      final exists = await _db!.query(
        'tracks',
        where: 'signature=?',
        whereArgs: [signature],
        limit: 1,
      );
      if (exists.isNotEmpty) continue;

      final id = _uuid();
      final safeName = _safeFileName(p.basename(srcPath));
      final destPath = p.join(audioDir.path, '${id}_$safeName');

      await file.copy(destPath);

      // duration: load into temp AudioPlayer to read duration (no hardcode)
      final durationMs = await _probeDurationMs(destPath);

      final title = p.basenameWithoutExtension(safeName);
      final row = TrackRow(
        id: id,
        title: title,
        artist: 'Unknown',
        localPath: destPath,
        signature: signature,
        coverPath: null,
        durationMs: durationMs,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _db!.insert('tracks', row.toMap());
      imported++;
    }

    if (imported > 0) {
      await _loadAllFromDb();
      // auto set current if empty
      if (_current == null && library.isNotEmpty) {
        await setCurrent(library.first.id, autoPlay: false);
      }
    }
  }

  Future<int> _probeDurationMs(String path) async {
    final ap = AudioPlayer();
    try {
      await ap.setFilePath(path);
      final d = ap.duration;
      return (d?.inMilliseconds ?? 0);
    } catch (_) {
      return 0;
    } finally {
      await ap.dispose();
    }
  }

  /// ===============================
  /// Cover image: pick + copy into app sandbox (rule)
  /// ===============================
  Future<void> setTrackCover(String trackId) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;

    final srcPath = res.files.first.path;
    if (srcPath == null) return;

    final ext = p.extension(srcPath).toLowerCase();
    final destPath = p.join(imageDir.path, 'cover_$trackId$ext');

    await File(srcPath).copy(destPath);

    await _db!.update(
      'tracks',
      {'coverPath': destPath},
      where: 'id=?',
      whereArgs: [trackId],
    );
    await _loadAllFromDb();

    // refresh current
    _current =
        library.firstWhere((t) => t.id == trackId, orElse: () => _current!);
    notifyListeners();
  }

  Future<void> renameTrack(String trackId, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    await _db!.update(
      'tracks',
      {'title': name},
      where: 'id=?',
      whereArgs: [trackId],
    );
    await _loadAllFromDb();
    if (_current?.id == trackId) {
      _current = library.firstWhere((t) => t.id == trackId);
    }
    notifyListeners();
  }

  /// Remove from app (delete copied audio file + db). Never touch original.
  Future<void> removeTrackFromApp(String trackId) async {
    final row = library.firstWhere((t) => t.id == trackId);

    // stop if currently playing this
    if (_current?.id == trackId) {
      await handler.pause();
      _current = null;
      position = Duration.zero;
      await _savePlaybackNow(
        isPlaying: false,
        currentTrackId: null,
        positionMs: 0,
      );
    }

    // delete files in app sandbox only
    try {
      final f = File(row.localPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (row.coverPath != null) {
      try {
        final c = File(row.coverPath!);
        if (await c.exists()) await c.delete();
      } catch (_) {}
    }

    await _db!.delete('favorites', where: 'trackId=?', whereArgs: [trackId]);
    await _db!
        .delete('playlist_items', where: 'trackId=?', whereArgs: [trackId]);
    await _db!.delete('tracks', where: 'id=?', whereArgs: [trackId]);

    await _loadAllFromDb();
  }

  Future<void> toggleFavorite(String trackId) async {
    if (favorites.contains(trackId)) {
      favorites.remove(trackId);
      await _db!.delete('favorites', where: 'trackId=?', whereArgs: [trackId]);
    } else {
      favorites.add(trackId);
      await _db!.insert('favorites', {'trackId': trackId});
    }
    notifyListeners();
  }

  /// ===============================
  /// Playlists
  /// ===============================
  Future<void> createPlaylist(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    final id = _uuid();
    final row = PlaylistRow(
      id: id,
      name: n,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db!.insert('playlists', row.toMap());
    await _loadAllFromDb();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _db!.delete('playlist_items',
        where: 'playlistId=?', whereArgs: [playlistId]);
    await _db!.delete('playlists', where: 'id=?', whereArgs: [playlistId]);
    await _loadAllFromDb();
  }

  Future<void> addToPlaylist(String playlistId, String trackId) async {
    final ids = playlistItems[playlistId] ?? [];
    if (ids.contains(trackId)) return;

    final pos = ids.length;
    await _db!.insert('playlist_items',
        {'playlistId': playlistId, 'trackId': trackId, 'pos': pos});
    await _loadAllFromDb();
  }

  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    await _db!.delete('playlist_items',
        where: 'playlistId=? AND trackId=?', whereArgs: [playlistId, trackId]);
    await _loadAllFromDb();
  }

  /// ===============================
  /// NEW: Import directly into a playlist - ALLOWS MULTIPLE FILE SELECTION
  /// ===============================
  Future<void> importIntoPlaylist(String playlistId) async {
    // iOS may not need storage permission; Android does. Keep safe:
    if (!kIsWeb && (Platform.isAndroid)) {
      final st = await Permission.audio.request();
      if (!st.isGranted) return;
    }

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true, // MULTIPLE FILES ENABLED
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a'],
      withData: false,
    );

    if (res == null || res.files.isEmpty) return;

    for (final f in res.files) {
      final srcPath = f.path;
      if (srcPath == null) continue;

      final ext = p.extension(srcPath).toLowerCase();
      if (ext != '.mp3' && ext != '.m4a') continue;

      final file = File(srcPath);
      if (!await file.exists()) continue;

      final stat = await file.stat();
      final signature = '${p.basename(srcPath)}::${stat.size}';

      // If exists in DB, reuse it
      final exists = await _db!.query(
        'tracks',
        where: 'signature=?',
        whereArgs: [signature],
        limit: 1,
      );

      String trackId;

      if (exists.isNotEmpty) {
        trackId = exists.first['id'] as String;
      } else {
        // Import as new track
        final id = _uuid();
        final safeName = _safeFileName(p.basename(srcPath));
        final destPath = p.join(audioDir.path, '${id}_$safeName');

        await file.copy(destPath);

        final durationMs = await _probeDurationMs(destPath);

        final row = TrackRow(
          id: id,
          title: p.basenameWithoutExtension(safeName),
          artist: 'Unknown',
          localPath: destPath,
          signature: signature,
          coverPath: null,
          durationMs: durationMs,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );

        await _db!.insert('tracks', row.toMap());
        trackId = id;
      }

      // Add into playlist (no duplicates)
      await addToPlaylist(playlistId, trackId);
    }

    await _loadAllFromDb();
  }

  /// ===============================
  /// NEW: Find playlists containing a track
  /// ===============================
  List<PlaylistRow> playlistsContaining(String trackId) {
    return playlists.where((pl) {
      final ids = playlistItems[pl.id] ?? const <String>[];
      return ids.contains(trackId);
    }).toList();
  }

  /// ===============================
  /// NEW: Play a playlist (ordered by pos)
  /// ===============================
  Future<void> playPlaylist(
    String playlistId, {
    bool autoPlay = true,
    String? startTrackId,
  }) async {
    final ids = playlistItems[playlistId] ?? const <String>[];
    if (ids.isEmpty) return;

    final tracks = <TrackRow>[];
    for (final id in ids) {
      final t = library.where((x) => x.id == id).toList();
      if (t.isNotEmpty) tracks.add(t.first);
    }
    if (tracks.isEmpty) return;

    int startIndex = 0;
    if (startTrackId != null) {
      final i = tracks.indexWhere((t) => t.id == startTrackId);
      if (i >= 0) startIndex = i;
    }

    final items = tracks.map(_toMediaItem).toList();

    _current = tracks[startIndex];
    position = Duration.zero;

    await handler.setQueueFromTracks(items, startIndex: startIndex);
    await handler.setLoopOne(loopOne);

    if (autoPlay) {
      await handler.play();
    } else {
      await handler.pause();
    }

    await _savePlaybackNow(
      isPlaying: autoPlay,
      currentTrackId: _current?.id,
      positionMs: 0,
    );

    notifyListeners();
  }

  /// ===============================
  /// Playback control
  /// ===============================
  Future<void> setCurrent(
    String trackId, {
    bool autoPlay = true,
    Duration? startPos,
  }) async {
    final idx = library.indexWhere((t) => t.id == trackId);
    if (idx < 0) return;

    _current = library[idx];

    final items = library.map(_toMediaItem).toList();
    await handler.setQueueFromTracks(items,
        startIndex: idx, startPos: startPos);
    await handler.setLoopOne(loopOne);

    if (autoPlay) {
      await handler.play();
    } else {
      await handler.pause();
    }

    // save state
    await _savePlaybackNow(
      isPlaying: autoPlay,
      currentTrackId: trackId,
      positionMs: (startPos ?? Duration.zero).inMilliseconds,
    );

    notifyListeners();
  }

  Future<void> playPause() async {
    if (_current == null) {
      if (library.isNotEmpty) {
        await setCurrent(library.first.id, autoPlay: true);
      }
      return;
    }
    final playing = handler.playbackState.value.playing;
    if (playing) {
      await handler.pause();
    } else {
      await handler.play();
    }
    _scheduleSavePlayback();
    notifyListeners();
  }

  Future<void> next() async {
    await handler.skipToNext();
    final idx = handler.playbackState.value.queueIndex ?? 0;
    if (idx >= 0 && idx < library.length) _current = library[idx];
    _scheduleSavePlayback();
    notifyListeners();
  }

  Future<void> previous() async {
    await handler.skipToPrevious();
    final idx = handler.playbackState.value.queueIndex ?? 0;
    if (idx >= 0 && idx < library.length) _current = library[idx];
    _scheduleSavePlayback();
    notifyListeners();
  }

  Future<void> seek(Duration to) async {
    await handler.seek(to);
    position = to;
    _scheduleSavePlayback();
    notifyListeners();
  }

  Future<void> toggleLoopOne() async {
    loopOne = !loopOne;
    await handler.setLoopOne(loopOne);
    _scheduleSavePlayback();
    notifyListeners();
  }

  Future<void> toggleContinuous() async {
    continuousPlay = !continuousPlay;
    _scheduleSavePlayback();
    notifyListeners();
  }

  /// ===============================
  /// Restore playback after reopen (no reset)
  /// ===============================
  Future<void> _restorePlaybackState() async {
    final rows = await _db!.query('playback_state', where: 'k=1', limit: 1);
    if (rows.isEmpty) return;

    final s = PlaybackStateRow.fromMap(rows.first);
    loopOne = s.loopOne;
    continuousPlay = s.continuous;

    if (s.currentTrackId != null &&
        library.any((t) => t.id == s.currentTrackId)) {
      final pos = Duration(milliseconds: s.positionMs);
      await setCurrent(s.currentTrackId!, autoPlay: s.isPlaying, startPos: pos);
    } else {
      _current = library.isEmpty ? null : library.first;
    }

    notifyListeners();
  }

  void _scheduleSavePlayback() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () async {
      final idx = handler.playbackState.value.queueIndex;
      final currentId = (idx != null && idx >= 0 && idx < library.length)
          ? library[idx].id
          : _current?.id;

      await _savePlaybackNow(
        isPlaying: handler.playbackState.value.playing,
        currentTrackId: currentId,
        positionMs: position.inMilliseconds,
      );
    });
  }

  Future<void> _savePlaybackNow({
    required bool isPlaying,
    required String? currentTrackId,
    required int positionMs,
  }) async {
    await _db!.update(
      'playback_state',
      PlaybackStateRow(
        currentTrackId: currentTrackId,
        positionMs: positionMs,
        isPlaying: isPlaying,
        loopOne: loopOne,
        continuous: continuousPlay,
      ).toMap(),
      where: 'k=1',
    );
  }

  MediaItem _toMediaItem(TrackRow t) {
    return MediaItem(
      id: t.id,
      title: t.title,
      artist: t.artist,
      duration: Duration(milliseconds: t.durationMs),
      artUri: (t.coverPath == null) ? null : Uri.file(t.coverPath!),
      extras: {'path': t.localPath},
    );
  }

  /// Utils
  String _uuid() => DateTime.now().microsecondsSinceEpoch.toString();

  String _safeFileName(String name) {
    // keep extension, remove weird chars
    final base = name.replaceAll(RegExp(r'[^\w\-. ]+'), '_');
    return base.isEmpty ? 'file' : base;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    handler.stop();
    _db?.close();
    super.dispose();
  }
}
