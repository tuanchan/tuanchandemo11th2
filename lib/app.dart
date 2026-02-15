// app.dart
// app.dart - CẬP NHẬT: THEME CONFIG A→Z (đổi mọi màu/font), GIỮ NGUYÊN UI/LAYOUT,
// VISUALIZER TO HƠN + STICKY HEROCARD
import 'package:archive/archive.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
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

  ThemeData _buildTheme({required bool dark, required ThemeConfig cfg}) {
    final base = dark ? ThemeData.dark() : ThemeData.light();

    // Fallbacks theo dark/light
    final fallback = ThemeConfig.defaults(darkDefault: dark);

    Color c(String k, Color fb) => cfg.getColor(k, fb);
    Color cf(String k) => cfg.getColor(k, fallback.getColor(k, Colors.pink));

    final primary = cf('primary');
    final secondary = cf('secondary');
    final background = cf('background');
    final surface = cf('surface');
    final card = cf('card');
    final divider = cf('divider');
    final shadow = cf('shadow');

    final textPrimary = cf('textPrimary');
    final textSecondary = cf('textSecondary');
    final textTertiary = cf('textTertiary');
    final textOnPrimary = cf('textOnPrimary');

    final appBarBg = cf('appBarBg');
    final appBarFg = cf('appBarFg');

    final bottomBg = cf('bottomNavBg');
    final bottomSelected = cf('bottomNavSelected');
    final bottomUnselected = cf('bottomNavUnselected');

    final buttonBg = cf('buttonBg');
    final buttonFg = cf('buttonFg');
    final buttonTonalBg = cf('buttonTonalBg');
    final buttonTonalFg = cf('buttonTonalFg');

    final inputFill = cf('inputFill');
    final inputBorder = cf('inputBorder');
    final inputHint = cf('inputHint');

    final iconPrimary = cf('iconPrimary');
    final iconSecondary = cf('iconSecondary');

    final sliderActive = cf('sliderActive');
    final sliderInactive = cf('sliderInactive');
    final sliderThumb = cf('sliderThumb');
    final sliderOverlay = cf('sliderOverlay');

    final dialogBg = cf('dialogBg');
    final sheetBg = cf('sheetBg');

    final snackBg = cf('snackBg');
    final snackFg = cf('snackFg');

    // Typography scaling (không đổi layout, chỉ scale font size token)
    final headerScale = (cfg.headerScale ?? 1.0).clamp(0.8, 1.6);
    final bodyScale = (cfg.bodyScale ?? 1.0).clamp(0.8, 1.6);

    TextTheme _scaleTextTheme(TextTheme t) {
      TextStyle? scale(TextStyle? s, double k) {
        if (s == null) return null;
        final fs = s.fontSize;
        return s.copyWith(
          fontSize: fs == null ? null : (fs * k),
        );
      }

      // Header = title/display, Body = body/label
      return t.copyWith(
        displayLarge: scale(t.displayLarge, headerScale),
        displayMedium: scale(t.displayMedium, headerScale),
        displaySmall: scale(t.displaySmall, headerScale),
        headlineLarge: scale(t.headlineLarge, headerScale),
        headlineMedium: scale(t.headlineMedium, headerScale),
        headlineSmall: scale(t.headlineSmall, headerScale),
        titleLarge: scale(t.titleLarge, headerScale),
        titleMedium: scale(t.titleMedium, headerScale),
        titleSmall: scale(t.titleSmall, headerScale),
        bodyLarge: scale(t.bodyLarge, bodyScale),
        bodyMedium: scale(t.bodyMedium, bodyScale),
        bodySmall: scale(t.bodySmall, bodyScale),
        labelLarge: scale(t.labelLarge, bodyScale),
        labelMedium: scale(t.labelMedium, bodyScale),
        labelSmall: scale(t.labelSmall, bodyScale),
      );
    }

    final baseText = base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final textTheme = _scaleTextTheme(baseText).copyWith(
      bodySmall:
          _scaleTextTheme(baseText).bodySmall?.copyWith(color: textSecondary),
      bodyMedium:
          _scaleTextTheme(baseText).bodyMedium?.copyWith(color: textPrimary),
      bodyLarge:
          _scaleTextTheme(baseText).bodyLarge?.copyWith(color: textPrimary),
    );

    return base.copyWith(
      useMaterial3: true,

      scaffoldBackgroundColor: background,

      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarFg),
        titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
          color: appBarFg,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomBg,
        selectedItemColor: bottomSelected,
        unselectedItemColor: bottomUnselected,
        type: BottomNavigationBarType.fixed,
      ),

      // Cards
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // Icon
      iconTheme: IconThemeData(color: iconPrimary),
      primaryIconTheme: IconThemeData(color: iconPrimary),

      // Slider
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: sliderActive,
        thumbColor: sliderThumb,
        overlayColor: sliderOverlay,
        inactiveTrackColor: sliderInactive,
      ),

      // Inputs (TextField, Search)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: inputHint),
        prefixIconColor: iconSecondary,
        suffixIconColor: iconSecondary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: (textTheme.titleMedium ?? const TextStyle()).copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: textSecondary,
        ),
      ),

      // Sheets (chủ yếu set backgroundColor tại showModalBottomSheet)
      // -> vẫn giữ token để app dùng
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: buttonFg,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: TextStyle(color: snackFg),
        actionTextColor: primary,
      ),

      // Text theme
      textTheme: textTheme.copyWith(
        titleLarge: textTheme.titleLarge?.copyWith(color: textPrimary),
        titleMedium: textTheme.titleMedium?.copyWith(color: textPrimary),
        titleSmall: textTheme.titleSmall?.copyWith(color: textPrimary),
        bodySmall: textTheme.bodySmall?.copyWith(color: textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = widget.logic;

    // ThemeConfig dùng chung, build 2 theme (light/dark) nhưng vẫn theo token của user.
    // Nếu user đang dùng ThemeMode.dark => lấy defaults(dark) làm fallback.
    final cfg = logic.settings.themeConfig;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(dark: false, cfg: cfg),
      darkTheme: _buildTheme(dark: true, cfg: cfg),
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
              icon: Icon(Icons.library_music_rounded), label: 'List'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), label: 'Setting'),
        ],
      ),
      floatingActionButton: (tab == 0)
          ? FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () => _openImportMenu(context),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _openImportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: Theme.of(context).bottomSheetTheme.shape,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.library_music_rounded),
              title: const Text('Thêm file'),
              subtitle: const Text('Chọn mp3/m4a'),
              onTap: () {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await logic.importAudioFiles();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_file_rounded),
              title: const Text('Chuyển video thành file'),
              subtitle: const Text('Chọn video → xuất .m4a vào thư viện'),
              onTap: () {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  // mở dialog progress
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AnimatedBuilder(
                      animation: logic,
                      builder: (_, __) {
                        return AlertDialog(
                          title: const Text('Đang chuyển đổi video'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(logic.convertLabel),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                  value: logic.convertProgress),
                              const SizedBox(height: 8),
                              Text(
                                  '${(logic.convertProgress * 100).toStringAsFixed(0)}%'),
                            ],
                          ),
                        );
                      },
                    ),
                  );

                  final err = await logic.importVideoToM4a();

                  if (context.mounted) Navigator.pop(context); // đóng dialog

                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(err)));
                  }
                });
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: Theme.of(context).bottomSheetTheme.shape,
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

/// ===============================
/// HOME (library) - STICKY HEROCARD + SEARCH BAR
/// ===============================
class _HomePage extends StatefulWidget {
  final AppLogic logic;
  const _HomePage({required this.logic});

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.logic.library;
    final currentId = widget.logic.currentTrack?.id;

    final filteredItems = _searchQuery.isEmpty
        ? items
        : items
            .where((t) =>
                t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.artist.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return CustomScrollView(
      slivers: [
        // ✨ HEROCARD STICKY (PINNED)
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeroDelegate(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: _FloatingHero(child: _HeroCard(logic: widget.logic)),
                ),
              ),
            ),
          ),
        ),

        // SEARCH BAR
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bài hát, nghệ sĩ...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),

        // HEADER
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                    child: Text('Thư viện',
                        style: Theme.of(context).textTheme.titleLarge)),
                if (_searchQuery.isNotEmpty)
                  Text('${filteredItems.length} kết quả',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),

        // EMPTY STATES
        if (items.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 24, left: 16, right: 16),
              child: Text('Chưa có file. Bấm nút + để thêm mp3/m4a vào app.'),
            ),
          ),

        if (items.isNotEmpty && filteredItems.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48),
                    const SizedBox(height: 8),
                    Text('Không tìm thấy "$_searchQuery"',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
          ),

        // TRACK LIST
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final t = filteredItems[index];
                final isCurrent = (currentId == t.id);
                final fav = widget.logic.favorites.contains(t.id);

                return Slidable(
                  key: ValueKey(t.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) async =>
                            await widget.logic.removeTrackFromApp(t.id),
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
                        await widget.logic.setCurrent(t.id, autoPlay: true);
                        _openNowPlaying(context, widget.logic);
                      },
                      leading: _CoverThumb(path: t.coverPath, title: t.title),
                      title: Text(t.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.artist,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✨ VISUALIZER giống HeroCard khi đang phát
                          if (isCurrent)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _AudioVisualizer(
                                isPlaying: widget
                                    .logic.handler.playbackState.value.playing,
                                barColor: Color(widget.logic.settings
                                        .themeConfig.colors['visualizerBar'] ??
                                    Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.7)
                                        .value),
                              ),
                            ),
                          IconButton(
                            tooltip: fav ? 'Bỏ thích' : 'Thích',
                            onPressed: () => widget.logic.toggleFavorite(t.id),
                            icon: Icon(fav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded),
                          ),
                          _TrackMenu(logic: widget.logic, track: t),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: filteredItems.length,
            ),
          ),
        ),
      ],
    );
  }

  void _openNowPlaying(BuildContext context, AppLogic logic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: Theme.of(context).bottomSheetTheme.shape,
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

/// ===============================
/// ✅ STICKY HEADER DELEGATE - ĐÃ FIX OVERFLOW
/// ===============================
class _StickyHeroDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeroDelegate({required this.child});

  @override
  double get minExtent => 132;

  @override
  double get maxExtent => 132;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyHeroDelegate oldDelegate) => false;
}

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

/// ===============================
/// HERO CARD - ✅ FIX PADDING ĐỂ TRÁNH OVERFLOW
/// ===============================
class _HeroCard extends StatelessWidget {
  final AppLogic logic;
  const _HeroCard({required this.logic});

  @override
  Widget build(BuildContext context) {
    final t = logic.currentTrack;
    final title = t?.title ?? 'Chưa chọn bài';
    final artist = t?.artist ?? '';
    final playing = logic.handler.playbackState.value.playing;

    final textSecondary = Color(
      logic.settings.themeConfig.colors['textSecondary'] ??
          Theme.of(context).textTheme.bodySmall?.color?.value ??
          Colors.white70.value,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _CoverThumb(path: t?.coverPath, title: title, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _AudioVisualizer(
              isPlaying: playing,
              barColor: Color(
                  logic.settings.themeConfig.colors['visualizerBar'] ??
                      Colors.grey.value),
            ),
            IconButton(
              onPressed: () async => await logic.playPause(),
              icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// ✨ AUDIO VISUALIZER - TO HƠN, CHỈ HIỆN KHI PHÁT NHẠC
/// ===============================
class _AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color barColor;
  const _AudioVisualizer({required this.isPlaying, required this.barColor});

  @override
  State<_AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<_AudioVisualizer>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    if (widget.isPlaying) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (mounted && widget.isPlaying) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopAnimations() {
    for (var controller in _controllers) {
      controller.stop();
      controller.value = 0.4;
    }
  }

  @override
  void didUpdateWidget(_AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return const SizedBox.shrink();
    }

    final barHeights = [18.0, 12.0, 20.0];

    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          return Padding(
            padding: EdgeInsets.only(right: index < 2 ? 4 : 0),
            child: AnimatedBuilder(
              animation: _animations[index],
              builder: (context, child) {
                return Container(
                  width: 4,
                  height: barHeights[index] * _animations[index].value,
                  decoration: BoxDecoration(
                    color: widget.barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

/// ===============================
/// ✨ NÚT TUA 5 GIÂY - REUSABLE WIDGET
/// ===============================
class _SeekStepButton extends StatelessWidget {
  final int seconds; // -5 = lùi, +5 = tiến
  final VoidCallback? onPressed;

  const _SeekStepButton({
    required this.seconds,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isRewind = seconds < 0;
    final s = seconds.abs();

    IconData icon;
    if (isRewind) {
      icon = (s == 5) ? Icons.replay_5_rounded : Icons.replay_rounded;
    } else {
      icon = (s == 5) ? Icons.forward_5_rounded : Icons.forward_rounded;
    }

    return IconButton(
      tooltip: isRewind ? 'Tua lùi ${s}s' : 'Tua tới ${s}s',
      onPressed: onPressed,
      iconSize: 30,
      splashRadius: 22,
      icon: Icon(icon),
    );
  }
}

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
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: Theme.of(context).bottomSheetTheme.shape,
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

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
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: Theme.of(context).bottomSheetTheme.shape,
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
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _handleBar(context),
                  const SizedBox(height: 10),
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
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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

  Widget _handleBar(BuildContext context) {
    final c = Color(
        logic.settings.themeConfig.colors['divider'] ?? Colors.white24.value);
    return Container(
      width: 40,
      height: 4,
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
    );
  }

  void _openNowPlaying(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: Theme.of(context).bottomSheetTheme.shape,
      builder: (_) => _NowPlayingSheet(logic: logic),
    );
  }
}

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
/// SETTINGS - THÊM “THEME A→Z” (đổi mọi token màu + font)
/// GIỮ NGUYÊN layout phần Setting hiện có (theme mode + title),
/// chỉ THÊM 1 Card mới phía dưới.
/// ===============================
class _SettingsPage extends StatefulWidget {
  final AppLogic logic;
  const _SettingsPage({required this.logic});

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _titleCtrl;

  // NEW: font family + sliders
  late final TextEditingController _fontCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.logic.settings.appTitle);
    _fontCtrl = TextEditingController(
        text: widget.logic.settings.themeConfig.fontFamily ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _fontCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logic = widget.logic;
    final cfg = logic.settings.themeConfig;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Setting', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),

        // Theme mode card (giữ nguyên)
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

        // App title card (giữ nguyên)
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
                        child: Text('Đổi title app',
                            style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nhập title...',
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
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.backup_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Backup & Restore',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: const Icon(Icons.archive_rounded),
                  label: const Text('Xuất backup (.zip)'),
                  onPressed: () async {
                    final path = await widget.logic.exportLibraryToZip();
                    if (!context.mounted) return;

                    if (path == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup lỗi')));
                      return;
                    }

                    // 🔥 MỞ SHARE SHEET iOS (AirDrop, Files, Zalo, v.v.)
                    await Share.shareXFiles(
                      [XFile(path)],
                      text: 'Backup thư viện nhạc',
                    );
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Import backup'),
                  onPressed: () async {
                    final err = await widget.logic.importLibraryFromZip();
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err ?? 'Khôi phục thành công'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // NEW: Theme A→Z card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Màu sắc & Font (A → Z)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final useDark =
                            (logic.settings.themeMode == ThemeMode.dark) ||
                                (logic.settings.themeMode == ThemeMode.system);
                        await logic.resetThemeToDefaults(darkDefault: useDark);
                        // update local font controller
                        _fontCtrl.text =
                            logic.settings.themeConfig.fontFamily ?? '';
                        setState(() {});
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Font family input
                Row(
                  children: [
                    const Icon(Icons.font_download_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _fontCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Font family (để trống = mặc định)',
                        ),
                        onSubmitted: (v) async {
                          await logic.setFontFamily(v);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () async {
                        await logic.setFontFamily(_fontCtrl.text);
                        setState(() {});
                      },
                      child: const Text('Áp'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Header scale
                _scaleRow(
                  context,
                  icon: Icons.text_fields_rounded,
                  title: 'Header scale',
                  value: (cfg.headerScale ?? 1.0).clamp(0.8, 1.6),
                  onChanged: (v) async {
                    await logic.setHeaderScale(v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),

                // Body scale
                _scaleRow(
                  context,
                  icon: Icons.subject_rounded,
                  title: 'Body scale',
                  value: (cfg.bodyScale ?? 1.0).clamp(0.8, 1.6),
                  onChanged: (v) async {
                    await logic.setBodyScale(v);
                    setState(() {});
                  },
                ),

                const SizedBox(height: 14),
                Divider(color: Theme.of(context).dividerTheme.color),

                const SizedBox(height: 10),
                Text(
                  'Đổi màu từng phần tử (nhấn vào ô màu):',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),

                // Grid color tokens
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ThemeConfig.keys.map((k) {
                    final col =
                        Color(cfg.colors[k] ?? Colors.transparent.value);
                    return _ColorToken(
                      label: k,
                      color: col,
                      onTap: () async {
                        final picked = await _pickColor(context, col);
                        if (picked != null) {
                          await logic.setThemeColor(k, picked);
                          setState(() {});
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _scaleRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
        SizedBox(
          width: 160,
          child: Slider(
            min: 0.8,
            max: 1.6,
            value: value,
            onChanged: (v) => onChanged(v),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 42,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color initial) async {
    // UI tối giản: RGB sliders + preview (không thêm package, giữ project gọn)
    double r = initial.red.toDouble();
    double g = initial.green.toDouble();
    double b = initial.blue.toDouble();
    double a = initial.alpha.toDouble();

    return showDialog<Color>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final col =
              Color.fromARGB(a.round(), r.round(), g.round(), b.round());
          return AlertDialog(
            title: const Text('Chọn màu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: col,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                ),
                const SizedBox(height: 10),
                _rgbSlider(ctx, 'A', a, (v) => setSt(() => a = v)),
                _rgbSlider(ctx, 'R', r, (v) => setSt(() => r = v)),
                _rgbSlider(ctx, 'G', g, (v) => setSt(() => g = v)),
                _rgbSlider(ctx, 'B', b, (v) => setSt(() => b = v)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, col),
                child: const Text('Chọn'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _rgbSlider(BuildContext context, String label, double v,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label)),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            value: v.clamp(0, 255),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            v.round().toString(),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
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

/// Token tile
class _ColorToken extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorToken({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 152,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Icon(Icons.edit_rounded, size: 16),
          ],
        ),
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
  bool _isDragging = false;

  int? _trimStartMs;
  int? _trimEndMs;

  void _openTrimPopup(BuildContext context, TrackRow track, AppLogic logic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: Theme.of(context).bottomSheetTheme.shape,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.cut_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cắt phân đoạn yêu thích',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTrimControls(context, track, logic),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = widget.logic;
    final track = logic.currentTrack;

    final title = track?.title ?? 'Chưa chọn bài';
    final artist = track?.artist ?? '';
    final duration = logic.currentDuration;
    final playing = logic.handler.playbackState.value.playing;

    final fav = track != null && logic.favorites.contains(track.id);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _handleBar(context),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Đang phát',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      if (track != null)
                        IconButton(
                          tooltip: 'Cắt phân đoạn',
                          onPressed: () =>
                              _openTrimPopup(context, track, logic),
                          icon: const Icon(Icons.cut_rounded),
                        ),
                      if (track != null) _TrackMenu(logic: logic, track: track),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    GestureDetector(
                      onHorizontalDragEnd: (d) async {
                        final v = d.primaryVelocity ?? 0;
                        if (v < -200) {
                          await logic.next();
                        } else if (v > 200) {
                          await logic.previous();
                        }
                      },
                      child: _BigCover(path: track?.coverPath, title: title),
                    ),
                    const SizedBox(height: 12),
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(artist,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Color(logic.settings.themeConfig
                                    .colors['textSecondary'] ??
                                Colors.white70.value)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    _buildSeekBar(duration),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous',
                          onPressed: () async => await logic.previous(),
                          iconSize: 32,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        const SizedBox(width: 4),
                        _SeekStepButton(
                          seconds: -5,
                          onPressed: track == null
                              ? null
                              : () => widget.logic
                                  .seekRelative(const Duration(seconds: -5)),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            shape: const CircleBorder(),
                          ),
                          onPressed: () async => await logic.playPause(),
                          child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 32),
                        ),
                        const SizedBox(width: 8),
                        _SeekStepButton(
                          seconds: 5,
                          onPressed: track == null
                              ? null
                              : () => widget.logic
                                  .seekRelative(const Duration(seconds: 5)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Next',
                          onPressed: () async => await logic.next(),
                          iconSize: 32,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                              : Color(logic.settings.themeConfig
                                      .colors['iconSecondary'] ??
                                  Colors.white70.value),
                        ),
                        IconButton(
                          tooltip: 'Loop one',
                          onPressed: () async => await logic.toggleLoopOne(),
                          icon: Icon(Icons.repeat_one_rounded,
                              color: logic.loopOne
                                  ? Theme.of(context).colorScheme.primary
                                  : Color(logic.settings.themeConfig
                                          .colors['iconSecondary'] ??
                                      Colors.white70.value)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimControls(
      BuildContext context, TrackRow track, AppLogic logic) {
    final hasStart = _trimStartMs != null;
    final hasEnd = _trimEndMs != null;

    return Card(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cut_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Tạo phân đoạn yêu thích',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      setState(() {
                        _trimStartMs = logic.position.inMilliseconds;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.start_rounded, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          hasStart ? _fmtMs(_trimStartMs!) : 'Đánh dấu đầu',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      setState(() {
                        _trimEndMs = logic.position.inMilliseconds;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stop_rounded, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          hasEnd ? _fmtMs(_trimEndMs!) : 'Đánh dấu cuối',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (hasStart || hasEnd) const SizedBox(height: 8),
            if (hasStart || hasEnd)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _trimStartMs = null;
                        _trimEndMs = null;
                      });
                    },
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Xoá'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: (hasStart && hasEnd)
                        ? () => _saveSegment(context, track, logic)
                        : null,
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Lưu'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _saveSegment(
      BuildContext context, TrackRow track, AppLogic logic) async {
    if (_trimStartMs == null || _trimEndMs == null) return;

    final start = _trimStartMs!;
    final end = _trimEndMs!;

    if (start >= end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Điểm đầu phải nhỏ hơn điểm cuối')),
      );
      return;
    }

    final nameCtrl =
        TextEditingController(text: 'Đoạn ${_fmtMs(start)} - ${_fmtMs(end)}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tên phân đoạn'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'VD: Solo hay nhất',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;

      await logic.addFavoriteSegment(
        trackId: track.id,
        name: name,
        startMs: start,
        endMs: end,
      );

      setState(() {
        _trimStartMs = null;
        _trimEndMs = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu phân đoạn yêu thích')),
        );
      }
    }
  }

  Widget _buildSeekBar(Duration duration) {
    final durMs = math.max(duration.inMilliseconds, 1).toDouble();

    return StreamBuilder<Duration>(
      stream: widget.logic.handler.player.positionStream,
      builder: (_, snap) {
        final dragging = _isDragging && _dragValue != null;

        final pos = dragging
            ? Duration(milliseconds: _dragValue!.round())
            : (snap.data ?? Duration.zero);

        final sliderValue =
            dragging ? _dragValue! : pos.inMilliseconds.toDouble();

        final clamped = sliderValue.clamp(0.0, durMs);

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
                  Text(
                    _fmt(Duration(milliseconds: clamped.round())),
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _fmt(duration),
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _handleBar(BuildContext context) {
    final c = Theme.of(context).dividerColor;
    return Container(
      width: 40,
      height: 4,
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
    );
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    return _fmt(d);
  }
}

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

class _FloatingHero extends StatelessWidget {
  final Widget child;
  const _FloatingHero({required this.child});

  @override
  Widget build(BuildContext context) {
    // shadow color có token nhưng không ép vì UI này là "floating",
    // vẫn lấy từ themeConfig đã map vào CardTheme.shadowColor.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            spreadRadius: 2,
            offset: const Offset(0, 10),
            color: Theme.of(context).cardTheme.shadowColor ??
                Colors.black.withOpacity(0.45),
          ),
        ],
      ),
      child: child,
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
