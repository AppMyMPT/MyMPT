/// Модель замены в расписании
///
/// Этот класс представляет собой замену в расписании,
/// например, замену одного предмета на другой
class Replacement {
  /// Номер пары, к которой применяется изменение
  final String lessonNumber;

  /// Исходный предмет (до изменения)
  final String replaceFrom;

  /// Новый предмет (после изменения)
  final String replaceTo;

  /// Время добавления изменения (timestamp)
  final String updatedAt;

  /// Дата применения изменения
  final String changeDate;

  /// Группа, к которой относится изменение
  final String group;

  /// Конструктор замены в расписании
  ///
  /// Параметры:
  /// - [lessonNumber]: Номер пары (обязательный)
  /// - [replaceFrom]: Исходный предмет (обязательный)
  /// - [replaceTo]: Новый предмет (обязательный)
  /// - [updatedAt]: Время добавления изменения (обязательный)
  /// - [changeDate]: Дата применения изменения (обязательный)
  /// - [group]: Группа
  Replacement({
    required this.lessonNumber,
    required this.replaceFrom,
    required this.replaceTo,
    required this.updatedAt,
    required this.changeDate,
    this.group = '',
  });

  @override
  String toString() {
    return 'ReplacementModel(lessonNumber: $lessonNumber, replaceFrom: $replaceFrom, replaceTo: $replaceTo, updatedAt: $updatedAt, changeDate: $changeDate, group: $group)';
  }

  /// Преобразует объект изменения в JSON
  ///
  /// Возвращает:
  /// Представление изменения в формате JSON
  Map<String, dynamic> toJson() {
    return {
      'lessonNumber': lessonNumber,
      'replaceFrom': replaceFrom,
      'replaceTo': replaceTo,
      'updatedAt': updatedAt,
      'changeDate': changeDate,
      'group': group,
    };
  }
}
