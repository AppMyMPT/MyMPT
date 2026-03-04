import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
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
    
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }

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

  List<Color> _getHeaderGradient(String weekType, {required bool isDark}) {
    final base = isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5);

    if (weekType == 'Знаменатель') {
      return [base, const Color(0xFF4FC3F7)];
    } else if (weekType == 'Числитель') {
      return [base, const Color(0xFFFF8C00)];
    } else {
      return [base, isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInitialLoading = _isLoading && _weeklySchedule.isEmpty;
    final days = _weeklySchedule.entries.toList();

    final now = DateTime.now();
    final weekType = DateFormatter.getWeekType(now);
    final dateLabel = DateFormatter.formatDayWithMonth(now);

    final bg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const headerMaxHeight = 176.0;
    const headerMinHeight = 88.0;

    return Scaffold(
      backgroundColor: bg,
      body: isInitialLoading
          ? SafeArea(
              bottom: false,
              child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
            )
          : RefreshIndicator(
              onRefresh: () async {
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                  HapticFeedback.lightImpact();
                }
                await _loadScheduleData(forceRefresh: true, userInitiated: true);
              },
              color: Theme.of(context).colorScheme.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HeightPinnedHeaderDelegate(
                      backgroundColor: bg,
                      maxHeight: headerMaxHeight + MediaQuery.of(context).padding.top,
                      minHeight: headerMinHeight + MediaQuery.of(context).padding.top,
                      paddingTop: MediaQuery.of(context).padding.top,
                      child: _CollapsibleWeekHeader(
                        maxHeight: headerMaxHeight,
                        minHeight: headerMinHeight,
                        title: 'Неделя',
                        dateLabel: dateLabel,
                        weekType: weekType,
                        gradient: _getHeaderGradient(weekType, isDark: isDark),
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
    required this.paddingTop,
    required this.child,
  });

  final Color backgroundColor;
  final double maxHeight;
  final double minHeight;
  final double paddingTop;
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
        old.paddingTop != paddingTop ||
        old.child != child;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = (maxHeight - minHeight).abs() < 1 ? 1.0 : (maxHeight - minHeight);
    final t = (shrinkOffset / range).clamp(0.0, 1.0);

    final blurSigma = lerpDouble(0, 20, Curves.easeOut.transform(t))!;
    final baseAlpha = backgroundColor.a;
    final overlayAlpha = lerpDouble(baseAlpha, baseAlpha * 0.4, Curves.easeOut.transform(t))!;
    
    final extraBlurPadding = 20.0; // Extend blur slightly below the top padding 

    return Stack(
      fit: StackFit.expand,
      children: [
        if (t == 0.0)
          ColoredBox(color: backgroundColor),

        if (t > 0.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: paddingTop + lerpDouble(16, 8 + extraBlurPadding, Curves.easeOutCubic.transform(t))!,
            child: blurSigma > 0.1
                ? ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                      child: ColoredBox(
                        color: backgroundColor.withAlpha((overlayAlpha * 255).toInt()),
                      ),
                    ),
                  )
                : ColoredBox(color: backgroundColor.withAlpha((overlayAlpha * 255).toInt())),
          ),

        Padding(
          padding: EdgeInsets.only(top: paddingTop),
          child: child,
        ),
      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    
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
          margin: EdgeInsets.fromLTRB(16, lerpDouble(16, 8, tCurved)!, 16, lerpDouble(0, 8, tCurved)!),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: lerpDouble(isDark ? 0.3 : 0.1, isDark ? 0.1 : 0.05, tCurved)!),
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
                            color: titleColor,
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
                            color: subColor,
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
                                color: titleColor,
                              ),
                            ),
                            SizedBox(height: gapTitleDate),
                            Text(
                              dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: dateSize,
                                color: subColor,
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
                        color: titleColor.withValues(alpha: 0.85),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final border = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final fg = isDark ? Colors.white : Colors.black87;

    final radius = BorderRadius.circular(14);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(color: border),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
