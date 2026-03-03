import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'package:my_mpt/domain/entities/schedule.dart';

/// Сервис обновления виджета «Пары на сегодня» на Android.
/// Отправляет данные расписания в нативный виджет через MethodChannel.
class ScheduleWidgetService {
  static const _channel = MethodChannel('ru.merrcurys.my_mpt/schedule_widget');

  /// Обновляет виджет расписания на главном экране Android.
  /// [date] — дата расписания (используется для отображения и проверки актуальности).
  /// [groupName] — название/код группы (отображается в виджете).
  /// [lessons] — список пар на день.
  static Future<void> updateWidget({
    required DateTime date,
    required String groupName,
    required List<Schedule> lessons,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final lessonsMap = lessons
          .map((s) => {
                'number': s.number,
                'subject': s.subject,
                'teacher': s.teacher,
                'startTime': s.startTime,
                'endTime': s.endTime,
                'building': s.building,
                'lessonType': s.lessonType,
              })
          .toList();
      await _channel.invokeMethod('updateWidget', {
        'date': dateStr,
        'group': groupName,
        'lessons': lessonsMap,
      });
    } on MissingPluginException catch (_) {
      // Нативная реализация ещё не зарегистрирована — полный перезапуск приложения
    } on PlatformException catch (_) {
      // Виджет может быть не добавлен — игнорируем
    }
  }
}
