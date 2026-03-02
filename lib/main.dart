import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_navbar/liquid_navbar.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mpt/firebase_options.dart';
import 'package:my_mpt/core/services/fcm_firestore_service.dart';
import 'package:my_mpt/core/services/notification_service.dart';
import 'package:my_mpt/core/services/rustore_update_ui.dart';
import 'package:my_mpt/core/utils/date_formatter.dart';

import 'package:my_mpt/presentation/screens/calls_screen.dart';
import 'package:my_mpt/presentation/screens/overview_screen.dart';
import 'package:my_mpt/presentation/screens/schedule_screen.dart';
import 'package:my_mpt/presentation/widgets/overview/page_indicator.dart';
import 'package:my_mpt/presentation/screens/settings_screen.dart';
import 'package:my_mpt/presentation/screens/welcome_screen.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Инициализируем Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    if (!kIsWeb) {
      FcmFirestoreService.registerBackgroundHandler();
      final notificationService = NotificationService();
      await notificationService.initialize();
      final fcmService = FcmFirestoreService();
      await fcmService.initialize();
      await fcmService.syncTokenWithGroup();
    }

    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  }, (e, st) {
    if (kDebugMode) {
      print('Uncaught error: $e');
      print(st);
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мой МПТ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF8C00),
          secondary: Color(0xFFFFA500),
          tertiary: Color(0xFFFFB347),
          surface: Color(0xFF121212),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  bool _isFirstLaunch = true;
  bool _isLoading = true;
  bool _updateChecked = false;

  late final List<Widget> _screens = <Widget>[
    OverviewScreen(forcedPage: 0),
    OverviewScreen(forcedPage: 1),
    const ScheduleScreen(),
    const CallsScreen(),
    const SettingsScreen(),
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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

    final isNumerator = DateFormatter.getWeekType(DateTime.now()) == 'Числитель';
    final Color activeColor =
        isNumerator ? const Color(0xFFFF8C00) : const Color(0xFF42A5F5);
        
    final bool isIOS = !kIsWeb && Platform.isIOS;
    final double indicatorBottomOffset = isIOS ? 100 : 80;

    // Для Android используем BottomNavScaffold из liquid_navbar
    if (!kIsWeb && Platform.isAndroid) {
      return Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            BottomNavScaffold(
              pages: [
                _screens[0], // Обзор
                _screens[2], // Неделя
                _screens[3], // Звонки
                _screens[4], // Настройки
              ],
              icons: _navItems.map((item) => Icon(item.icon)).toList(),
              labels: _navItems.map((item) => item.label).toList(),
              navbarHeight: 70,
              indicatorWidth: 70,
              bottomPadding: 8,
              horizontalPadding: 24,
              selectedColor: activeColor,
              unselectedColor: Colors.grey.shade400,
            ),
            // Индикатор страниц "Сегодня / Завтра" нужен только на экране "Обзор"
            // Но в liquid_navbar страницы сменяются через Riverpod, 
            // так что для простоты покажем его просто поверх всего. 
            // Идеально было бы связать его с состоянием навбара.
          ],
        ),
      );
    }

    // Для iOS оставляем NativeGlassNavBar (так как он идеально повторяет iOS-стиль)
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            children: _screens,
          ),
          if (_currentIndex == 0 || _currentIndex == 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + indicatorBottomOffset,
              child: IgnorePointer(
                child: PageIndicator(currentPageIndex: _currentIndex),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NativeGlassNavBar(
        currentIndex: selectedNavIndex,
        tintColor: activeColor,
        onTap: (index) {
          if (index == 0) {
            _goToPage(0);
          } else {
            _goToPage(index + 1);
          }
        },
        tabs: [
          for (final item in _navItems)
            NativeGlassNavBarItem(
              label: item.label,
              symbol: item.sfSymbol,
            ),
        ],
      ),
    );
  }
}
