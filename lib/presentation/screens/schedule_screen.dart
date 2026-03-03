import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_mpt/core/utils/date_formatter.dart';
import 'package:my_mpt/data/repositories/schedule_repository.dart';
import 'package:my_mpt/domain/entities/schedule.dart';
import 'package:my_mpt/presentation/screens/teacher_schedule_screen.dart';
import 'package:my_mpt/presentation/widgets/schedule/day_section.dart';
import 'package:my_mpt/presentation/widgets/schedule/lesson_detail_sheet.dart';

import 'package:my_mpt/presentation/widgets/settings/info_notification.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State {
  static const _backgroundColor = Color(0xFF000000);
  static const Color _lessonAccent = Colors.grey;

  late final ScheduleRepository _repository;

  Map<String, List<Schedule>> _weeklySchedule = {};
  bool _isLoading = false;
  bool _isStudent = true;

  bool _isOffline = false;
  bool _autoOfflineNotified = false;

  static const String _selectedRoleKey = 'selected_role';

  @override
  void initState() {
    super.initState();

    _repository = ScheduleRepository();
    _repository.dataUpdatedNotifier.addListener(_onDataUpdated);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_selectedRoleKey) ?? 'student';
      if (mounted) setState(() => _isStudent = role == 'student');
      _initializeSchedule();
    });
  }

  void _onLessonTap(Schedule lesson, {String? startTime, String? endTime}) {
    if (lesson.teacher.trim().isEmpty) return;
    showLessonDetailSheet(
      context,
      lesson: lesson,
      startTime: startTime,
      endTime: endTime,
      onViewTeacherSchedule: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => TeacherScheduleScreen(teacherName: lesson.teacher),
          ),
        );
      },
    );
  }

  Future _initializeSchedule() async {
    await _loadScheduleData(forceRefresh: false, showLoader: true, userInitiated: false);
    await _loadScheduleData(forceRefresh: true, showLoader: false, userInitiated: false);
  }

  void _onDataUpdated() {
    _loadScheduleData(forceRefresh: false, showLoader: false, userInitiated: false);
  }

  void _showOfflineBanner({required bool userInitiated}) {
    if (!userInitiated && _autoOfflineNotified) return;
    _autoOfflineNotified = true;

    showInfoNotification(
      context,
      'Нет интернета',
      'Показано последнее сохранённое расписание',
      Icons.info_outline,
    );
  }

  Future _loadScheduleData({
    required bool forceRefresh,
    bool showLoader = true,
    bool userInitiated = false,
  }) async {
    if (showLoader) setState(() => _isLoading = true);

    bool? refreshOk;

    try {
      if (forceRefresh) {
        refreshOk = await _repository.forceRefreshWithStatus();
      }

      final weekly = await _repository.getWeeklySchedule();
      if (!mounted) return;

      setState(() {
        _weeklySchedule = weekly;
        _isOffline = refreshOk == null ? _repository.isOfflineBadgeVisible : !refreshOk;
        if (showLoader) _isLoading = false;
      });

      if (forceRefresh && refreshOk == false && mounted) {
        _showOfflineBanner(userInitiated: userInitiated);
      }
    } catch (_) {
      if (!mounted) return;
      if (showLoader) setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки расписания')),
      );
    }
  }

  List<Color> _getHeaderGradient(String weekType) {
    if (weekType == 'Знаменатель') {
      return const [Color(0xFF111111), Color(0xFF4FC3F7)];
    } else if (weekType == 'Числитель') {
      return const [Color(0xFF111111), Color(0xFFFF8C00)];
    } else {
      return const [Color(0xFF111111), Color(0xFF333333)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInitialLoading = _isLoading && _weeklySchedule.isEmpty;
    final days = _weeklySchedule.entries.toList();

    final now = DateTime.now();
    final weekType = DateFormatter.getWeekType(now) ?? '';
    final dateLabel = DateFormatter.formatDayWithMonth(now);

    const headerMaxHeight = 176.0;
    const headerMinHeight = 88.0;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: isInitialLoading
          ? const SafeArea(
              bottom: false,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          : Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: RefreshIndicator(
                    onRefresh: () => _loadScheduleData(forceRefresh: true, userInitiated: true),
                    color: Colors.white,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // Оптимизация физики скролла
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _HeightPinnedHeaderDelegate(
                            backgroundColor: _backgroundColor,
                            maxHeight: headerMaxHeight,
                            minHeight: headerMinHeight,
                            child: _CollapsibleWeekHeader(
                              maxHeight: headerMaxHeight,
                              minHeight: headerMinHeight,
                              title: 'Неделя',
                              dateLabel: dateLabel,
                              weekType: weekType,
                              gradient: _getHeaderGradient(weekType),
                              isOffline: _isOffline,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(0, 24, 0, 110),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final day = days[index];
                                final building = _primaryBuilding(day.value);

                                return DaySection(
                                  title: day.key,
                                  building: building,
                                  lessons: day.value,
                                  accentColor: _lessonAccent,
                                  weekType: weekType,
                                  onLessonTap: _isStudent ? _onLessonTap : null,
                                );
                              },
                              childCount: days.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _primaryBuilding(List<Schedule> schedule) {
    if (schedule.isEmpty) return '';

    final Map<String, int> counts = {};
    for (final lesson in schedule) {
      counts[lesson.building] = (counts[lesson.building] ?? 0) + 1;
    }

    String primary = schedule.first.building;
    int maxCount = 0;

    counts.forEach((building, count) {
      if (count > maxCount) {
        maxCount = count;
        primary = building;
      }
    });

    return primary;
  }

  @override
  void dispose() {
    _repository.dataUpdatedNotifier.removeListener(_onDataUpdated);
    super.dispose();
  }
}

class _HeightPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeightPinnedHeaderDelegate({
    required this.backgroundColor,
    required this.maxHeight,
    required this.minHeight,
    required this.child,
  });

  final Color backgroundColor;
  final double maxHeight;
  final double minHeight;
  final Widget child;

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _HeightPinnedHeaderDelegate old) {
    return old.backgroundColor != backgroundColor ||
        old.maxHeight != maxHeight ||
        old.minHeight != minHeight ||
        old.child != child;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Убрали BackdropFilter и ClipRect (блюр), так как они вызывают сильный jank в Impeller iOS
    return ColoredBox(
      color: backgroundColor, // Статичный фон вместо блюра для производительности 120Hz
      child: child,
    );
  }
}

class _CollapsibleWeekHeader extends StatelessWidget {
  const _CollapsibleWeekHeader({
    required this.maxHeight,
    required this.minHeight,
    required this.title,
    required this.dateLabel,
    required this.weekType,
    required this.gradient,
    required this.isOffline,
  });

  final double maxHeight;
  final double minHeight;
  final String title;
  final String dateLabel;
  final String weekType;
  final List<Color> gradient;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.clamp(minHeight, maxHeight);
        final t = ((maxHeight - h) / (maxHeight - minHeight)).clamp(0.0, 1.0);
        final tCurved = Curves.easeOutCubic.transform(t);

        final radius = lerpDouble(32, 18, tCurved)!;
        final padH = lerpDouble(20, 14, tCurved)!;
        final padTop = lerpDouble(18, 10, tCurved)!;
        final padBottom = lerpDouble(18, 10, tCurved)!;

        final titleSize = lerpDouble(28, 18, tCurved)!;
        final dateSize = lerpDouble(16, 13, tCurved)!;

        final pillFont = lerpDouble(13, 11, tCurved)!;
        final pillPH = lerpDouble(14, 10, tCurved)!;
        final pillPV = lerpDouble(6, 4, tCurved)!;

        final gapTitleDate = lerpDouble(4, 4, tCurved)!;
        final gapPillIcon = 10.0;
        final estimatedPillHeight = pillFont + (pillPV * 2) + 6;
        final reservedTop = estimatedPillHeight + gapPillIcon;

        final iconSize = lerpDouble(18, 14, tCurved)!;

        final pill = _WeekTypePill(
          text: weekType,
          fontSize: pillFont,
          padH: pillPH,
          padV: pillPV,
        );

        final isCompact = tCurved > 0.5;
        final displayTitle = isCompact ? weekType : title;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            // Уменьшено количество теней для оптимизации
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: lerpDouble(0.3, 0.1, tCurved)!),
                blurRadius: lerpDouble(15, 6, tCurved)!,
                offset: Offset(0, lerpDouble(8, 2, tCurved)!),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(padH, padTop, padH, padBottom),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isCompact)
                  Align(
                    alignment: Alignment(lerpDouble(-1.0, 0.0, tCurved)!, 0.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: gapTitleDate),
                        Text(
                          dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: dateSize,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...[
                    Align(
                      alignment: Alignment.topLeft,
                      child: pill,
                    ),
                    Align(
                      alignment: const Alignment(-1.0, -0.35),
                      child: Padding(
                        padding: EdgeInsets.only(right: iconSize + 12, top: reservedTop),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: gapTitleDate),
                            Text(
                              dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: dateSize,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                Align(
                  alignment: const Alignment(1.0, 0.0),
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: Opacity(
                      opacity: isOffline ? 1.0 : 0.0,
                      child: Icon(
                        Icons.wifi_off,
                        size: iconSize,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WeekTypePill extends StatelessWidget {
  const _WeekTypePill({
    required this.text,
    required this.fontSize,
    required this.padH,
    required this.padV,
  });

  final String text;
  final double fontSize;
  final double padH;
  final double padV;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
    );
  }
}
