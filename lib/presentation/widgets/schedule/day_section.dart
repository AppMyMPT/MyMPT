// day_section.dart
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_mpt/core/utils/calls_util.dart';
import 'package:my_mpt/domain/entities/schedule.dart';
import 'package:my_mpt/presentation/widgets/shared/location.dart';
import 'package:my_mpt/presentation/widgets/shared/lesson_card.dart';
import 'package:my_mpt/presentation/widgets/shared/break_indicator.dart';
import 'package:my_mpt/presentation/widgets/schedule/numerator_denominator_card.dart';

/// Виджет секции дня недели
class DaySection extends StatelessWidget {
  /// Название дня недели
  final String title;

  /// Корпус проведения занятий
  final String building;

  /// Список занятий в этот день
  final List<Schedule> lessons;

  /// Акцентный цвет
  final Color accentColor;

  /// Тип недели (числитель/знаменатель)
  final String? weekType;

  /// При нажатии на пару (только для студента). Если null, пары не кликабельны.
  /// [startTime] и [endTime] — время с карточки (для отображения в окне детали).
  final void Function(Schedule lesson, {String? startTime, String? endTime})? onLessonTap;

  const DaySection({
    super.key,
    required this.title,
    required this.building,
    required this.lessons,
    required this.accentColor,
    this.weekType,
    this.onLessonTap,
  });

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
      return Uri.parse('geo:0,0?q=$q'); // [web:387][web:393]
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

  /// Преобразует день недели из ЗАГЛАВНЫХ букв в формат с заглавной буквы
  String _formatDayTitle(String day) {
    if (day.isEmpty) return day;

    const dayMap = {
      'ПОНЕДЕЛЬНИК': 'Понедельник',
      'ВТОРНИК': 'Вторник',
      'СРЕДА': 'Среда',
      'ЧЕТВЕРГ': 'Четверг',
      'ПЯТНИЦА': 'Пятница',
      'СУББОТА': 'Суббота',
      'ВОСКРЕСЕНЬЕ': 'Воскресенье',
    };

    return dayMap[day] ?? day;
  }

  /// Создает виджеты для отображения уроков с поддержкой числителя/знаменателя
  List<Widget> _buildLessonWidgets(
    List<Schedule> lessons,
    List callsData, {
    void Function(Schedule lesson, {String? startTime, String? endTime})? onLessonTap,
  }) {
    final List<Widget> widgets = [];

    final Map<String, List<Schedule>> lessonsByPeriod = {};
    for (final lesson in lessons) {
      final period = lesson.number;
      (lessonsByPeriod[period] ??= []).add(lesson);
    }

    final sortedPeriods = lessonsByPeriod.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

    for (int i = 0; i < sortedPeriods.length; i++) {
      final period = sortedPeriods[i];
      final periodLessons = lessonsByPeriod[period]!;

      String startTime = '';
      String endTime = '';
      try {
        final periodInt = int.tryParse(period);
        if (periodInt != null && periodInt > 0 && periodInt <= callsData.length) {
          final call = callsData[periodInt - 1];
          startTime = call.startTime;
          endTime = call.endTime;
        }
      } catch (_) {}

      final hasTypedLessons = periodLessons.any((lesson) => lesson.lessonType != null);

      if (hasTypedLessons) {
        Schedule? numeratorLesson;
        Schedule? denominatorLesson;

        for (final lesson in periodLessons) {
          if (lesson.lessonType == 'numerator') {
            numeratorLesson = lesson;
          } else if (lesson.lessonType == 'denominator') {
            denominatorLesson = lesson;
          }
        }

        widgets.add(
          NumeratorDenominatorCard(
            numeratorLesson: numeratorLesson,
            denominatorLesson: denominatorLesson,
            lessonNumber: period,
            startTime: startTime,
            endTime: endTime,
            onLessonTap: onLessonTap,
          ),
        );
      } else {
        for (int j = 0; j < periodLessons.length; j++) {
          final lesson = periodLessons[j];
          Widget card = LessonCard(
            number: lesson.number,
            subject: lesson.subject,
            teacher: lesson.teacher,
            startTime: startTime,
            endTime: endTime,
            accentColor: accentColor,
          );
          if (onLessonTap != null) {
            card = Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onLessonTap!(lesson, startTime: startTime, endTime: endTime),
                borderRadius: BorderRadius.circular(16),
                child: card,
              ),
            );
          }
          widgets.add(card);

          if (j < periodLessons.length - 1) {
            widgets.add(const SizedBox(height: 8));
          }
        }
      }

      if (i < sortedPeriods.length - 1) {
        String nextLessonStartTime = '';
        try {
          final nextPeriodInt = int.tryParse(sortedPeriods[i + 1]);
          if (nextPeriodInt != null && nextPeriodInt > 0 && nextPeriodInt <= callsData.length) {
            final nextCall = callsData[nextPeriodInt - 1];
            nextLessonStartTime = nextCall.startTime;
          }
        } catch (_) {}

        widgets.add(BreakIndicator(startTime: endTime, endTime: nextLessonStartTime));
        widgets.add(const SizedBox(height: 14));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final formattedTitle = _formatDayTitle(title);
    final callsData = CallsUtil.getCalls();

    final canOpen = _canOpenBuilding(building);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formattedTitle,
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
                    child: Location(label: building),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(children: _buildLessonWidgets(lessons, callsData, onLessonTap: onLessonTap)),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 32),
        ],
      ),
    );
  }
}
