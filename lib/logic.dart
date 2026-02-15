// logic.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';

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
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:image_picker/image_picker.dart';

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
  final bool isSpecial;

  PlaylistRow({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isSpecial = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
        'isSpecial': isSpecial ? 1 : 0
      };

  static PlaylistRow fromMap(Map<String, Object?> m) => PlaylistRow(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        createdAt: (m['createdAt'] as int?) ?? 0,
        isSpecial: ((m['isSpecial'] as int?) ?? 0) == 1,
      );
}

class FavoriteSegment {
  final String id;
  final String trackId;
  final String name;
  final int startMs;
  final int endMs;
  final int createdAt;

  FavoriteSegment({
    required this.id,
    required this.trackId,
    required this.name,
    required this.startMs,
    required this.endMs,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'trackId': trackId,
        'name': name,
        'startMs': startMs,
        'endMs': endMs,
        'createdAt': createdAt,
      };

  static FavoriteSegment fromMap(Map<String, Object?> m) => FavoriteSegment(
        id: m['id'] as String,
        trackId: m['trackId'] as String,
        name: (m['name'] as String?) ?? '',
        startMs: (m['startMs'] as int?) ?? 0,
        endMs: (m['endMs'] as int?) ?? 0,
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
/// Theme Config (A→Z palette) + persistence
/// - Mục tiêu: "quét không chừa 1 cái nào" => gom toàn bộ màu/typography tokens
/// - App.dart sẽ đọc themeConfig để build ThemeData (file app.dart anh bảo OK mới in)
/// ===============================
class ThemeConfig {
  /// Keys chuẩn hoá để app.dart build ThemeData.
  /// Anh có thể thêm key mới mà không phá backward-compat.
  static const keys = <String>[
    // Core
    'primary',
    'secondary',
    'background',
    'surface',
    'card',
    'divider',
    'shadow',

    // Text
    'textPrimary',
    'textSecondary',
    'textTertiary',
    'textOnPrimary',

    // AppBar
    'appBarBg',
    'appBarFg',

    // BottomNav
    'bottomNavBg',
    'bottomNavSelected',
    'bottomNavUnselected',

    // Buttons
    'buttonBg',
    'buttonFg',
    'buttonTonalBg',
    'buttonTonalFg',

    // Inputs
    'inputFill',
    'inputBorder',
    'inputHint',

    // Icons
    'iconPrimary',
    'iconSecondary',

    // Slider
    'sliderActive',
    'sliderInactive',
    'sliderThumb',
    'sliderOverlay',

    // Dialog / Sheet
    'dialogBg',
    'sheetBg',

    // SnackBar
    'snackBg',
    'snackFg',

    // ListTile highlight/selection
    'selectedRowBg',
    'selectedRowFg',

    // Visualizer bars
    'visualizerBar',
  ];

  /// Typography knobs (mà anh nói “font chữ header...”).
  /// Không đổi UI layout, chỉ đổi font family/weight/size tokens từ ThemeData.
  final String? fontFamily;
  final double? headerScale; // 1.0 default
  final double? bodyScale; // 1.0 default

  /// Palette lưu dưới dạng ARGB int.
  final Map<String, int> colors;

  const ThemeConfig({
    required this.colors,
    this.fontFamily,
    this.headerScale,
    this.bodyScale,
  });

  ThemeConfig copyWith({
    Map<String, int>? colors,
    String? fontFamily,
    double? headerScale,
    double? bodyScale,
  }) {
    return ThemeConfig(
      colors: colors ?? this.colors,
      fontFamily: fontFamily ?? this.fontFamily,
      headerScale: headerScale ?? this.headerScale,
      bodyScale: bodyScale ?? this.bodyScale,
    );
  }

  Color getColor(String key, Color fallback) {
    final v = colors[key];
    if (v == null) return fallback;
    return Color(v);
  }

  ThemeConfig setColor(String key, Color color) {
    final next = Map<String, int>.from(colors);
    next[key] = color.value;
    return copyWith(colors: next);
  }

  ThemeConfig resetToDefaults({required bool darkDefault}) {
    return ThemeConfig.defaults(darkDefault: darkDefault);
  }

  Map<String, Object?> toMap() => {
        'colors': colors,
        'fontFamily': fontFamily,
        'headerScale': headerScale,
        'bodyScale': bodyScale,
      };

  static ThemeConfig fromMap(Map<String, Object?> m) {
    final rawColors = (m['colors'] as Map?) ?? const {};
    final parsed = <String, int>{};
    for (final e in rawColors.entries) {
      final k = e.key.toString();
      final v = e.value;
      if (v is int) parsed[k] = v;
      if (v is num) parsed[k] = v.toInt();
      if (v is String) {
        // allow hex strings accidentally stored
        final s = v.trim();
        final maybe = int.tryParse(
          s.startsWith('0x') ? s.substring(2) : s,
          radix: 16,
        );
        if (maybe != null) parsed[k] = maybe;
      }
    }
    return ThemeConfig(
      colors: parsed,
      fontFamily: (m['fontFamily'] as String?)?.trim().isEmpty == true
          ? null
          : (m['fontFamily'] as String?),
      headerScale: (m['headerScale'] as num?)?.toDouble(),
      bodyScale: (m['bodyScale'] as num?)?.toDouble(),
    );
  }

  static ThemeConfig defaults({required bool darkDefault}) {
    // Base giống app.dart hiện tại: cam #FF4A00 + nền đen.
    const orange = 0xFFFF4A00;
    const black = 0xFF000000;
    const white = 0xFFFFFFFF;

    // Một số neutral gần giống anh đang dùng.
    const cardDark = 0xFF1A1A1A;
    const cardLight = 0xFFF6F6F6;
    const dividerDark = 0x33FFFFFF;
    const dividerLight = 0x1F000000;

    final colors = <String, int>{
      'primary': orange,
      'secondary': orange,
      'background': darkDefault ? black : white,
      'surface': darkDefault ? black : white,
      'card': darkDefault ? cardDark : cardLight,
      'divider': darkDefault ? dividerDark : dividerLight,
      'shadow': 0x73000000,
      'textPrimary': darkDefault ? 0xFFFFFFFF : 0xFF000000,
      'textSecondary': darkDefault ? 0xB3FFFFFF : 0x99000000,
      'textTertiary': darkDefault ? 0x80FFFFFF : 0x66000000,
      'textOnPrimary': 0xFFFFFFFF,
      'appBarBg': darkDefault ? black : white,
      'appBarFg': darkDefault ? 0xFFFFFFFF : 0xFF000000,
      'bottomNavBg': darkDefault ? black : white,
      'bottomNavSelected': orange,
      'bottomNavUnselected': darkDefault ? 0xB3FFFFFF : 0x8A000000,
      'buttonBg': orange,
      'buttonFg': 0xFFFFFFFF,
      'buttonTonalBg': darkDefault ? 0x1FFFF4A00 : 0x1AFF4A00,
      'buttonTonalFg': orange,
      'inputFill': darkDefault ? cardDark : cardLight,
      'inputBorder': darkDefault ? 0x33FFFFFF : 0x22000000,
      'inputHint': darkDefault ? 0x80FFFFFF : 0x66000000,
      'iconPrimary': darkDefault ? 0xFFFFFFFF : 0xFF000000,
      'iconSecondary': darkDefault ? 0xB3FFFFFF : 0x8A000000,
      'sliderActive': orange,
      'sliderInactive': darkDefault ? 0x3DFFFFFF : 0x42000000,
      'sliderThumb': orange,
      'sliderOverlay': 0x1FFF4A00,
      'dialogBg': darkDefault ? cardDark : white,
      'sheetBg': darkDefault ? cardDark : white,
      'snackBg': darkDefault ? 0xFF202020 : 0xFF202020,
      'snackFg': 0xFFFFFFFF,
      'selectedRowBg': darkDefault ? 0x1AFF4A00 : 0x14FF4A00,
      'selectedRowFg': darkDefault ? 0xFFFFFFFF : 0xFF000000,
      'visualizerBar': darkDefault ? 0xFF9E9E9E : 0xFF616161,
    };

    // Ensure all keys exist (future-proof)
    for (final k in keys) {
      colors.putIfAbsent(k, () => orange);
    }

    return ThemeConfig(
        colors: colors, fontFamily: null, headerScale: 1.0, bodyScale: 1.0);
  }
}

/// ===============================
/// Settings
/// ===============================
class AppSettings {
  final ThemeMode themeMode;
  final String appTitle;

  /// Theme token map (A→Z), persisted.
  final ThemeConfig themeConfig;

  const AppSettings({
    required this.themeMode,
    required this.appTitle,
    required this.themeConfig,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? appTitle,
    ThemeConfig? themeConfig,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        appTitle: appTitle ?? this.appTitle,
        themeConfig: themeConfig ?? this.themeConfig,
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
  bool isConvertingVideo = false;
  double convertProgress = 0.0; // 0..1
  String convertLabel = '';

  // NEW: theme config storage
  static const _kPrefThemeConfig = 'settings.themeConfig.v1';

  late SharedPreferences _prefs;
  Database? _db;

  // Storage folders
  late Directory _rootDir;
  late Directory audioDir;
  late Directory imageDir;
  late Directory playlistDir;
  late Directory favoritesDir;

  AppSettings settings = AppSettings(
    themeMode: ThemeMode.dark,
    appTitle: 'Local Player',
    themeConfig: ThemeConfig.defaults(darkDefault: true),
  );

  // Data in memory
  final List<TrackRow> library = [];
  final Set<String> favorites = {};
  final List<PlaylistRow> playlists = [];
  final Map<String, List<String>> playlistItems = {}; // playlistId -> trackIds
  final List<FavoriteSegment> favoriteSegments = [];
  StreamSubscription<MediaItem?>? _mediaItemSub;

  // Player
  PlayerHandler? handler;
  bool _handlerReady = false;

  Duration position = Duration.zero;

  bool loopOne = false;
  bool continuousPlay = true;

  TrackRow? _current;
  TrackRow? get currentTrack => _current;

  Duration get currentDuration =>
      Duration(milliseconds: _current?.durationMs ?? 0);

  // throttle save playback
  Timer? _saveTimer;

  Future<void> seekRelative(Duration delta) async {
    final cur = position; // Duration hiện tại
    final dur = currentDuration; // Duration tổng

    var next = cur + delta;

    if (next < Duration.zero) next = Duration.zero;
    if (next > dur) next = dur;

    await seek(next);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();

    await _initFolders();

    // ✅ NEW: nếu lần trước restore bị kill giữa chừng -> tự recover
    await _recoverIfInterruptedRestore();

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
        onEvent: (_) => _scheduleSavePlayback(),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tuanchan.localplayer.audio',
        androidNotificationChannelName: 'Local Player',
        androidNotificationOngoing: true,
      ),
    );
    _handlerReady = true;
    _mediaItemSub = handler!.mediaItem.listen((mi) {
      if (mi == null) return;
      final i = library.indexWhere((t) => t.id == mi.id);
      if (i >= 0) {
        _current = library[i];
        notifyListeners();
      }
    });

    await _restorePlaybackStateWithoutAutoPlay();
  }

  /// ✅ NEW: marker-based recovery nếu restore đang dang dở
  Future<void> _recoverIfInterruptedRestore() async {
    final lock = File(p.join(_rootDir.path, '.restore_lock'));
    final dbFile = File(p.join(_rootDir.path, 'app.db'));

    // Nếu có lock => restore chưa hoàn tất
    if (await lock.exists()) {
      // Trường hợp hay gặp: rootDir bị xoá dở / db mất / unzip dang dở
      // => reset về trạng thái sạch + xoá lock
      try {
        if (await _rootDir.exists()) {
          await _rootDir.delete(recursive: true);
        }
      } catch (_) {}

      await _initFolders();

      try {
        if (await lock.exists()) await lock.delete();
      } catch (_) {}
      return;
    }

    // Nếu không có lock nhưng db bị mất (kill đúng lúc xoá) => tự tạo lại folders/db
    if (!await dbFile.exists()) {
      // Không xoá audio/images (nếu còn) để tránh mất file,
      // nhưng DB sẽ được tạo lại ở _initDb(). (Nếu anh muốn rebuild DB từ folder thì làm sau)
      // Ở đây chỉ đảm bảo init không crash.
      return;
    }
  }

  void _loadSettings() {
    final themeStr = _prefs.getString(_kPrefTheme) ?? 'dark';
    final titleStr = _prefs.getString(_kPrefTitle) ?? 'Local Player';

    ThemeMode mode = switch (themeStr) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

    // Theme config decode
    ThemeConfig cfg;
    final rawCfg = _prefs.getString(_kPrefThemeConfig);
    if (rawCfg == null || rawCfg.trim().isEmpty) {
      cfg = ThemeConfig.defaults(darkDefault: mode != ThemeMode.light);
    } else {
      try {
        final m = jsonDecode(rawCfg) as Map<String, Object?>;
        cfg = ThemeConfig.fromMap(m);

        // If cfg is missing keys, patch with defaults
        final patched = Map<String, int>.from(
          ThemeConfig.defaults(darkDefault: mode != ThemeMode.light).colors,
        );
        patched.addAll(cfg.colors);
        cfg = cfg.copyWith(colors: patched);

        // Ensure scalars not null
        cfg = cfg.copyWith(
          headerScale: cfg.headerScale ?? 1.0,
          bodyScale: cfg.bodyScale ?? 1.0,
        );
      } catch (_) {
        cfg = ThemeConfig.defaults(darkDefault: mode != ThemeMode.light);
      }
    }

    settings = AppSettings(
      themeMode: mode,
      appTitle: titleStr,
      themeConfig: cfg,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
  final prevMode = settings.themeMode;

  settings = settings.copyWith(themeMode: mode);

  await _prefs.setString(
    _kPrefTheme,
    switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark'
    },
  );

  final oldIsDark = prevMode == ThemeMode.dark || prevMode == ThemeMode.system;
  final newIsDark = mode == ThemeMode.dark || mode == ThemeMode.system;

  final currentCfg = settings.themeConfig;
  final defaultOld = ThemeConfig.defaults(darkDefault: oldIsDark);

  bool isStillDefault = true;
  for (final k in ThemeConfig.keys) {
    if (currentCfg.colors[k] != defaultOld.colors[k]) {
      isStillDefault = false;
      break;
    }
  }

  if (isStillDefault) {
    settings = settings.copyWith(
      themeConfig: ThemeConfig.defaults(darkDefault: newIsDark),
    );
    await _persistThemeConfig();
  }

  notifyListeners();
}


  Future<void> setAppTitle(String title) async {
    final t = title.trim().isEmpty ? 'Local Player' : title.trim();
    settings = settings.copyWith(appTitle: t);
    await _prefs.setString(_kPrefTitle, settings.appTitle);
    notifyListeners();
  }

  /// ===============================
  /// NEW: Theme Config APIs (A→Z)
  /// - app.dart sẽ dùng settings.themeConfig để build ThemeData (không đổi UI layout)
  /// ===============================
  Future<void> setThemeColor(String key, Color color) async {
    final cfg = settings.themeConfig.setColor(key, color);
    settings = settings.copyWith(themeConfig: cfg);
    await _persistThemeConfig();
    notifyListeners();
  }

  Future<void> setFontFamily(String? fontFamily) async {
    final ff = (fontFamily?.trim().isEmpty ?? true) ? null : fontFamily!.trim();
    settings = settings.copyWith(
      themeConfig: settings.themeConfig.copyWith(fontFamily: ff),
    );
    await _persistThemeConfig();
    notifyListeners();
  }

  Future<void> setHeaderScale(double scale) async {
    final s = scale.clamp(0.8, 1.6);
    settings = settings.copyWith(
      themeConfig: settings.themeConfig.copyWith(headerScale: s),
    );
    await _persistThemeConfig();
    notifyListeners();
  }

  Future<void> setBodyScale(double scale) async {
    final s = scale.clamp(0.8, 1.6);
    settings = settings.copyWith(
      themeConfig: settings.themeConfig.copyWith(bodyScale: s),
    );
    await _persistThemeConfig();
    notifyListeners();
  }

  Future<void> resetThemeToDefaults({bool? darkDefault}) async {
    final useDark = darkDefault ??
        (settings.themeMode == ThemeMode.dark ||
            settings.themeMode == ThemeMode.system);
    settings = settings.copyWith(
      themeConfig: ThemeConfig.defaults(darkDefault: useDark),
    );
    await _persistThemeConfig();
    notifyListeners();
  }

  Future<void> _persistThemeConfig() async {
    final raw = jsonEncode(settings.themeConfig.toMap());
    await _prefs.setString(_kPrefThemeConfig, raw);
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
File get _globalRestoreLock => File(p.join(_docsDir.path, '.appmusic_restore_lock'));
  Future<void> _initDb() async {
    final dbPath = p.join(_rootDir.path, 'app.db');
    _db = await openDatabase(
      dbPath,
      version: 2,
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
            createdAt INTEGER NOT NULL,
            isSpecial INTEGER DEFAULT 0
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
          CREATE TABLE favorite_segments (
            id TEXT PRIMARY KEY,
            trackId TEXT NOT NULL,
            name TEXT NOT NULL,
            startMs INTEGER NOT NULL,
            endMs INTEGER NOT NULL,
            createdAt INTEGER NOT NULL
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

        // Create default "Phân đoạn yêu thích" playlist
        await db.insert('playlists', {
          'id': 'special_favorite_segments',
          'name': 'Phân đoạn yêu thích',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'isSpecial': 1,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            ALTER TABLE playlists ADD COLUMN isSpecial INTEGER DEFAULT 0;
          ''');

          await db.execute('''
            CREATE TABLE favorite_segments (
              id TEXT PRIMARY KEY,
              trackId TEXT NOT NULL,
              name TEXT NOT NULL,
              startMs INTEGER NOT NULL,
              endMs INTEGER NOT NULL,
              createdAt INTEGER NOT NULL
            );
          ''');

          // Create default "Phân đoạn yêu thích" playlist if not exists
          final exists = await db.query('playlists',
              where: 'id=?', whereArgs: ['special_favorite_segments']);
          if (exists.isEmpty) {
            await db.insert('playlists', {
              'id': 'special_favorite_segments',
              'name': 'Phân đoạn yêu thích',
              'createdAt': DateTime.now().millisecondsSinceEpoch,
              'isSpecial': 1,
            });
          }
        }
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

    favoriteSegments
      ..clear()
      ..addAll((await db.query('favorite_segments', orderBy: 'createdAt DESC'))
          .map(FavoriteSegment.fromMap));

    notifyListeners();
  }

  /// ===============================
  /// Import audio (mp3/m4a) + dedupe + copy into Documents
  /// ===============================
  Future<void> importAudioFiles() async {
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
      if (ext != '.mp3' && ext != '.m4a') continue;

      final file = File(srcPath);
      if (!await file.exists()) continue;

      final stat = await file.stat();
      final signature = '${p.basename(srcPath)}::${stat.size}';

      final exists = await _db!.query(
        'tracks',
        where: 'signature=?',
        whereArgs: [signature],
        limit: 1,
      );
      if (exists.isNotEmpty) continue;

      final id = _uuid();
      // ✅ FIX: tên file = id + ext (không có unicode/space -> tránh lỗi -11800)
      final destPath = p.join(audioDir.path, '$id$ext');

      await file.copy(destPath);

      // ✅ verify file copy thành công
      final destFile = File(destPath);
      if (!await destFile.exists() || (await destFile.stat()).size == 0) {
        try {
          await destFile.delete();
        } catch (_) {}
        continue;
      }

      final durationMs = await _probeDurationMs(destPath);

      // title vẫn lấy tên gốc để hiển thị đẹp
      final title = p.basenameWithoutExtension(p.basename(srcPath));
      final row = TrackRow(
        id: id,
        title: title.isEmpty ? 'Unknown' : title,
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
      if (_current == null && library.isNotEmpty) {
        await setCurrent(library.first.id, autoPlay: false);
      }
    }
  }

  /// ===============================
  /// NEW: Import from VIDEO -> convert to M4A (AAC) -> add into tracks DB
  /// - KHÔNG đụng tới importAudioFiles() cũ
  /// - Output lưu vào audioDir của app (Documents/AppMusicVol2/Audio)
  /// - Trả về null nếu OK, trả về string nếu lỗi để UI show SnackBar
  /// ===============================
  Future<String?> importVideoToM4a() async {
    if (isConvertingVideo) return 'Đang chuyển đổi, vui lòng chờ...';

    isConvertingVideo = true;
    convertProgress = 0.0;
    convertLabel = 'Đang chọn video...';
    notifyListeners();

    try {
      // 1) PICK VIDEO FROM PHOTOS (Gallery)
      final picker = ImagePicker();
      final x = await picker.pickVideo(source: ImageSource.gallery);
      if (x == null) {
        isConvertingVideo = false;
        convertLabel = '';
        notifyListeners();
        return 'Đã huỷ chọn video';
      }

      final srcPath = x.path;
      final srcFile = File(srcPath);
      if (!await srcFile.exists()) {
        isConvertingVideo = false;
        convertLabel = '';
        notifyListeners();
        return 'Video không tồn tại';
      }

      // 2) Prepare output
      convertLabel = 'Đang chuẩn bị chuyển đổi...';
      notifyListeners();

      final id = _uuid();
      final base = p.basenameWithoutExtension(srcPath);
      final safeBase = _safeFileName(base);
      final outPath = p.join(audioDir.path, '${id}_$safeBase.m4a');

      // 3) Run FFmpeg async + statistics progress
      // - statistics.getTime() trả ms đã xử lý => map sang progress.
      // API statistics callback của ffmpeg-kit Flutter: :contentReference[oaicite:2]{index=2}
      //
      // Lưu ý: để progress "đúng nghĩa" cần duration đầu vào.
      // Nếu anh muốn 100% chính xác, nên FFprobe duration trước.
      // (Ở đây tạm dùng progress theo time processed / duration audio/video ước lượng từ player sau khi convert là không được.)
      //
      // => Cách đúng: dùng FFprobeKit để lấy duration input (nếu package anh đang dùng có FFprobeKit).
      // Nếu dự án anh chưa import FFprobeKit, anh có thể để progress dạng indeterminate (LinearProgressIndicator không value).
      //
      // Bản này: cho progress "theo time processed", nhưng nếu chưa lấy duration -> vẫn hiển thị % tương đối bằng cách clamp.
      double? inputDurationMs; // TODO: fill via FFprobeKit for exact progress

      final cmd =
          '-y -i "${_ffq(srcPath)}" -vn -c:a aac -b:a 192k "${_ffq(outPath)}"';

      final completer = Completer<String?>();
      convertLabel = 'Đang chuyển đổi...';
      notifyListeners();

      await FFmpegKit.executeAsync(
        cmd,
        (session) async {
          final rc = await session.getReturnCode();
          if (!ReturnCode.isSuccess(rc)) {
            final logs = await session.getAllLogsAsString();
            completer.complete(
              'Convert thất bại${logs == null || logs.trim().isEmpty ? '' : '\n$logs'}',
            );
            return;
          }

          // 4) Add to DB
          final durationMs = await _probeDurationMs(outPath);
          final st = await File(outPath).stat();
          final signature = '${p.basename(outPath)}::${st.size}';

          final exists = await _db!.query(
            'tracks',
            where: 'signature=?',
            whereArgs: [signature],
            limit: 1,
          );

          if (exists.isNotEmpty) {
            try {
              await File(outPath).delete();
            } catch (_) {}
            completer.complete('File đã tồn tại trong thư viện');
            return;
          }

          final row = TrackRow(
            id: id,
            title: safeBase.isEmpty ? 'Video Audio' : safeBase,
            artist: 'Unknown',
            localPath: outPath,
            signature: signature,
            coverPath: null,
            durationMs: durationMs,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );

          await _db!.insert('tracks', row.toMap());
          await _loadAllFromDb();

          if (_current == null && library.isNotEmpty) {
            await setCurrent(library.first.id, autoPlay: false);
          }

          convertProgress = 1.0;
          convertLabel = 'Hoàn tất';
          notifyListeners();

          completer.complete(null);
        },
        null,
        (statistics) {
          // statistics.getTime() là ms đã xử lý (theo ffmpeg-kit). :contentReference[oaicite:3]{index=3}
          final t = statistics.getTime(); // ms
          if (inputDurationMs != null && inputDurationMs! > 0) {
            convertProgress = (t / inputDurationMs!).clamp(0.0, 0.999);
          } else {
            // chưa có duration -> chỉ “nhúc nhích” để UI có cảm giác đang chạy
            convertProgress = (convertProgress + 0.01).clamp(0.0, 0.95);
          }
          notifyListeners();
        },
      );

      return await completer.future;
    } catch (e) {
      return e.toString();
    } finally {
      isConvertingVideo = false;
      // convertLabel giữ lại để UI kịp show “Hoàn tất” 1 nhịp (tuỳ anh)
      notifyListeners();
    }
  }

  /// Escape quote cho FFmpeg command
  String _ffq(String s) => s.replaceAll('"', '\\"');

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
      await handler?.pause();

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
    // Prevent deleting special playlists
    final pl = playlists.firstWhere((p) => p.id == playlistId);
    if (pl.isSpecial) return;

    await _db!.delete('playlist_items',
        where: 'playlistId=?', whereArgs: [playlistId]);
    await _db!.delete('playlists', where: 'id=?', whereArgs: [playlistId]);
    await _loadAllFromDb();
  }

  /// ===============================
  /// Favorite Segments
  /// ===============================
  Future<void> addFavoriteSegment({
    required String trackId,
    required String name,
    required int startMs,
    required int endMs,
  }) async {
    final id = _uuid();
    final segment = FavoriteSegment(
      id: id,
      trackId: trackId,
      name: name,
      startMs: startMs,
      endMs: endMs,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db!.insert('favorite_segments', segment.toMap());
    await _loadAllFromDb();
  }

  Future<void> deleteFavoriteSegment(String segmentId) async {
    await _db!
        .delete('favorite_segments', where: 'id=?', whereArgs: [segmentId]);
    await _loadAllFromDb();
  }

  List<FavoriteSegment> getSegmentsForTrack(String trackId) {
    return favoriteSegments.where((s) => s.trackId == trackId).toList();
  }

  Future<void> playSegment(FavoriteSegment segment,
      {bool autoPlay = true}) async {
    final idx = library.indexWhere((t) => t.id == segment.trackId);
    if (idx < 0) return;
    final track = library[idx];

    _current = track;
    final startPos = Duration(milliseconds: segment.startMs);

    final items = library.map(_toMediaItem).toList();
    await handler!.setQueueFromTracks(items,
        startIndex: idx, startPos: startPos);
    await handler!.setLoopOne(false);

    if (autoPlay) {
      await handler!.play();
    }

    await _savePlaybackNow(
      isPlaying: autoPlay,
      currentTrackId: track.id,
      positionMs: segment.startMs,
    );

    notifyListeners();
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

    for (final f in res.files) {
      final srcPath = f.path;
      if (srcPath == null) continue;

      final ext = p.extension(srcPath).toLowerCase();
      if (ext != '.mp3' && ext != '.m4a') continue;

      final file = File(srcPath);
      if (!await file.exists()) continue;

      final stat = await file.stat();
      final signature = '${p.basename(srcPath)}::${stat.size}';

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
        final id = _uuid();
        // ✅ FIX: tên file = id + ext
        final destPath = p.join(audioDir.path, '$id$ext');

        await file.copy(destPath);

        final destFile = File(destPath);
        if (!await destFile.exists() || (await destFile.stat()).size == 0) {
          try {
            await destFile.delete();
          } catch (_) {}
          continue;
        }

        final durationMs = await _probeDurationMs(destPath);
        final title = p.basenameWithoutExtension(p.basename(srcPath));

        final row = TrackRow(
          id: id,
          title: title.isEmpty ? 'Unknown' : title,
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

    await handler!.setQueueFromTracks(items, startIndex: startIndex);
    await handler!.setLoopOne(loopOne);

    if (autoPlay) {
      await handler!.play();
    } else {
      await handler!.pause();
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

    // ✅ FIX: Verify file actually exists before trying to play
    final file = File(_current!.localPath);
    if (!await file.exists()) {
      debugPrint('setCurrent: file not found at ${_current!.localPath}');
      notifyListeners();
      return;
    }

    try {
      final items = library.map(_toMediaItem).toList();
      await handler!.setQueueFromTracks(
        items,
        startIndex: idx,
        startPos: startPos,
      );
      await handler!.setLoopOne(loopOne);

      if (autoPlay) {
        await handler!.play();
      } else {
        await handler!.pause();
      }

      await _savePlaybackNow(
        isPlaying: autoPlay,
        currentTrackId: trackId,
        positionMs: (startPos ?? Duration.zero).inMilliseconds,
      );
    } catch (e) {
      debugPrint('setCurrent error: $e');
    }

    notifyListeners();
  }

  Future<void> playPause() async {
    if (_current == null) {
      if (library.isNotEmpty) {
        await setCurrent(library.first.id, autoPlay: true);
      }
      return;
    }
    final playing = handler?.playbackState.value.playing ?? false;
if (playing) {
      await handler?.pause();
    } else {
      await handler?.play();
    }
    _scheduleSavePlayback();
    notifyListeners();
  }

  Future<void> next() async {
    await handler?.skipToNext();
    _scheduleSavePlayback();
    notifyListeners(); // _current sẽ được update bởi mediaItem listener
  }

  Future<void> previous() async {
    await handler?.skipToPrevious();
    _scheduleSavePlayback();
    notifyListeners(); // _current sẽ được update bởi mediaItem listener
  }

  Future<void> seek(Duration to) async {
    await handler?.seek(to);
    position = to;
    _scheduleSavePlayback();
    notifyListeners();
  }

  Future<void> toggleLoopOne() async {
    loopOne = !loopOne;
    await handler?.setLoopOne(loopOne);
    _scheduleSavePlayback();
    notifyListeners();
  }

  Future<void> toggleContinuous() async {
    continuousPlay = !continuousPlay;
    _scheduleSavePlayback();
    notifyListeners();
  }

  /// ===============================
  /// Restore state without auto-playing
  /// ===============================
  Future<void> _restorePlaybackStateWithoutAutoPlay() async {
    final rows = await _db!.query('playback_state', where: 'k=1', limit: 1);
    if (rows.isEmpty) return;

    final s = PlaybackStateRow.fromMap(rows.first);
    loopOne = s.loopOne;
    continuousPlay = s.continuous;

    String? trackIdToLoad = s.currentTrackId;

    // ✅ FIX: nếu saved track không còn trong library, fallback về first
    if (trackIdToLoad != null && !library.any((t) => t.id == trackIdToLoad)) {
      trackIdToLoad = null;
    }

    // ✅ FIX: fallback về library.first nếu không có saved track
    if (trackIdToLoad == null && library.isNotEmpty) {
      trackIdToLoad = library.first.id;
    }

    if (trackIdToLoad == null) {
      notifyListeners();
      return;
    }

    final idx = library.indexWhere((t) => t.id == trackIdToLoad);
    if (idx < 0) {
      notifyListeners();
      return;
    }

    _current = library[idx];

    // ✅ FIX: verify file exists
    final file = File(_current!.localPath);
    if (!await file.exists()) {
      debugPrint('restore: file missing ${_current!.localPath}');
      _current = null;
      notifyListeners();
      return;
    }

    try {
      final items = library.map(_toMediaItem).toList();
      await handler!.setQueueFromTracks(items, startIndex: idx);
      await handler!.setLoopOne(loopOne);
      // ✅ CRITICAL: luôn pause sau restore, không tự phát
      await handler!.pause();
    } catch (e) {
      debugPrint('restore error: $e');
      _current = null;
    }

    notifyListeners();
  }

  void _scheduleSavePlayback() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () async {
      final idx = handler?.playbackState.value.queueIndex;
      final currentId = (idx != null && idx >= 0 && idx < library.length)
          ? library[idx].id
          : _current?.id;

      await _savePlaybackNow(
  isPlaying: handler?.playbackState.value.playing ?? false,
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

  /// ===============================
  /// BACKUP → EXPORT ZIP
  /// ===============================
  Future<String?> exportLibraryToZip() async {
  final tmpDir = await getTemporaryDirectory();
  final exportPath = p.join(
    tmpDir.path,
    'backup_${DateTime.now().millisecondsSinceEpoch}.zip',
  );

  try {
    final root = Directory(_rootDir.path);
    if (!await root.exists()) return 'Không tìm thấy dữ liệu';

    // ✅ STREAMING: ZipFileEncoder ghi thẳng ra file, không buffer vào RAM
    final encoder = ZipFileEncoder();
    encoder.create(exportPath);

    try {
      final files = root.listSync(recursive: true, followLinks: false);

      for (final f in files) {
        if (f is! File) continue;

        final ext = p.extension(f.path).toLowerCase();
        if (ext == '.zip') continue;

        final name = p.basename(f.path);
        if (name == '.restore_lock') continue;

        final rel = p.relative(f.path, from: _rootDir.path);

        // ✅ addFile dùng InputFileStream bên trong -> không load hết vào RAM
        encoder.addFile(f, rel);
      }
    } finally {
      encoder.close();
    }

    // Verify output tồn tại
    if (!await File(exportPath).exists()) {
      return 'Không thể tạo file zip';
    }

    return exportPath;
  } catch (e) {
    // Cleanup nếu lỗi
    try {
      final out = File(exportPath);
      if (await out.exists()) await out.delete();
    } catch (_) {}
    return e.toString();
  }
}

  /// ===============================
  /// RESTORE → IMPORT ZIP
  /// ===============================
  /// ===============================
  /// RESTORE → IMPORT ZIP (FIX: đóng DB/player trước khi xoá rootDir để tránh crash/white screen)
  /// ===============================
  /// ===============================
/// RESTORE → IMPORT ZIP (STREAMING - chịu 1GB+)
/// ===============================


Future<String?> importLibraryFromZip() async {
  await _initFolders();
  Directory? tmpDir;
  Directory? oldDir;

  try {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );

    if (res == null || res.files.isEmpty) return 'Đã huỷ';
    final zipPath = res.files.first.path;
    if (zipPath == null) return 'File không hợp lệ';

    // 1) Teardown runtime
    await _teardownBeforeRestore();

    // 2) Lock
    final lockFile = File(p.join(_rootDir.path, '.restore_lock'));
    try {
      await _rootDir.create(recursive: true);
      await lockFile.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {}

    // 3) Prepare tmpDir
    final parent = Directory(p.dirname(_rootDir.path));
    tmpDir = Directory(p.join(parent.path, 'AppMusicVol2_tmp_restore'));
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    await tmpDir.create(recursive: true);

    // 4) STREAMING extract: dùng InputFileStream + decodeBuffer
    //    Không load toàn bộ ZIP vào RAM
    final pathRemap = <String, String>{};

    final inputStream = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeBuffer(inputStream);

      for (final file in archive) {
        if (!file.isFile) {
          await Directory(p.join(tmpDir.path, file.name))
              .create(recursive: true);
          continue;
        }

        String outRelPath = file.name;

        // Đổi tên file audio = id + ext để tránh lỗi -11800
        final isAudio = outRelPath.startsWith('Audio/') ||
            outRelPath.startsWith('Audio\\');
        if (isAudio) {
          final ext = p.extension(file.name).toLowerCase();
          if (ext == '.mp3' || ext == '.m4a') {
            final baseName =
                p.basenameWithoutExtension(p.basename(file.name));
            final underscoreIdx = baseName.indexOf('_');
            final id = underscoreIdx > 0
                ? baseName.substring(0, underscoreIdx)
                : baseName;
            final newRelPath = 'Audio/$id$ext';
            if (newRelPath != outRelPath) {
              pathRemap[outRelPath] = newRelPath;
              outRelPath = newRelPath;
            }
          }
        }

        final outPath = p.join(tmpDir.path, outRelPath);
        final outFile = File(outPath);
        await outFile.create(recursive: true);

        // ✅ STREAMING: writeContent dùng OutputFileStream -> không buffer vào RAM
        final outputStream = OutputFileStream(outPath);
        try {
          file.writeContent(outputStream);
        } finally {
          await outputStream.close();
        }
      }
    } finally {
      await inputStream.close();
    }

    // 5) Patch DB trong tmpDir
    if (pathRemap.isNotEmpty) {
      await _patchDbAfterRestore(tmpDir.path, pathRemap);
    }

    // 6) Atomic swap với fallback copy nếu rename fail (cross-volume trên iOS)
    oldDir = Directory(p.join(parent.path, 'AppMusicVol2_old_backup'));
    if (await oldDir.exists()) await oldDir.delete(recursive: true);

    if (await _rootDir.exists()) {
      // Thử rename trước (nhanh)
      try {
        await _rootDir.rename(oldDir.path);
      } catch (_) {
        // Fallback: copy rồi delete (cross-volume)
        await _copyDir(_rootDir, oldDir);
        await _rootDir.delete(recursive: true);
      }
    }

    // Thử rename tmpDir -> rootDir
    try {
      await tmpDir.rename(_rootDir.path);
    } catch (_) {
      // Fallback: copy
      await _copyDir(tmpDir, _rootDir);
      await tmpDir.delete(recursive: true);
    }

    // tmpDir đã được rename/copy -> đặt null để finally không xoá nhầm
    tmpDir = null;

    // 7) Xoá lock
    try {
      final lockNow = File(p.join(_rootDir.path, '.restore_lock'));
      if (await lockNow.exists()) await lockNow.delete();
    } catch (_) {}

    // 8) Re-init
    await _initFolders();
    await _initDb();
    await _rebuildAbsolutePathsAfterRestore();
    await _loadAllFromDb();
    await _removeTracksWithMissingFiles();

    if (library.isNotEmpty) {
      await setCurrent(library.first.id, autoPlay: false);
      await handler?.pause();
    }

    // 9) Cleanup old
    try {
      if (oldDir != null && await oldDir.exists()) {
        await oldDir.delete(recursive: true);
      }
    } catch (_) {}

    notifyListeners();
    return null;
  } catch (e) {
    return e.toString();
  } finally {
    try {
      if (tmpDir != null && await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}

/// ✅ NEW: Fallback copy dir khi rename fail (cross-volume iOS)
Future<void> _copyDir(Directory src, Directory dest) async {
  await dest.create(recursive: true);
  await for (final entity in src.list(recursive: false)) {
    if (entity is Directory) {
      final newDir = Directory(
        p.join(dest.path, p.basename(entity.path)),
      );
      await _copyDir(entity, newDir);
    } else if (entity is File) {
      await entity.copy(
        p.join(dest.path, p.basename(entity.path)),
      );
    }
  }
}

  /// ✅ NEW: Patch localPath trong DB sau khi đổi tên file audio
  Future<void> _patchDbAfterRestore(
      String tmpDirPath, Map<String, String> pathRemap) async {
    final dbPath = p.join(tmpDirPath, 'app.db');
    if (!await File(dbPath).exists()) return;

    // ✅ FIX: tính trước rootDir thật (tmpDir sẽ được rename thành rootDir)
    // nên path cuối cùng phải dùng audioDir.path (đã được _initFolders set đúng)
    // Nhưng _initFolders chưa chạy lúc này -> dùng tmpDirPath/Audio làm base tạm,
    // _rebuildAbsolutePathsAfterRestore() sẽ fix lại đúng path sau khi rename xong.

    Database? patchDb;
    try {
      patchDb = await openDatabase(dbPath);

      final tracks = await patchDb.query('tracks');
      for (final row in tracks) {
        final oldLocalPath = row['localPath'] as String? ?? '';
        if (oldLocalPath.isEmpty) continue;

        String? matchedOldRel;
        String? matchedNewRel;

        for (final entry in pathRemap.entries) {
          final oldRel = entry.key; // e.g. 'Audio/123_tenfile.mp3'
          // Match theo basename của oldRel vs basename của oldLocalPath
          if (p.basename(oldLocalPath) == p.basename(oldRel)) {
            matchedOldRel = oldRel;
            matchedNewRel = entry.value; // e.g. 'Audio/123.mp3'
            break;
          }
          // fallback: path contains
          if (oldLocalPath
              .contains(oldRel.replaceAll('/', Platform.pathSeparator))) {
            matchedOldRel = oldRel;
            matchedNewRel = entry.value;
            break;
          }
        }

        if (matchedNewRel != null) {
          // ✅ FIX: lưu path dựa trên tmpDirPath (sẽ được rename thành rootDir)
          // _rebuildAbsolutePathsAfterRestore() sẽ fix lại nếu path thay đổi sau rename
          final newAbsPath = p.join(tmpDirPath, matchedNewRel);
          await patchDb.update(
            'tracks',
            {'localPath': newAbsPath},
            where: 'id=?',
            whereArgs: [row['id']],
          );
        }
      }
    } catch (e) {
      debugPrint('_patchDbAfterRestore error: $e');
    } finally {
      await patchDb?.close();
    }
  }

  /// ✅ NEW: Sau khi restore + load DB, fix absolute paths vì rootDir có thể đổi
  /// (VD: Documents path thay đổi giữa các lần cài app trên iOS)
  Future<void> _rebuildAbsolutePathsAfterRestore() async {
    final db = _db!;
    final tracks = await db.query('tracks');

    for (final row in tracks) {
      final localPath = row['localPath'] as String? ?? '';
      if (localPath.isEmpty) continue;

      // Nếu file tồn tại ở path cũ -> không cần fix
      if (await File(localPath).exists()) continue;

      // Thử rebuild: lấy basename và tìm trong audioDir
      final baseName = p.basename(localPath);
      final candidate = p.join(audioDir.path, baseName);

      if (await File(candidate).exists()) {
        await db.update(
          'tracks',
          {'localPath': candidate},
          where: 'id=?',
          whereArgs: [row['id']],
        );
      }

      // Tương tự coverPath
      final coverPath = row['coverPath'] as String?;
      if (coverPath != null && coverPath.isNotEmpty) {
        if (!await File(coverPath).exists()) {
          final coverBase = p.basename(coverPath);
          final coverCandidate = p.join(imageDir.path, coverBase);
          if (await File(coverCandidate).exists()) {
            await db.update(
              'tracks',
              {'coverPath': coverCandidate},
              where: 'id=?',
              whereArgs: [row['id']],
            );
          }
        }
      }
    }
  }

  /// ✅ NEW: Xoá track khỏi DB nếu file audio không còn tồn tại
  Future<void> _removeTracksWithMissingFiles() async {
    final db = _db!;
    final toRemove = <String>[];

    for (final t in library) {
      if (!await File(t.localPath).exists()) {
        toRemove.add(t.id);
        debugPrint('Missing file, removing track: ${t.title} @ ${t.localPath}');
      }
    }

    for (final id in toRemove) {
      await db.delete('favorites', where: 'trackId=?', whereArgs: [id]);
      await db.delete('playlist_items', where: 'trackId=?', whereArgs: [id]);
      await db.delete('tracks', where: 'id=?', whereArgs: [id]);
    }

    if (toRemove.isNotEmpty) {
      await _loadAllFromDb();
    }
  }

  /// Helper: đóng mọi thứ trước khi restore để không “giữ tay” vào file cũ
  Future<void> _teardownBeforeRestore() async {
    _saveTimer?.cancel();
    _saveTimer = null;

    await _mediaItemSub?.cancel();
    _mediaItemSub = null;
    
    if (_handlerReady && handler != null) {
  try { await handler!.pause(); } catch (_) {}
  try { await handler!.stop(); } catch (_) {}
}
handler = null;
_handlerReady = false;



    try {
      await _db?.close();
    } catch (_) {}
    _db = null;

    library.clear();
    favorites.clear();
    playlists.clear();
    playlistItems.clear();
    favoriteSegments.clear();
    _current = null;
    position = Duration.zero;

    notifyListeners();
  }

   @override
  void dispose() {
    _saveTimer?.cancel();
    _mediaItemSub?.cancel();

    if (_handlerReady && handler != null) {
      handler!.stop();
    }

    _db?.close();
    super.dispose();
  }
}
