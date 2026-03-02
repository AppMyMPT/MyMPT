import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:my_mpt/data/models/teacher.dart';

class TeacherParser {
  List<Teacher> parse(String html) {
    final document = html_parser.parse(html);
    final Set<String> result = {};
    final List<Teacher> teachers = [];

    // Регекс для поиска ФИО: поддерживает и "И.О. Фамилия" и "Фамилия И.О."
    final fioRegex = RegExp(r'([А-ЯЁ][а-яё\-]+\s+[А-ЯЁ]\.\s?[А-ЯЁ]\.)|([А-ЯЁ]\.\s?[А-ЯЁ]\.\s?[А-ЯЁ][а-яё\-]+)');

    final tables = document.querySelectorAll('table');

    for (var table in tables) {
      int teacherIndex = _findTeacherColumnIndex(table);

      final rows = table.querySelectorAll('tbody tr');
      final iterRows = rows.isNotEmpty ? rows : table.querySelectorAll('tr');

      for (var row in iterRows) {
        if (row.querySelectorAll('th').isNotEmpty) continue;

        final cols = row.querySelectorAll('td');
        if (cols.isEmpty) continue;

        Element teacherCell;
        if (teacherIndex >= 0 && teacherIndex < cols.length) {
          teacherCell = cols[teacherIndex];
        } else {
          teacherCell = cols.last;
        }

        // 1) вытаскиваем label-danger / label-info 
        final labels = teacherCell.querySelectorAll('.label-danger, .label-info');
        
        if (labels.isNotEmpty) {
           for (var lbl in labels) {
            final txt = lbl.text.replaceAll(RegExp(r'\s+'), ' ').trim();
            final matches = fioRegex.allMatches(txt);
            for (var match in matches) {
                result.add(match.group(0)!.trim());
            }
          }
        } else {
          // 2) иначе — берем весь текст ячейки
          final raw = teacherCell.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          final matches = fioRegex.allMatches(raw);
          if (matches.isNotEmpty) {
             for (var match in matches) {
                result.add(match.group(0)!.trim());
             }
          } else {
            // дополнительная защита: иногда ФИО находятся внутри <strong> или <b>
            final strong = teacherCell.querySelector('strong, b');
            if (strong != null) {
              final s = strong.text.replaceAll(RegExp(r'\s+'), ' ').trim();
              final strongMatches = fioRegex.allMatches(s);
              for (var match in strongMatches) {
                 result.add(match.group(0)!.trim());
              }
            } else {
              // Если регулярка совсем не сработала, но в ячейке явно есть преподаватели через запятую
              final parts = raw.split(',');
              for (var part in parts) {
                final cleaned = part.trim();
                // Фильтруем откровенный мусор: должно содержать точки, не должно содержать цифр, не должно быть слишком длинным (например, фразы)
                if (cleaned.length > 5 && cleaned.length < 40 && cleaned.contains('.') && !RegExp(r'\d').hasMatch(cleaned)) {
                  result.add(cleaned);
                }
              }
            }
          }
        }
      }
    }

    // Сортировка по фамилии (последнее слово или первое, если "Фамилия И.О.").
    final list = result.toList();
    list.sort((a, b) {
      final ka = _surnameKey(a);
      final kb = _surnameKey(b);
      final c = ka.compareTo(kb);
      return c != 0 ? c : a.compareTo(b);
    });

    for (var teacher in list){
      teachers.add(Teacher(teacherName: teacher));
    }

    return teachers;
  }

  int _findTeacherColumnIndex(Element table) {
    final headerCells = <Element>[];
    headerCells.addAll(table.querySelectorAll('thead th'));
    if (headerCells.isEmpty) {
      final firstRow = table.querySelector('tbody tr') ?? table.querySelector('tr');
      if (firstRow != null) {
        headerCells.addAll(firstRow.querySelectorAll('th'));
      }
    }
    if (headerCells.isEmpty) {
      headerCells.addAll(table.querySelectorAll('th'));
    }

    for (int i = 0; i < headerCells.length; i++) {
      final text = headerCells[i].text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
      if (text.contains('преподав')) return i;
    }

    return -1;
  }

  String _surnameKey(String s) {
    final cleaned = s.replaceAll(RegExp(r'[,\\.\(\)]'), '').trim();
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.isEmpty) return cleaned.toLowerCase();
    
    // Если формат "Фамилия И О", фамилия - первое слово
    // Если формат "И О Фамилия", фамилия - последнее слово
    // Простейшая эвристика: слово, которое длиннее 2 символов
    final possibleSurnames = words.where((w) => w.length > 2).toList();
    if (possibleSurnames.isNotEmpty) {
      return possibleSurnames.first.toLowerCase(); // чаще всего фамилия одна и она длинная
    }
    
    return words.last.toLowerCase();
  }
}