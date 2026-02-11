// app.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'logic.dart';

class AppRoot extends StatefulWidget {
  final AppLogic logic;
  const AppRoot({super.key, required this.logic});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.logic.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.logic.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  static const _orange = Color(0xFFFF4A00);
  static const _bg = Color(0xFF000000); // Changed to pure black

  ThemeData _theme(bool dark) {
    final base = dark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: dark ? _bg : Colors.white,
      colorScheme:
          base.colorScheme.copyWith(primary: _orange, secondary: _orange),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? _bg : Colors.white,
        foregroundColor: dark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: dark ? _bg : Colors.white,
        selectedItemColor: _orange,
        unselectedItemColor: dark ? Colors.white70 : Colors.black54,
        type: BottomNavigationBarType.fixed,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: _orange,
        thumbColor: _orange,
        overlayColor: _orange.withOpacity(0.12),
        inactiveTrackColor: dark ? Colors.white24 : Colors.black26,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1A1A1A) : const Color(0xFFF6F6F6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = widget.logic;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme(false),
      darkTheme: _theme(true),
      themeMode: logic.settings.themeMode,
      home: _Shell(
        logic: logic,
        tab: _tab,
        onTab: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  final AppLogic logic;
  final int tab;
  final ValueChanged<int> onTab;

  const _Shell({required this.logic, required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomePage(logic: logic),
      _FavoritesPage(logic: logic),
      _PlaylistsPage(logic: logic),
      _SettingsPage(logic: logic),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(logic.settings.appTitle),
        actions: [
          IconButton(
            tooltip: 'Now Playing',
            onPressed: () => _openNowPlaying(context),
            icon: const Icon(Icons.queue_music_rounded),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        onTap: onTab,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_rounded), label: 'Yêu thích'),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_music_rounded), label: 'Danh sách phát'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), label: 'Setting'),
        ],
      ),
      floatingActionButton: (tab == 0)
          ? FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () async {
                await logic.importAudioFiles();
              },
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

/// ===============================
/// HOME (library)
/// ===============================
class _HomePage extends StatelessWidget {
  final AppLogic logic;
  const _HomePage({required this.logic});

  @override
  Widget build(BuildContext context) {
    final items = logic.library;
    final currentId = logic.currentTrack?.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeroCard(logic: logic),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
                child: Text('Thư viện',
                    style: Theme.of(context).textTheme.titleLarge)),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('Chưa có file. Bấm nút + để thêm mp3/m4a vào app.'),
          ),
        ...items.map((t) {
          final isCurrent = (currentId == t.id);
          final fav = logic.favorites.contains(t.id);

          return Slidable(
            key: ValueKey(t.id),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) async => await logic.removeTrackFromApp(t.id),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_rounded,
                  label: 'Xoá',
                ),
              ],
            ),
            child: Card(
              child: ListTile(
                onTap: () async {
                  await logic.setCurrent(t.id, autoPlay: true);
                  _openNowPlaying(context, logic);
                },
                leading: _CoverThumb(path: t.coverPath, title: t.title),
                title:
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(t.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCurrent) const Icon(Icons.equalizer_rounded),
                    IconButton(
                      tooltip: fav ? 'Bỏ thích' : 'Thích',
                      onPressed: () => logic.toggleFavorite(t.id),
                      icon: Icon(fav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded),
                    ),
                    _TrackMenu(logic: logic, track: t),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _openNowPlaying(BuildContext context, AppLogic logic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

/// 3 dots menu per file
class _TrackMenu extends StatelessWidget {
  final AppLogic logic;
  final TrackRow track;

  const _TrackMenu({required this.logic, required this.track});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      onSelected: (v) async {
        if (v == 'cover') {
          await logic.setTrackCover(track.id);
        } else if (v == 'rename') {
          final name =
              await _promptText(context, 'Sửa tên', initial: track.title);
          if (name != null) await logic.renameTrack(track.id, name);
        } else if (v == 'delete') {
          await logic.removeTrackFromApp(track.id);
        } else if (v.startsWith('addpl:')) {
          final pid = v.substring('addpl:'.length);
          await logic.addToPlaylist(pid, track.id);
        }
      },
      itemBuilder: (_) {
        final pls = logic.playlists;
        return [
          const PopupMenuItem(value: 'cover', child: Text('Thêm ảnh')),
          const PopupMenuItem(value: 'rename', child: Text('Sửa tên')),
          const PopupMenuDivider(),
          ...pls.map((pl) => PopupMenuItem(
              value: 'addpl:${pl.id}', child: Text('Thêm vào: ${pl.name}'))),
          if (pls.isNotEmpty) const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Xoá khỏi app (không xoá file gốc)'),
          ),
        ];
      },
      icon: const Icon(Icons.more_vert_rounded),
    );
  }

  Future<String?> _promptText(
    BuildContext context,
    String title, {
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Lưu')),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final AppLogic logic;
  const _HeroCard({required this.logic});

  @override
  Widget build(BuildContext context) {
    final t = logic.currentTrack;
    final title = t?.title ?? 'Chưa chọn bài';
    final artist = t?.artist ?? '';
    final playing = logic.handler.playbackState.value.playing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _CoverThumb(path: t?.coverPath, title: title, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () async => await logic.playPause(),
              icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// FAVORITES
/// ===============================
class _FavoritesPage extends StatelessWidget {
  final AppLogic logic;
  const _FavoritesPage({required this.logic});

  @override
  Widget build(BuildContext context) {
    final favTracks =
        logic.library.where((t) => logic.favorites.contains(t.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Yêu thích', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (favTracks.isEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Chưa có bài yêu thích.')),
        ...favTracks.map((t) => Slidable(
              key: ValueKey('fav_${t.id}'),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) async =>
                        await logic.removeTrackFromApp(t.id),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_rounded,
                    label: 'Xoá',
                  ),
                ],
              ),
              child: Card(
                child: ListTile(
                  leading: _CoverThumb(path: t.coverPath, title: t.title),
                  title: Text(t.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(t.artist,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () async {
                    await logic.setCurrent(t.id, autoPlay: true);
                    _openNowPlaying(context, logic);
                  },
                ),
              ),
            )),
      ],
    );
  }

  void _openNowPlaying(BuildContext context, AppLogic logic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

/// ===============================
/// PLAYLISTS
/// ===============================
class _PlaylistsPage extends StatelessWidget {
  final AppLogic logic;
  const _PlaylistsPage({required this.logic});

  @override
  Widget build(BuildContext context) {
    final pls = logic.playlists;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
                child: Text('Danh sách phát',
                    style: Theme.of(context).textTheme.titleLarge)),
            FilledButton.tonalIcon(
              onPressed: () async {
                final name = await _promptText(context, 'Tạo playlist');
                if (name != null) await logic.createPlaylist(name);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pls.isEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Chưa có playlist.')),
        ...pls.map((pl) {
          final ids = logic.playlistItems[pl.id] ?? const <String>[];
          final segmentCount =
              pl.isSpecial ? logic.favoriteSegments.length : ids.length;

          return Slidable(
            key: ValueKey(pl.id),
            endActionPane: pl.isSpecial
                ? null
                : ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) async =>
                            await logic.deletePlaylist(pl.id),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete_rounded,
                        label: 'Xoá',
                      ),
                    ],
                  ),
            child: Card(
              child: ListTile(
                leading: Icon(pl.isSpecial
                    ? Icons.star_rounded
                    : Icons.playlist_play_rounded),
                title: Text(pl.name),
                subtitle: Text(pl.isSpecial
                    ? '$segmentCount phân đoạn'
                    : '$segmentCount bài'),
                onTap: () =>
                    _openPlaylist(context, pl.id, pl.name, pl.isSpecial),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<String?> _promptText(BuildContext context, String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Tạo')),
        ],
      ),
    );
  }

  void _openPlaylist(
      BuildContext context, String playlistId, String name, bool isSpecial) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => isSpecial
          ? _FavoriteSegmentsSheet(logic: logic)
          : _PlaylistSheet(logic: logic, playlistId: playlistId, name: name),
    );
  }
}

class _PlaylistSheet extends StatelessWidget {
  final AppLogic logic;
  final String playlistId;
  final String name;

  const _PlaylistSheet(
      {required this.logic, required this.playlistId, required this.name});

  @override
  Widget build(BuildContext context) {
    final ids = logic.playlistItems[playlistId] ?? const <String>[];
    final tracks =
        ids.map((id) => logic.library.firstWhere((t) => t.id == id)).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(name,
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                  tooltip: 'Phát danh sách',
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: tracks.isEmpty
                      ? null
                      : () async {
                          await logic.playPlaylist(playlistId);
                          Navigator.pop(context);
                        },
                ),
                IconButton(
                  tooltip: 'Thêm file vào playlist',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () async =>
                      await logic.importIntoPlaylist(playlistId),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (_, i) {
                  final t = tracks[i];
                  return Slidable(
                    key: ValueKey('pli_${t.id}'),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (_) async =>
                              await logic.removeFromPlaylist(
                            playlistId,
                            t.id,
                          ),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          icon: Icons.remove_circle_outline_rounded,
                          label: 'Bỏ',
                        ),
                      ],
                    ),
                    child: Card(
                      child: ListTile(
                        leading: _CoverThumb(path: t.coverPath, title: t.title),
                        title: Text(t.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(t.artist,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          await logic.playPlaylist(
                            playlistId,
                            startTrackId: t.id,
                            autoPlay: true,
                          );
                          Navigator.pop(context);
                          _openNowPlaying(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

/// ===============================
/// FAVORITE SEGMENTS SHEET
/// ===============================
class _FavoriteSegmentsSheet extends StatelessWidget {
  final AppLogic logic;

  const _FavoriteSegmentsSheet({required this.logic});

  @override
  Widget build(BuildContext context) {
    final segments = logic.favoriteSegments;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Phân đoạn yêu thích',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (segments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                    'Chưa có phân đoạn yêu thích.\nMở file nhạc và tạo phân đoạn từ nút "Now Playing".'),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: segments.length,
                itemBuilder: (_, i) {
                  final seg = segments[i];
                  final track = logic.library.firstWhere(
                    (t) => t.id == seg.trackId,
                    orElse: () => TrackRow(
                      id: '',
                      title: 'Unknown',
                      artist: '',
                      localPath: '',
                      signature: '',
                      coverPath: null,
                      durationMs: 0,
                      createdAt: 0,
                    ),
                  );

                  return Slidable(
                    key: ValueKey('seg_${seg.id}'),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (_) async =>
                              await logic.deleteFavoriteSegment(seg.id),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete_rounded,
                          label: 'Xoá',
                        ),
                      ],
                    ),
                    child: Card(
                      child: ListTile(
                        leading: _CoverThumb(
                            path: track.coverPath, title: track.title),
                        title: Text(seg.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${track.title} • ${_fmtMs(seg.startMs)} - ${_fmtMs(seg.endMs)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          await logic.playSegment(seg, autoPlay: true);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

/// ===============================
/// SETTINGS
/// ===============================
class _SettingsPage extends StatefulWidget {
  final AppLogic logic;
  const _SettingsPage({required this.logic});

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.logic.settings.appTitle);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logic = widget.logic;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Setting', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.dark_mode_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('Chế độ giao diện',
                            style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(context,
                        label: 'Tối',
                        selected: logic.settings.themeMode == ThemeMode.dark,
                        onTap: () => logic.setThemeMode(ThemeMode.dark)),
                    _chip(context,
                        label: 'Sáng',
                        selected: logic.settings.themeMode == ThemeMode.light,
                        onTap: () => logic.setThemeMode(ThemeMode.light)),
                    _chip(context,
                        label: 'System',
                        selected: logic.settings.themeMode == ThemeMode.system,
                        onTap: () => logic.setThemeMode(ThemeMode.system)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.title_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('Đổi title app (góc trái trên cùng)',
                            style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nhập title...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14))),
                  ),
                  onSubmitted: (v) => logic.setAppTitle(v),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                      onPressed: () => logic.setAppTitle(_titleCtrl.text),
                      child: const Text('Lưu')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent),
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : Theme.of(context).cardColor,
        ),
        child: Text(label),
      ),
    );
  }
}

/// ===============================
/// NOW PLAYING (smooth seek bar)
/// ===============================
class _NowPlayingSheet extends StatefulWidget {
  final AppLogic logic;
  const _NowPlayingSheet({required this.logic});

  @override
  State<_NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<_NowPlayingSheet> {
  double? _dragValue;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final logic = widget.logic;
    final track = logic.currentTrack;

    final title = track?.title ?? 'Chưa chọn bài';
    final artist = track?.artist ?? '';
    final duration = logic.currentDuration;
    final playing = logic.handler.playbackState.value.playing;

    final fav = track != null && logic.favorites.contains(track.id);

    final pls =
        track == null ? <PlaylistRow>[] : logic.playlistsContaining(track.id);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handleBar(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: Text('Đang phát',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            _BigCover(path: track?.coverPath, title: title),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(artist,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),

            /// Smooth seek bar
            _buildSeekBar(duration),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Loop one',
                  onPressed: () async => await logic.toggleLoopOne(),
                  icon: Icon(Icons.repeat_one_rounded,
                      color: logic.loopOne
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white70),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Previous',
                  onPressed: () async => await logic.previous(),
                  iconSize: 34,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  onPressed: () async => await logic.playPause(),
                  child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 28),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Next',
                  onPressed: () async => await logic.next(),
                  iconSize: 34,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Continuous play',
                  onPressed: () async => await logic.toggleContinuous(),
                  icon: Icon(Icons.all_inclusive_rounded,
                      color: logic.continuousPlay
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white70),
                ),
              ],
            ),

            if (pls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.playlist_play_rounded),
                  label: const Text('Phát danh sách'),
                  onPressed: () async {
                    if (track == null) return;

                    if (pls.length == 1) {
                      await logic.playPlaylist(
                        pls.first.id,
                        startTrackId: track.id,
                        autoPlay: true,
                      );
                      return;
                    }

                    final chosen = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Chọn playlist'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: pls
                              .map((pl) => ListTile(
                                    title: Text(pl.name),
                                    onTap: () => Navigator.pop(context, pl.id),
                                  ))
                              .toList(),
                        ),
                      ),
                    );

                    if (chosen != null) {
                      await logic.playPlaylist(
                        chosen,
                        startTrackId: track.id,
                        autoPlay: true,
                      );
                    }
                  },
                ),
              ),

            const SizedBox(height: 10),

            // Add Favorite Segment Button
            if (track != null)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.cut_rounded),
                label: const Text('Tạo phân đoạn yêu thích'),
                onPressed: () =>
                    _showCreateSegmentDialog(context, track, logic),
              ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: fav ? 'Bỏ thích' : 'Thích',
                  onPressed: track == null
                      ? null
                      : () => logic.toggleFavorite(track.id),
                  icon: Icon(fav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded),
                  color: fav
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white70,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar(Duration duration) {
    final durMs = math.max(duration.inMilliseconds, 1).toDouble();

    return StreamBuilder<Duration>(
      stream: widget.logic.handler.player.positionStream,
      builder: (_, snap) {
        final pos = _isDragging
            ? Duration(milliseconds: _dragValue!.round())
            : (snap.data ?? Duration.zero);
        final posMs = pos.inMilliseconds.toDouble();
        final value = _isDragging ? _dragValue! : posMs;
        final clamped = value.clamp(0.0, durMs);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14.0),
              ),
              child: Slider(
                min: 0,
                max: durMs,
                value: clamped,
                onChangeStart: (v) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = v;
                  });
                },
                onChanged: (v) {
                  setState(() {
                    _dragValue = v;
                  });
                },
                onChangeEnd: (v) async {
                  await widget.logic.seek(Duration(milliseconds: v.round()));
                  setState(() {
                    _isDragging = false;
                    _dragValue = null;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(Duration(milliseconds: clamped.round())),
                      style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()])),
                  Text(_fmt(duration),
                      style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _handleBar() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(999)),
    );
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _showCreateSegmentDialog(
      BuildContext context, TrackRow track, AppLogic logic) {
    final currentPos = logic.position.inMilliseconds;
    final duration = logic.currentDuration.inMilliseconds;

    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tạo phân đoạn yêu thích'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên phân đoạn',
                hintText: 'VD: Solo hay nhất',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bắt đầu (giây)',
                      hintText: '0',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: endCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kết thúc (giây)',
                      hintText: '30',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () {
                startCtrl.text = (currentPos / 1000).round().toString();
              },
              child: const Text('Dùng vị trí hiện tại làm điểm bắt đầu'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final startSec = int.tryParse(startCtrl.text) ?? 0;
              final endSec = int.tryParse(endCtrl.text) ?? (duration ~/ 1000);

              final startMs = startSec * 1000;
              final endMs = endSec * 1000;

              if (startMs >= endMs || endMs > duration) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thời gian không hợp lệ')),
                );
                return;
              }

              await logic.addFavoriteSegment(
                trackId: track.id,
                name: name,
                startMs: startMs,
                endMs: endMs,
              );

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã tạo phân đoạn yêu thích')),
              );
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// Cover widgets (FileImage if exists)
/// ===============================
class _CoverThumb extends StatelessWidget {
  final String? path;
  final String title;
  final double size;

  const _CoverThumb({required this.path, required this.title, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final has = path != null && File(path!).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: primary.withOpacity(0.14),
        child: has
            ? Image.file(File(path!), fit: BoxFit.cover)
            : Center(
                child: Text(
                  title.isEmpty ? '?' : title.characters.first.toUpperCase(),
                  style: TextStyle(
                      fontSize: size * 0.38,
                      fontWeight: FontWeight.w700,
                      color: primary),
                ),
              ),
      ),
    );
  }
}

class _BigCover extends StatelessWidget {
  final String? path;
  final String title;

  const _BigCover({required this.path, required this.title});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final has = path != null && File(path!).existsSync();

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: has
            ? Image.file(File(path!), fit: BoxFit.cover)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withOpacity(0.34),
                      primary.withOpacity(0.08)
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  title.isEmpty ? '♪' : title.characters.first.toUpperCase(),
                  style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: primary),
                ),
              ),
      ),
    );
  }
}
