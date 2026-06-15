/// Сущность, представляющая замену в расписании
///
/// Этот класс представляет собой замену в расписании,
/// например, замену одного предмета на другой
class Replacement {
  /// Номер пары, к которой применяется замена
  final String lessonNumber;

  /// Исходный предмет (до замены)
  final String replaceFrom;

  /// Новый предмет (после замены)
  final String replaceTo;

  /// Время добавления замены (timestamp)
  final String updatedAt;

  /// Дата применения замены
  final String changeDate;

  /// Группа, к которой относится замена
  final String group;

  /// Конструктор замены в расписании
  ///
  /// Параметры:
  /// - [lessonNumber]: Номер пары (обязательный)
  /// - [replaceFrom]: Исходный предмет (обязательный)
  /// - [replaceTo]: Новый предмет (обязательный)
  /// - [updatedAt]: Время добавления замены (обязательный)
  /// - [changeDate]: Дата применения замены (обязательный)
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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Replacement &&
        other.lessonNumber == lessonNumber &&
        other.replaceFrom == replaceFrom &&
        other.replaceTo == replaceTo &&
        other.updatedAt == updatedAt &&
        other.changeDate == changeDate &&
        other.group == group;
  }

  @override
  int get hashCode {
    return Object.hash(
      lessonNumber,
      replaceFrom,
      replaceTo,
      updatedAt,
      changeDate,
      group,
    );
  }
}
