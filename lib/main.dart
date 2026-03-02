import 'dart:async';
import 'dart:ui'; // Для ImageFilter.blur

import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    
    // Инициализируем Firebase (работает на всех платформах, если настроено)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // FCM, локальные уведомления и Rustore могут вызывать краши на Web, 
    // поэтому отключаем их вызов при запуске в браузере (для Device Preview)
    if (!kIsWeb) {
      FcmFirestoreService.registerBackgroundHandler();
      final notificationService = NotificationService();
      await notificationService.initialize();
      final fcmService = FcmFirestoreService();
      await fcmService.initialize();
      await fcmService.syncTokenWithGroup();
    }

    runApp(
      DevicePreview(
        enabled: kDebugMode,
        builder: (context) => const MyApp(),
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
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
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
    _NavItemData(icon: Icons.flash_on_outlined, selectedIcon: Icons.flash_on, label: 'Обзор'),
    _NavItemData(icon: Icons.view_week_outlined, selectedIcon: Icons.view_week, label: 'Неделя'),
    _NavItemData(icon: Icons.notifications_none_outlined, selectedIcon: Icons.notifications, label: 'Звонки'),
    _NavItemData(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Настройки'),
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
    
    // Определяем текущий тип недели (Числитель / Знаменатель)
    final isNumerator = DateFormatter.getWeekType(DateTime.now()) == 'Числитель';
    final Color activeColor = isNumerator ? const Color(0xFFEF5350) : const Color(0xFF42A5F5); // Красный для числителя, Синий для знаменателя

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
              bottom: MediaQuery.of(context).padding.bottom + 90,
              child: IgnorePointer(
                child: PageIndicator(currentPageIndex: _currentIndex),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5), // Высокая прозрачность для правильного блюра
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2), // Тонкая граница усиливает эффект стекла
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(35),
                  ),
                  child: Stack(
                    children: [
                      // Анимированный фон (овал) для выбранного элемента
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        left: _calculateIndicatorPosition(selectedNavIndex, context),
                        top: 6,
                        bottom: 6,
                        width: _calculateIndicatorWidth(context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: activeColor.withOpacity(0.25), // Цвет подложки привязан к неделе
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                      // Сами кнопки
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(_navItems.length, (index) {
                          final isSelected = selectedNavIndex == index;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (index == 0) _goToPage(0);
                                else _goToPage(index + 1);
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isSelected ? _navItems[index].selectedIcon : _navItems[index].icon,
                                    color: isSelected ? activeColor : const Color(0xFF4A3525), // Цвет иконки привязан к неделе
                                    size: 26,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _navItems[index].label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? activeColor : const Color(0xFF4A3525), // Цвет текста привязан к неделе
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateIndicatorWidth(BuildContext context) {
    // Ширина экрана минус отступы по краям (24 * 2) делить на количество элементов
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 48; 
    return availableWidth / _navItems.length;
  }

  double _calculateIndicatorPosition(int index, BuildContext context) {
    return index * _calculateIndicatorWidth(context);
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItemData({
    required this.icon, 
    required this.selectedIcon, 
    required this.label
  });
}
