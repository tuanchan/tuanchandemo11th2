// app.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
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
    widget.logic.addListener(_onLogicChanged);
  }

  @override
  void dispose() {
    widget.logic.removeListener(_onLogicChanged);
    super.dispose();
  }

  void _onLogicChanged() => setState(() {});

  static const _orange = Color(0xFFFF4A00);
  static const _bg = Color(0xFF121212);

  ThemeData _theme(bool dark) {
    final base = dark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: dark ? _bg : Colors.white,
      colorScheme: base.colorScheme.copyWith(
        primary: _orange,
        secondary: _orange,
      ),
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

      /// FIX 1: CardThemeData (không dùng CardTheme)
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1A1A1A) : const Color(0xFFF6F6F6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            onPressed: () => _openNowPlaying(context, logic),
            icon: const Icon(Icons.queue_music),
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
              onPressed: () => _openNowPlaying(context, logic),
              child: const Icon(Icons.play_arrow_rounded),
            )
          : null,
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

class _HomePage extends StatelessWidget {
  final AppLogic logic;
  const _HomePage({required this.logic});

  @override
  Widget build(BuildContext context) {
    final t = logic.currentTrack;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeroPlayerCard(logic: logic),
        const SizedBox(height: 16),
        Text('Thư viện', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...logic.library.map((track) {
          final isCurrent = t?.id == track.id;
          final fav = logic.favorites.contains(track.id);
          return Card(
            child: ListTile(
              onTap: () {
                logic.setCurrent(track.id);
                _openNowPlaying(context, logic);
              },
              leading: _CoverThumb(title: track.title),
              title: Text(track.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(track.artist,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCurrent) const Icon(Icons.equalizer_rounded),
                  IconButton(
                    tooltip: fav ? 'Bỏ thích' : 'Thích',
                    onPressed: () => logic.toggleFavorite(track.id),
                    icon: Icon(fav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded),
                  ),
                ],
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

class _FavoritesPage extends StatelessWidget {
  final AppLogic logic;
  const _FavoritesPage({required this.logic});

  @override
  Widget build(BuildContext context) {
    final favIds = logic.favorites.toList();
    final favTracks = favIds
        .map((id) => logic.library
            .firstWhere((t) => t.id == id, orElse: () => logic.library.first))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Yêu thích', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (favTracks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('Chưa có bài nào trong danh sách yêu thích.'),
          ),
        ...favTracks.map((track) => Card(
              child: ListTile(
                leading: _CoverThumb(title: track.title),
                title: Text(track.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(track.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  logic.setCurrent(track.id);
                  _openNowPlaying(context, logic);
                },
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

class _PlaylistsPage extends StatelessWidget {
  final AppLogic logic;
  const _PlaylistsPage({required this.logic});

  @override
  Widget build(BuildContext context) {
    final names = logic.playlists.keys.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Danh sách phát', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...names.map((name) {
          final ids = logic.playlists[name] ?? const <String>[];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: Text(name),
              subtitle: Text('${ids.length} bài'),
              onTap: () => _openPlaylist(context, name, ids),
            ),
          );
        }),
      ],
    );
  }

  void _openPlaylist(BuildContext context, String name, List<String> ids) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final tracks = ids
            .map((id) => logic.library.firstWhere((t) => t.id == id,
                orElse: () => logic.library.first))
            .toList();

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
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tracks.length,
                    itemBuilder: (_, i) {
                      final track = tracks[i];
                      return Card(
                        child: ListTile(
                          leading: _CoverThumb(title: track.title),
                          title: Text(track.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(track.artist,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            logic.setCurrent(track.id);
                            Navigator.pop(context);
                            _openNowPlaying(context, logic);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                    _chip(
                      context,
                      label: 'Tối',
                      selected: logic.settings.themeMode == ThemeMode.dark,
                      onTap: () => logic.setThemeMode(ThemeMode.dark),
                    ),
                    _chip(
                      context,
                      label: 'Sáng',
                      selected: logic.settings.themeMode == ThemeMode.light,
                      onTap: () => logic.setThemeMode(ThemeMode.light),
                    ),
                    _chip(
                      context,
                      label: 'System',
                      selected: logic.settings.themeMode == ThemeMode.system,
                      onTap: () => logic.setThemeMode(ThemeMode.system),
                    ),
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
                    child: const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
            'Lưu ý: Setting được lưu vĩnh viễn (thoát app mở lại vẫn giữ).'),
      ],
    );
  }

  Widget _chip(BuildContext context,
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
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

class _NowPlayingSheet extends StatefulWidget {
  final AppLogic logic;
  const _NowPlayingSheet({required this.logic});

  @override
  State<_NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<_NowPlayingSheet> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final logic = widget.logic;
    final track = logic.currentTrack;

    final title = track?.title ?? 'No track';
    final artist = track?.artist ?? '';
    final duration = logic.currentDuration;

    /// FIX 2: khai báo biến fav ngoài children
    final fav = track != null && logic.favorites.contains(track.id);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handleBar(context),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: Text('Đang phát',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BigCover(title: title),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              artist,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            StreamBuilder<Duration>(
              stream: logic.positionStream,
              initialData: logic.position,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final posMs = pos.inMilliseconds.toDouble();
                final durMs = math.max(duration.inMilliseconds, 1).toDouble();

                final value = _dragValue ?? posMs;
                final clamped = value.clamp(0.0, durMs);

                return Column(
                  children: [
                    Slider(
                      min: 0,
                      max: durMs,
                      value: clamped,
                      onChanged: (v) => setState(() => _dragValue = v),
                      onChangeEnd: (v) {
                        setState(() => _dragValue = null);
                        logic.seek(Duration(milliseconds: v.round()));
                      },
                    ),
                    Row(
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
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Loop one',
                  onPressed: logic.toggleLoopOne,
                  icon: Icon(Icons.repeat_one_rounded,
                      color: logic.loopOne
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white70),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Previous',
                  onPressed: logic.previous,
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
                  onPressed: logic.playPause,
                  child: Icon(
                      logic.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Next',
                  onPressed: logic.next,
                  iconSize: 34,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Continuous play',
                  onPressed: logic.toggleContinuous,
                  icon: Icon(Icons.all_inclusive_rounded,
                      color: logic.continuousPlay
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white70),
                ),
              ],
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

  Widget _handleBar(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _HeroPlayerCard extends StatelessWidget {
  final AppLogic logic;
  const _HeroPlayerCard({required this.logic});

  @override
  Widget build(BuildContext context) {
    final t = logic.currentTrack;
    final title = t?.title ?? 'No track';
    final artist = t?.artist ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _CoverThumb(title: title, size: 54),
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
                  Text(artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: logic.playPause,
              icon: Icon(logic.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  final String title;
  final double size;
  const _CoverThumb({required this.title, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primary.withOpacity(0.14);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        title.isEmpty ? '?' : title.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _BigCover extends StatelessWidget {
  final String title;
  const _BigCover({required this.title});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withOpacity(0.34),
              primary.withOpacity(0.08),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title.isEmpty ? '♪' : title.characters.first.toUpperCase(),
          style: TextStyle(
              fontSize: 64, fontWeight: FontWeight.w800, color: primary),
        ),
      ),
    );
  }
}
