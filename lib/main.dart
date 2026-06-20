import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mpt/firebase_options.dart';
import 'package:my_mpt/core/services/fcm_firestore_service.dart';
import 'package:my_mpt/core/services/notification_service.dart';
import 'package:my_mpt/core/services/rustore_update_ui.dart';
import 'package:my_mpt/core/services/app_theme_service.dart';
import 'package:my_mpt/core/utils/date_formatter.dart';

import 'package:my_mpt/presentation/screens/calls_screen.dart';
import 'package:my_mpt/presentation/screens/overview_screen.dart';
import 'package:my_mpt/presentation/screens/schedule_screen.dart';
import 'package:my_mpt/presentation/widgets/overview/page_indicator.dart';
import 'package:my_mpt/presentation/screens/settings_screen.dart';
import 'package:my_mpt/presentation/screens/welcome_screen.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Инициализируем Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!kIsWeb) {
        FcmFirestoreService.registerBackgroundHandler();
        final notificationService = NotificationService();
        await notificationService.initialize();
        final fcmService = FcmFirestoreService();
        await fcmService.initialize();
        await fcmService.syncTokenWithGroup();
      }

      await AppThemeService.init();

      runApp(const MyApp());
    },
    (e, st) {
      if (kDebugMode) {
        print('Uncaught error: $e');
        print(st);
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(0xFF000000),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF8C00),
        secondary: Color(0xFFFFA500),
        tertiary: Color(0xFFFFB347),
        surface: Color(0xFF111111),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: const Color(0x33FFFFFF),
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white70,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            letterSpacing: 0.1,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white60,
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const cs = ColorScheme.light(
      primary: Color(0xFFFF8C00),
      secondary: Color(0xFFFFA500),
      tertiary: Color(0xFFFFB347),
      surface: Color(
        0xFFF5F5F5,
      ), // Сопоставляем 0xFF111111 из темной с 0xFFF5F5F5 в светлой
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: const Color(
        0xFFFFFFFF,
      ), // Сопоставляем 0xFF000000 из темной с 0xFFFFFFFF в светлой
      colorScheme: cs,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
      appBarTheme: const AppBarTheme(
        foregroundColor: Colors.black87,
        elevation: 0,
        backgroundColor: Color(0xFFFFFFFF), // Белый фон
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFF5F5F5),
        indicatorColor: Colors.black.withOpacity(0.06),
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light = _buildLightTheme();
    final dark = _buildDarkTheme();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeService.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Мой МПТ',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          home: const MainScreen(),
        );
      },
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String sfSymbol;

  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.sfSymbol,
  });
}

/// Keeps the expensive iOS platform view alive when an unrelated part of the
/// main scaffold rebuilds (for example, the overview page indicator).
class _StableNativeNavBar extends StatefulWidget {
  final int currentIndex;
  final Color tintColor;
  final ValueChanged<int> onTap;
  final List<_NavItemData> items;

  const _StableNativeNavBar({
    required this.currentIndex,
    required this.tintColor,
    required this.onTap,
    required this.items,
  });

  @override
  State<_StableNativeNavBar> createState() => _StableNativeNavBarState();
}

class _StableNativeNavBarState extends State<_StableNativeNavBar> {
  Widget? _cachedNavBar;
  int? _cachedIndex;
  Color? _cachedTintColor;
  Brightness? _cachedBrightness;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_cachedNavBar == null ||
        _cachedIndex != widget.currentIndex ||
        _cachedTintColor != widget.tintColor ||
        _cachedBrightness != brightness) {
      _cachedIndex = widget.currentIndex;
      _cachedTintColor = widget.tintColor;
      _cachedBrightness = brightness;
      _cachedNavBar = NativeGlassNavBar(
        currentIndex: widget.currentIndex,
        tintColor: widget.tintColor,
        onTap: widget.onTap,
        fallback: CupertinoTabBar(
          currentIndex: widget.currentIndex,
          onTap: widget.onTap,
          activeColor: widget.tintColor,
          inactiveColor: CupertinoDynamicColor.resolve(
            CupertinoColors.inactiveGray,
            context,
          ),
          backgroundColor: CupertinoDynamicColor.resolve(
            CupertinoColors.systemGrey6,
            context,
          ),
          border: Border(
            top: BorderSide(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.separator,
                context,
              ),
              width: 0,
            ),
          ),
          items: [
            for (final item in widget.items)
              BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
        tabs: [
          for (final item in widget.items)
            NativeGlassNavBarItem(label: item.label, symbol: item.sfSymbol),
        ],
      );
    }
    return _cachedNavBar!;
  }
}

/// Retains an already visited page and its raster cache while it is outside
/// the PageView viewport. This avoids rebuilding data-heavy screens mid-swipe.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  bool _isModalSheetVisible = false;

  bool _isFirstLaunch = true;
  bool _isLoading = true;
  bool _updateChecked = false;

  late final List<Widget> _screens = <Widget>[
    const _KeepAlivePage(child: OverviewScreen(forcedPage: 0)),
    const _KeepAlivePage(child: OverviewScreen(forcedPage: 1)),
    const _KeepAlivePage(child: ScheduleScreen()),
    const _KeepAlivePage(child: CallsScreen()),
    _KeepAlivePage(
      child: SettingsScreen(onModalVisibilityChanged: _setModalSheetVisibility),
    ),
  ];

  final List<_NavItemData> _navItems = const [
    _NavItemData(
      icon: Icons.flash_on_outlined,
      selectedIcon: Icons.flash_on,
      label: 'Обзор',
      sfSymbol: 'bolt.fill',
    ),
    _NavItemData(
      icon: Icons.view_week_outlined,
      selectedIcon: Icons.view_week,
      label: 'Неделя',
      sfSymbol: 'calendar',
    ),
    _NavItemData(
      icon: Icons.notifications_none_outlined,
      selectedIcon: Icons.notifications,
      label: 'Звонки',
      sfSymbol: 'bell',
    ),
    _NavItemData(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Настройки',
      sfSymbol: 'gearshape',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('first_launch') ?? true;

    if (!mounted) return;
    setState(() {
      _isFirstLaunch = isFirstLaunch;
      _isLoading = false;
    });
  }

  Future<void> _onSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);

    if (!mounted) return;
    setState(() {
      _isFirstLaunch = false;
    });
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _screens.length) return;
    if (index == _currentIndex) return;
    _pageController.jumpToPage(index);
    setState(() => _currentIndex = index);
  }

  void _setModalSheetVisibility(bool isVisible) {
    if (!mounted || _isModalSheetVisible == isVisible) return;
    setState(() => _isModalSheetVisible = isVisible);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_isFirstLaunch) {
      return WelcomeScreen(
        onSetupComplete: () {
          _onSetupComplete();
        },
      );
    }

    if (!_updateChecked) {
      _updateChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!kIsWeb) {
          RuStoreUpdateUi.checkAndRunDeferredUpdate();
        }
      });
    }

    final int selectedNavIndex = _currentIndex <= 1 ? 0 : _currentIndex - 1;
    void handleNavTap(int index) {
      if (index == 0) {
        _goToPage(0);
      } else {
        _goToPage(index + 1);
      }
    }

    final isNumerator =
        DateFormatter.getWeekType(DateTime.now()) == 'Числитель';
    final Color activeColor = isNumerator
        ? const Color(0xFFFF8C00)
        : const Color(0xFF42A5F5);

    final bool isIOS = !kIsWeb && Platform.isIOS;
    final double indicatorBottomOffset = isIOS ? 60 : (80 + 10);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? bottomNavigationBar;

    if (isIOS) {
      if (!_isModalSheetVisible) {
        bottomNavigationBar = _StableNativeNavBar(
          currentIndex: selectedNavIndex,
          tintColor: activeColor,
          onTap: handleNavTap,
          items: _navItems,
        );
      }
    } else {
      bottomNavigationBar = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: Theme.of(context).navigationBarTheme.copyWith(
              indicatorColor: isDark
                  ? activeColor.withOpacity(0.25)
                  : activeColor.withOpacity(0.15),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? (isDark ? Colors.white : activeColor)
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 11,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w600
                      : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: states.contains(WidgetState.selected)
                      ? (isDark ? Colors.white : activeColor)
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedNavIndex,
            onDestinationSelected: handleNavTap,
            surfaceTintColor: Colors.transparent,
            destinations: [
              for (final item in _navItems)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
            ],
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              allowImplicitScrolling: true,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              children: _screens,
            ),
            if (_currentIndex == 0 || _currentIndex == 1)
              Positioned(
                left: 0,
                right: 0,
                bottom:
                    MediaQuery.of(context).padding.bottom +
                    indicatorBottomOffset,
                child: IgnorePointer(
                  child: PageIndicator(currentPageIndex: _currentIndex),
                ),
              ),
          ],
        ),
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
