import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_mpt/core/utils/calls_util.dart';
import 'package:my_mpt/core/utils/date_formatter.dart';
import 'package:my_mpt/core/utils/lesson_details_parser.dart';
import 'package:my_mpt/data/repositories/replacement_repository.dart';
import 'package:my_mpt/data/repositories/schedule_repository.dart';
import 'package:my_mpt/domain/entities/replacement.dart';
import 'package:my_mpt/domain/entities/schedule.dart';
import 'package:my_mpt/presentation/screens/teacher_schedule_screen.dart';
import 'package:my_mpt/presentation/widgets/overview/page_indicator.dart';
import 'package:my_mpt/presentation/widgets/overview/replacement_card.dart';
import 'package:my_mpt/presentation/widgets/schedule/lesson_detail_sheet.dart';
import 'package:my_mpt/presentation/widgets/shared/break_indicator.dart';
import 'package:my_mpt/presentation/widgets/shared/lesson_card.dart';
import 'package:my_mpt/presentation/widgets/shared/location.dart';

import 'package:my_mpt/presentation/widgets/settings/info_notification.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key, this.innerPageRequest, this.forcedPage});

  final ValueNotifier<int>? innerPageRequest;
  final int? forcedPage;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  static const backgroundColor = Color(0xFF000000);
  static const Color lessonAccent = Colors.grey;

  late final ScheduleRepository repository;
  late final ReplacementRepository changesRepository;

  List<Schedule> todayScheduleData = const [];
  List<Schedule> tomorrowScheduleData = const [];
  List<Replacement> scheduleChanges = const [];

  bool isLoading = false;
  bool isOffline = false;
  bool _autoOfflineNotified = false;
  bool _isStudent = true;

  static const String _selectedRoleKey = 'selected_role';

  late final PageController pageController;
  late final ValueNotifier<int> _pageRequest;
  late final bool _ownsPageRequest;

  int currentPageIndex = 0;

  static const Map<String, String> _buildingToAddress = {
    'нежинская': 'Нежинская улица, 7, Москва',
    'нахимовский': 'Нахимовский проспект, 21, Москва',
  };

  bool _canOpenBuilding(String label) {
    final key = label.trim().toLowerCase();
    return _buildingToAddress.containsKey(key);
  }

  Uri _mapsUriForAddress(String address) {
    final q = Uri.encodeComponent(address);
    if (Platform.isAndroid) {
      return Uri.parse('geo:0,0?q=$q');
    }
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
  }

  Future<void> _openBuildingInMaps(BuildContext context, String label) async {
    final key = label.trim().toLowerCase();
    final address = _buildingToAddress[key];
    if (address == null) return;
    final uri = _mapsUriForAddress(address);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть карты')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final useInnerPageView = widget.forcedPage == null;
    _ownsPageRequest = useInnerPageView && widget.innerPageRequest == null;
    _pageRequest = widget.innerPageRequest ?? ValueNotifier<int>(0);
    currentPageIndex = (widget.forcedPage ?? _pageRequest.value).clamp(0, 1);
    pageController = PageController(initialPage: currentPageIndex);

    if (useInnerPageView) _pageRequest.addListener(_onExternalPageRequest);

    repository = ScheduleRepository();
    changesRepository = ReplacementRepository();

    repository.dataUpdatedNotifier.addListener(onDataUpdated);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_selectedRoleKey) ?? 'student';
      if (mounted) setState(() => _isStudent = role == 'student');
      initializeSchedule();
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

  void _onExternalPageRequest() {
    final target = _pageRequest.value.clamp(0, 1);
    if (!mounted) return;
    if (currentPageIndex == target) return;

    if (!pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!pageController.hasClients) return;
        if (currentPageIndex == target) return;

        setState(() => currentPageIndex = target);
        pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      });
      return;
    }

    setState(() => currentPageIndex = target);
    pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> initializeSchedule() async {
    await fetchScheduleData(forceRefresh: false, showLoader: true, userInitiated: false);
    await fetchScheduleData(forceRefresh: true, showLoader: false, userInitiated: false);
  }

  void onDataUpdated() {
    fetchScheduleData(forceRefresh: false, showLoader: false, userInitiated: false);
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

  Future<void> fetchScheduleData({
    required bool forceRefresh,
    bool showLoader = true,
    bool userInitiated = false,
  }) async {
    if (showLoader) setState(() => isLoading = true);

    bool? refreshOk;
    try {
      if (forceRefresh) {
        refreshOk = await repository.forceRefreshWithStatus();
      }

      final scheduleResults = await Future.wait<List<Schedule>>([
        repository.getTodaySchedule(),
        repository.getTomorrowSchedule(),
      ]);

      if (!mounted) return;

      setState(() {
        todayScheduleData = scheduleResults[0];
        tomorrowScheduleData = scheduleResults[1];
        isOffline = refreshOk == null ? repository.isOfflineBadgeVisible : !refreshOk;
        if (showLoader) isLoading = false;
      });

      if (forceRefresh && refreshOk == false) {
        _showOfflineBanner(userInitiated: userInitiated);
      }
    } catch (_) {
      if (!mounted) return;
      if (showLoader) setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки расписания')),
      );
      return;
    }

    try {
      final loadedChanges = await changesRepository.getScheduleChanges();
      if (!mounted) return;
      setState(() {
        scheduleChanges = loadedChanges;
      });
    } catch (_) {}
  }

  List<Color> getHeaderGradient(String weekType) {
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
    final hasCachedData = todayScheduleData.isNotEmpty || tomorrowScheduleData.isNotEmpty;
    final isInitialLoading = isLoading && !hasCachedData;

    final forcedPage = widget.forcedPage;

    if (isInitialLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const SafeArea(
          bottom: false,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (forcedPage != null) {
      final pageTitle = forcedPage == 0 ? 'Сегодня' : 'Завтра';
      final scheduleData = forcedPage == 0 ? todayScheduleData : tomorrowScheduleData;
      return Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => fetchScheduleData(forceRefresh: true, userInitiated: true),
            color: Colors.white,
            child: buildSchedulePage(scheduleData, pageTitle),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            PageView(
              controller: pageController,
              onPageChanged: (index) {
                setState(() => currentPageIndex = index);
                if (_pageRequest.value != index) _pageRequest.value = index;
              },
              children: [
                RefreshIndicator(
                  onRefresh: () => fetchScheduleData(forceRefresh: true, userInitiated: true),
                  color: Colors.white,
                  child: buildSchedulePage(todayScheduleData, 'Сегодня'),
                ),
                RefreshIndicator(
                  onRefresh: () => fetchScheduleData(forceRefresh: true, userInitiated: true),
                  color: Colors.white,
                  child: buildSchedulePage(tomorrowScheduleData, 'Завтра'),
                ),
              ],
            ),
            Positioned(
              bottom: 60, // Сдвигаем индикатор страниц чуть выше над навбаром
              left: 0,
              right: 0,
              child: PageIndicator(currentPageIndex: currentPageIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSchedulePage(List<Schedule> scheduleData, String pageTitle) {
    final targetDate =
        pageTitle == 'Сегодня' ? DateTime.now() : DateTime.now().add(const Duration(days: 1));
    final weekType = getWeekTypeForDate(targetDate);

    final filteredScheduleData = filterScheduleByWeekType(scheduleData, weekType);
    final filteredChanges = getFilteredScheduleChanges(pageTitle);

    final callsData = CallsUtil.getCalls();

    final ScheduleChangesResult changesResult = filteredChanges.isEmpty
        ? ScheduleChangesResult(
            schedule: List<Schedule>.from(filteredScheduleData),
            hasBuildingOverride: false,
          )
        : applyScheduleChanges(filteredScheduleData, filteredChanges, callsData);

    final scheduleWithChanges = changesResult.schedule;
    final hasBuildingOverride = changesResult.hasBuildingOverride;

    final building = primaryBuilding(scheduleWithChanges);
    final dateLabel = formatDate(targetDate);

    final canOpen = _canOpenBuilding(building);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // Оптимизация для iOS
      slivers: [
        SliverToBoxAdapter(
          child: _StaticOverviewHeader(
            title: pageTitle,
            dateLabel: dateLabel,
            weekType: weekType ?? '',
            gradient: getHeaderGradient(weekType ?? ''),
            isOffline: isOffline,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 110),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          pageTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: canOpen ? () => _openBuildingInMaps(context, building) : null,
                            child: Location(
                              label: building,
                              showOverrideIndicator: hasBuildingOverride,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: scheduleWithChanges.isEmpty ? 50.0 : 12.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      if (scheduleWithChanges.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                Icons.weekend_outlined,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '$pageTitle выходной',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Нет запланированных занятий',
                                style: const TextStyle(fontSize: 16, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ...List.generate(scheduleWithChanges.length, (index) {
                          final item = scheduleWithChanges[index];

                          String lessonStartTime = item.startTime;
                          String lessonEndTime = item.endTime;

                          try {
                            final periodInt = int.tryParse(item.number);
                            if (periodInt != null && periodInt > 0 && periodInt <= callsData.length) {
                              final call = callsData[periodInt - 1];
                              lessonStartTime = call.startTime;
                              lessonEndTime = call.endTime;
                            }
                          } catch (_) {}

                          Widget card = LessonCard(
                            number: item.number,
                            subject: item.subject,
                            teacher: item.teacher,
                            startTime: lessonStartTime,
                            endTime: lessonEndTime,
                            accentColor: lessonAccent,
                          );
                          if (_isStudent) {
                            card = Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onLessonTap(
                                  item,
                                  startTime: lessonStartTime,
                                  endTime: lessonEndTime,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                child: card,
                              ),
                            );
                          }
                          final List<Widget> widgets = [card];

                          if (index < scheduleWithChanges.length - 1) {
                            String nextLessonStartTime = scheduleWithChanges[index + 1].startTime;

                            try {
                              final nextPeriodInt = int.tryParse(scheduleWithChanges[index + 1].number);
                              if (nextPeriodInt != null &&
                                  nextPeriodInt > 0 &&
                                  nextPeriodInt <= callsData.length) {
                                final nextCall = callsData[nextPeriodInt - 1];
                                nextLessonStartTime = nextCall.startTime;
                              }
                            } catch (_) {}

                            widgets.add(
                              BreakIndicator(
                                startTime: lessonEndTime,
                                endTime: nextLessonStartTime,
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(children: widgets),
                          );
                        }),
                      ],
                      if (filteredChanges.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        const Divider(color: Color(0xFF333333), thickness: 1),
                        const SizedBox(height: 20),
                        const Text(
                          'Изменения в расписании',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...filteredChanges.map((change) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: ReplacementCard(
                              lessonNumber: change.lessonNumber,
                              replaceFrom: change.replaceFrom,
                              replaceTo: change.replaceTo,
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? getWeekTypeForDate(DateTime date) => DateFormatter.getWeekType(date);

  List<Schedule> filterScheduleByWeekType(List<Schedule> schedule, String? weekType) {
    if (weekType == null) return schedule;

    final Map<String, List<Schedule>> lessonsByPeriod = {};
    for (final lesson in schedule) {
      (lessonsByPeriod[lesson.number] ??= []).add(lesson);
    }

    final List<Schedule> filtered = [];

    lessonsByPeriod.forEach((_, lessons) {
      final numeratorLessons = lessons
          .where((l) => l.lessonType == 'numerator' && l.subject.trim().isNotEmpty)
          .toList();

      final denominatorLessons = lessons
          .where((l) => l.lessonType == 'denominator' && l.subject.trim().isNotEmpty)
          .toList();

      final regularLessons =
          lessons.where((l) => l.lessonType == null && l.subject.trim().isNotEmpty).toList();

      if (numeratorLessons.isNotEmpty || denominatorLessons.isNotEmpty) {
        if (weekType == 'Числитель' && numeratorLessons.isNotEmpty) {
          filtered.addAll(numeratorLessons);
        } else if (weekType == 'Знаменатель' && denominatorLessons.isNotEmpty) {
          filtered.addAll(denominatorLessons);
        } else {
          filtered.addAll(regularLessons);
        }
      } else {
        filtered.addAll(regularLessons);
      }
    });

    return filtered;
  }

  ScheduleChangesResult applyScheduleChanges(
    List<Schedule> schedule,
    List<Replacement> changes,
    List callsData,
  ) {
    if (changes.isEmpty) {
      return ScheduleChangesResult(schedule: List<Schedule>.from(schedule), hasBuildingOverride: false);
    }

    final List<Schedule> result = List<Schedule>.from(schedule);
    bool hasBuildingOverride = false;

    for (final change in changes) {
      final lessonNumber = change.lessonNumber.trim();
      if (lessonNumber.isEmpty) continue;

      final normalizedReplaceTo = change.replaceTo.replaceAll('\u00A0', ' ').trim();
      final shouldHide = shouldHideLessonFromOverview(normalizedReplaceTo);

      final existingIndex = result.indexWhere((l) => l.number.trim() == lessonNumber);

      if (shouldHide) {
        if (existingIndex != -1) result.removeAt(existingIndex);
        continue;
      }

      final parsedDetails = parseLessonDetails(normalizedReplaceTo);
      final subject = parsedDetails.subject.isNotEmpty ? parsedDetails.subject : normalizedReplaceTo;
      final teacher = parsedDetails.teacher;

      final updatedBuilding = resolveBuildingFromChange(
        normalizedReplaceTo,
        existingIndex != -1 ? result[existingIndex].building : '',
      );

      if (updatedBuilding.isNotEmpty &&
          existingIndex != -1 &&
          updatedBuilding != result[existingIndex].building) {
        hasBuildingOverride = true;
      }

      if (existingIndex != -1) {
        final existing = result[existingIndex];
        result[existingIndex] = Schedule(
          id: existing.id,
          number: existing.number,
          subject: subject,
          teacher: teacher.isNotEmpty ? teacher : existing.teacher,
          startTime: existing.startTime,
          endTime: existing.endTime,
          building: updatedBuilding.isNotEmpty ? updatedBuilding : existing.building,
          lessonType: existing.lessonType,
        );
      } else {
        final timing = lessonTimingForNumber(lessonNumber, callsData);
        result.add(
          Schedule(
            id: 'change_${lessonNumber}_${change.updatedAt}',
            number: lessonNumber,
            subject: subject,
            teacher: teacher,
            startTime: timing.start,
            endTime: timing.end,
            building: updatedBuilding.isNotEmpty ? updatedBuilding : 'Дистанционно',
            lessonType: null,
          ),
        );
      }
    }

    result.sort((a, b) {
      final aN = tryParseLessonNumber(a.number);
      final bN = tryParseLessonNumber(b.number);
      if (aN != null && bN != null) return aN.compareTo(bN);
      return a.number.compareTo(b.number);
    });

    return ScheduleChangesResult(schedule: result, hasBuildingOverride: hasBuildingOverride);
  }

  bool shouldHideLessonFromOverview(String replaceTo) {
    final normalized = replaceTo.toLowerCase();
    return normalized.startsWith('занятие отменено') || normalized.startsWith('занятие перенесено на');
  }

  String resolveBuildingFromChange(String replaceTo, String fallbackBuilding) {
    final upper = replaceTo.toUpperCase();
    if (upper.contains('НЕЖИНСК')) return 'Нежинская';
    if (upper.contains('НАХИМОВ')) return 'Нахимовский';
    return fallbackBuilding;
  }

  LessonTiming lessonTimingForNumber(String lessonNumber, List callsData) {
    final sanitized = lessonNumber.trim();
    for (final call in callsData) {
      try {
        if (call.period == sanitized) {
          return LessonTiming(start: call.startTime, end: call.endTime);
        }
      } catch (_) {}
    }
    return const LessonTiming(start: '--:--', end: '--:--');
  }

  int? tryParseLessonNumber(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  String primaryBuilding(List<Schedule> schedule) {
    if (schedule.isEmpty) return '';
    final Map<String, int> counts = {};
    for (final lesson in schedule) {
      counts[lesson.building] = (counts[lesson.building] ?? 0) + 1;
    }

    String primary = schedule.first.building;
    int maxCount = 0;

    counts.forEach((b, c) {
      if (c > maxCount) {
        maxCount = c;
        primary = b;
      }
    });

    return primary;
  }

  String formatDate(DateTime date) => DateFormatter.formatDayWithMonth(date);

  List<Replacement> getFilteredScheduleChanges(String pageTitle) {
    final today = DateTime.now();
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    final todayDate =
        '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';
    final tomorrowDate =
        '${tomorrow.day.toString().padLeft(2, '0')}.${tomorrow.month.toString().padLeft(2, '0')}.${tomorrow.year}';

    final targetDate = pageTitle == 'Сегодня' ? todayDate : tomorrowDate;
    return scheduleChanges.where((c) => c.changeDate == targetDate).toList();
  }

  @override
  void dispose() {
    if (widget.forcedPage == null) {
      _pageRequest.removeListener(_onExternalPageRequest);
      pageController.dispose();
    }
    if (_ownsPageRequest) _pageRequest.dispose();
    repository.dataUpdatedNotifier.removeListener(onDataUpdated);
    super.dispose();
  }
}

class LessonTiming {
  final String start;
  final String end;

  const LessonTiming({required this.start, required this.end});
}

class ScheduleChangesResult {
  final List<Schedule> schedule;
  final bool hasBuildingOverride;

  ScheduleChangesResult({required this.schedule, required this.hasBuildingOverride});
}

const _overviewHeaderHeight = 176.0;

class _StaticOverviewHeader extends StatelessWidget {
  const _StaticOverviewHeader({
    required this.title,
    required this.dateLabel,
    required this.weekType,
    required this.gradient,
    required this.isOffline,
  });

  final String title;
  final String dateLabel;
  final String weekType;
  final List<Color> gradient;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    const radius = 32.0;
    const padH = 20.0;
    const padTop = 18.0;
    const padBottom = 18.0;
    const titleSize = 28.0;
    const dateSize = 16.0;
    const gapTitleDate = 4.0;
    const gapPillIcon = 10.0;
    const iconSize = 18.0;

    final pill = _WeekTypePill(
      text: weekType,
      fontSize: 13,
      padH: 14,
      padV: 6,
    );

    const pillFont = 13.0;
    const pillPV = 6.0;
    final estimatedPillHeight = pillFont + (pillPV * 2) + 6;
    final reservedTop = estimatedPillHeight + gapPillIcon;

    return SizedBox(
      height: _overviewHeaderHeight,
      child: Container(
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
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(padH, padTop, padH, padBottom),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: const Alignment(-1.0, -0.35),
                child: Padding(
                  padding: EdgeInsets.only(right: iconSize + 12, top: reservedTop),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: gapTitleDate),
                      Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: dateSize,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: pill,
              ),
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
      ),
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