/// Модель урока в расписании
///
/// Этот класс представляет собой отдельный урок в расписании
/// с информацией о времени, предмете, преподавателе и других деталях
class Lesson {
  /// Номер пары
  final String number;

  /// Название предмета
  final String subject;

  /// Преподаватель
  final String teacher;

  /// Группа, для которой проводится пара
  final String group;

  /// Время начала пары
  final String startTime;

  /// Время окончания пары
  final String endTime;

  /// Корпус проведения пары
  final String building;

  /// Тип пары (numerator, denominator или null для обычных пар)
  final String? lessonType;

  Lesson({
    required this.number,
    required this.subject,
    required this.teacher,
    this.group = '',
    required this.startTime,
    required this.endTime,
    required this.building,
    this.lessonType,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      number: (json['number'] ?? '') as String,
      subject: (json['subject'] ?? '') as String,
      teacher: (json['teacher'] ?? '') as String,
      group: (json['group'] ?? '') as String,
      startTime: (json['startTime'] ?? '') as String,
      endTime: (json['endTime'] ?? '') as String,
      building: (json['building'] ?? '') as String,
      lessonType: json['lessonType'] as String?,
    );
  }

  @override
  String toString() {
    return 'Lesson(number: $number, subject: $subject, teacher: $teacher, group: $group, startTime: $startTime, endTime: $endTime, building: $building)';
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'subject': subject,
      'teacher': teacher,
      'group': group,
      'startTime': startTime,
      'endTime': endTime,
      'building': building,
      'lessonType': lessonType,
    };
  }
}
