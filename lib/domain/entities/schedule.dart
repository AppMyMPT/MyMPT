/// Сущность, представляющая элемент расписания
///
/// Этот класс представляет собой элемент расписания с полной информацией
/// о времени, предмете, преподавателе и других деталях
class Schedule {
  /// Уникальный идентификатор элемента расписания
  final String id;

  /// Номер пары
  final String number;

  /// Название предмета
  final String subject;

  /// Преподаватель
  final String teacher;

  /// Группа, для которой проводится занятие
  final String group;

  /// Время начала пары
  final String startTime;

  /// Время окончания пары
  final String endTime;

  /// Корпус проведения пары
  final String building;

  /// Тип пары (numerator, denominator или null для обычных пар)
  final String? lessonType;

  /// Дополнительный комментарий к занятию
  final String comment;

  /// Конструктор элемента расписания
  ///
  /// Параметры:
  /// - [id]: Уникальный идентификатор (обязательный)
  /// - [number]: Номер пары (обязательный)
  /// - [subject]: Название предмета (обязательный)
  /// - [teacher]: Преподаватель (обязательный)
  /// - [group]: Группа
  /// - [startTime]: Время начала пары (обязательный)
  /// - [endTime]: Время окончания пары (обязательный)
  /// - [building]: Корпус проведения пары (обязательный)
  /// - [lessonType]: Тип пары (опциональный)
  /// - [comment]: Комментарий
  Schedule({
    required this.id,
    required this.number,
    required this.subject,
    required this.teacher,
    this.group = '',
    required this.startTime,
    required this.endTime,
    required this.building,
    this.lessonType,
    this.comment = '',
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Schedule &&
        other.id == id &&
        other.number == number &&
        other.subject == subject &&
        other.teacher == teacher &&
        other.group == group &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.building == building &&
        other.comment == comment;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      number,
      subject,
      teacher,
      group,
      startTime,
      endTime,
      building,
      comment,
    );
  }
}
