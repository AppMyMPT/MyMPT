import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:my_mpt/data/models/lesson.dart';

class ScheduleTeacherParser {
  Map<String, List<Lesson>> parse(String html, String teacherName) {
    if (teacherName.isEmpty) return {};

    final document = html_parser.parse(html);
    final schedule = <String, List<Lesson>>{};

    final teacherNameParts = teacherName.split(' ');
    final lastName = teacherNameParts.last.toLowerCase();
    final initials = teacherNameParts.sublist(0, teacherNameParts.length - 1).join(' ').toLowerCase();

    final tabPanels = document.querySelectorAll('[role="tabpanel"]');
    
    // Создаем карту соответствия id вкладки -> Название группы
    final Map<String, String> idToGroup = {};
    final tabLinks = document.querySelectorAll('ul.nav-tabs > li > a[href^="#"]');
    for (var link in tabLinks) {
       final href = link.attributes['href'];
       if (href != null && href.startsWith('#')) {
          final tabId = href.substring(1);
          idToGroup[tabId] = link.text.trim();
       }
    }

    for (var tabPanel in tabPanels) {
      // Игнорируем родительские вкладки (например, вкладки специальностей),
      // чтобы не парсить одни и те же таблицы дважды. Берем только самые вложенные.
      if (tabPanel.querySelectorAll('[role="tabpanel"]').isNotEmpty) {
        continue;
      }
      
      String currentGroup = '';

      // Пытаемся найти "Группа П50-1-23" внутри панели
      final headers = tabPanel.querySelectorAll('h2, h3');
      for (var h in headers) {
        final text = h.text.trim();
        if (text.startsWith('Группа ')) {
          currentGroup = text.replaceFirst('Группа ', '').trim();
          break;
        }
      }

      // Если не нашли, пробуем по ID вкладки
      if (currentGroup.isEmpty) {
        final tabId = tabPanel.attributes['id'];
        currentGroup = tabId != null ? (idToGroup[tabId] ?? '') : '';
      }

      // На случай если каким-то образом попало "Расписание занятий для ..."
      if (currentGroup.startsWith('Расписание занятий для ')) {
        currentGroup = currentGroup.replaceFirst('Расписание занятий для ', '').trim();
      }

      if (currentGroup.isEmpty) continue;

      final tables = tabPanel.querySelectorAll('table.table');

      for (var table in tables) {
        final thead = table.querySelector('thead');
        if (thead == null) continue;

        final h4 = thead.querySelector('h4');
        if (h4 == null) continue;

        String rawDay = h4.nodes.first.text?.trim() ?? '';
        final day = rawDay.toUpperCase();
        if (day.isEmpty) continue;

        final rows = table.querySelectorAll('tbody tr');
        final iterRows = rows.isNotEmpty ? rows : table.querySelectorAll('tr');

        for (var row in iterRows) {
          if (row.querySelectorAll('th').isNotEmpty) continue;
          final cols = row.querySelectorAll('td');
          if (cols.length < 3) continue;

          final numberTimeText = cols[0].text;
          final numberMatch = RegExp(r'\d+').firstMatch(numberTimeText);
          final number = numberMatch?.group(0) ?? '';

          final timeMatch = RegExp(r'(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})').firstMatch(numberTimeText);
          final startTime = timeMatch?.group(1) ?? '';
          final endTime = timeMatch?.group(2) ?? '';

          final subjectCell = cols[1];
          final teacherCell = cols[2];

          final subjectLabels = subjectCell.querySelectorAll('div.label');
          final teacherLabels = teacherCell.querySelectorAll('div.label');

          if (subjectLabels.isEmpty || teacherLabels.isEmpty) {
            final cellTeacherText = teacherCell.text.toLowerCase();
            if (_isTeacherMatch(cellTeacherText, lastName, initials)) {
               final building = h4.querySelector('span')?.text.trim() ?? '';
               final subject = subjectCell.text.trim();

               if (!schedule.containsKey(day)) schedule[day] = [];
               schedule[day]!.add(Lesson(
                 number: number,
                 subject: subject,
                 teacher: currentGroup,
                 startTime: startTime,
                 endTime: endTime,
                 building: building,
                 lessonType: null
               ));
            }
          } else {
             final count = _pairedLabelsCount(subjectLabels, teacherLabels);
             for (var i = 0; i < count; i++) {
                final cellTeacherText = teacherLabels[i].text.toLowerCase();
                if (_isTeacherMatch(cellTeacherText, lastName, initials)) {
                   final building = h4.querySelector('span')?.text.trim() ?? '';
                   final subject = subjectLabels[i].text.trim();
                   final lessonType = _resolveLessonType(subjectLabels[i]);
                   
                   if (!schedule.containsKey(day)) schedule[day] = [];
                   schedule[day]!.add(Lesson(
                     number: number,
                     subject: subject,
                     teacher: currentGroup, // Сохраняем группу
                     startTime: startTime,
                     endTime: endTime,
                     building: building,
                     lessonType: lessonType
                   ));
                }
             }
          }
        }
      }
    }
    
    return _mergeTeacherLessons(schedule);
  }

  bool _isTeacherMatch(String cellText, String lastName, String initials) {
    // 1. Поиск точного совпадения фамилии (с границами)
    // Используем [^а-яёa-z] чтобы исключить совпадения внутри других слов
    final nameRegex = RegExp(r'(^|\s|[^а-яёa-z])' + RegExp.escape(lastName) + r'($|\s|[^а-яёa-z])', caseSensitive: false);
    
    if (!nameRegex.hasMatch(cellText)) {
      return false; // Фамилии нет — точно не он
    }

    final cleanInitials = initials.replaceAll(' ', '');
    
    if (cleanInitials.isEmpty) return true;
    if (!cellText.contains('.')) return true;

    return cellText.replaceAll(' ', '').contains(cleanInitials);
  }

  int _pairedLabelsCount(List<Element> subjects, List<Element> teachers) {
    if (subjects.isEmpty || teachers.isEmpty) return 0;
    return subjects.length < teachers.length ? subjects.length : teachers.length;
  }

  String? _resolveLessonType(Element label) {
    final classes = label.attributes['class'] ?? '';
    if (classes.contains('label-danger')) return 'numerator';
    if (classes.contains('label-info')) return 'denominator';
    return null;
  }

  Map<String, List<Lesson>> _mergeTeacherLessons(Map<String, List<Lesson>> rawSchedule) {
     final result = <String, List<Lesson>>{};
     
     rawSchedule.forEach((day, lessons) {
        final Map<String, Lesson> merged = {};
        for (var lesson in lessons) {
           final key = '${lesson.number}_${lesson.lessonType ?? "all"}';
           if (merged.containsKey(key)) {
              final existing = merged[key]!;
              final newGroup = existing.teacher == null || existing.teacher!.isEmpty 
                  ? (lesson.teacher ?? '') 
                  // Если группа уже есть в строке, не дублируем её
                  : (existing.teacher!.contains(lesson.teacher ?? '') 
                      ? existing.teacher 
                      : '${existing.teacher}, ${lesson.teacher ?? ''}');
                  
              merged[key] = Lesson(
                  number: existing.number,
                  subject: existing.subject,
                  teacher: newGroup,
                  startTime: existing.startTime,
                  endTime: existing.endTime,
                  building: existing.building,
                  lessonType: existing.lessonType
              );
           } else {
              merged[key] = lesson;
           }
        }
        result[day] = merged.values.toList()..sort((a, b) => int.parse(a.number).compareTo(int.parse(b.number)));
     });
     
     return _sortDays(result);
  }

  Map<String, List<Lesson>> _sortDays(Map<String, List<Lesson>> schedule) {
    const daysOrder = {
      'ПОНЕДЕЛЬНИК': 1,
      'ВТОРНИК': 2,
      'СРЕДА': 3,
      'ЧЕТВЕРГ': 4,
      'ПЯТНИЦА': 5,
      'СУББОТА': 6,
      'ВОСКРЕСЕНЬЕ': 7,
    };

    final sortedKeys = schedule.keys.toList()..sort((a, b) {
      final orderA = daysOrder[a] ?? 99;
      final orderB = daysOrder[b] ?? 99;
      return orderA.compareTo(orderB);
    });

    final sortedSchedule = <String, List<Lesson>>{};
    for (final key in sortedKeys) {
      sortedSchedule[key] = schedule[key]!;
    }

    return sortedSchedule;
  }
}
