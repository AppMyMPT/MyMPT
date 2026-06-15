import 'package:html/dom.dart';
import 'package:my_mpt/data/models/replacement.dart';

/// Парсер для извлечения замен в расписании из HTML-документа
class ReplacementParser {
  /// Парсит замены в расписании для конкретной группы
  ///
  /// Метод извлекает HTML-страницу с заменами в расписании и находит
  /// все замены, относящиеся к указанной группе, на сегодня и завтра
  ///
  /// Параметры:
  /// - [document]: HTML-документ с заменами в расписании
  /// - [groupCode]: Код группы для которой нужно получить изменения
  ///
  /// Возвращает:
  /// Список замен в расписании для группы
  List<Replacement> parseScheduleChangesForGroup(
    Document document,
    String groupCode,
  ) {
    // Создаем список для хранения замен
    final List<Replacement> changes = [];

    // Получаем сегодняшнюю и завтрашнюю даты для фильтрации замен
    final today = DateTime.now();
    final tomorrow = DateTime.now().add(Duration(days: 1));

    // Форматируем даты в строковый формат для сравнения
    final String todayDate =
        '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';
    final String tomorrowDate =
        '${tomorrow.day.toString().padLeft(2, '0')}.${tomorrow.month.toString().padLeft(2, '0')}.${tomorrow.year}';

    // Нормализуем код группы для поиска
    final normalizedGroupCode = groupCode.trim().toUpperCase();

    // Ищем все заголовки h4 с датами замен (строгий селектор)
    final dateHeaders = document.querySelectorAll('h4');

    // Регулярное выражение для извлечения даты (компилируем один раз)
    final RegExp dateRegExp = RegExp(r'(\d{2}\.\d{2}\.\d{4})');

    // Проходим по заголовкам с датами
    for (var header in dateHeaders) {
      final text = header.text.trim();

      // Проверяем, является ли заголовок заголовком изменений
      if (!text.startsWith('Замены на')) continue;

      // Извлекаем дату из заголовка
      final match = dateRegExp.firstMatch(text);
      if (match == null) continue;

      final currentDate = match.group(1)!;

      // Проверяем, что дата соответствует сегодня или завтра
      if (currentDate != todayDate && currentDate != tomorrowDate) continue;

      // Ищем таблицы напрямую после заголовка (оптимизированный поиск)
      Element? nextElement = header.nextElementSibling;

      while (nextElement != null) {
        // Если встретили следующий заголовок, прекращаем поиск
        if (nextElement.localName == 'h4' &&
            nextElement.text.trim().startsWith('Замены на')) {
          break;
        }

        // Ищем таблицы с заменами (строгий селектор)
        Element? table;
        if (nextElement.localName == 'div' &&
            nextElement.classes.contains('table-responsive')) {
          table = nextElement.querySelector('table.table');
        } else if (nextElement.localName == 'table' &&
            nextElement.classes.contains('table')) {
          table = nextElement;
        }

        // Если таблица найдена, проверяем её на соответствие группе
        if (table != null) {
          final caption = table.querySelector('caption');
          if (caption != null) {
            final captionText = caption.text.trim().toUpperCase();
            // Проверяем, содержит ли таблица замены для нашей группы
            if (normalizedGroupCode.isNotEmpty &&
                captionText.contains(normalizedGroupCode)) {
              // Ищем все строки с заменами (пропускаем заголовок)
              final rows = table.querySelectorAll(
                'tbody > tr, tr:not(:first-child)',
              );

              // Обрабатываем строки
              for (var row in rows) {
                final cells = row.querySelectorAll('td');

                // Проверяем, что в строке есть все необходимые данные (4 ячейки)
                if (cells.length == 4) {
                  // Извлекаем данные из ячеек таблицы
                  final lessonNumber = cells[0].text.trim();
                  final replaceFrom = cells[1].text.trim();
                  final replaceTo = cells[2].text.trim();
                  final updatedAt = cells[3].text.trim();

                  // Создаем объект замены с пометкой о дате
                  changes.add(
                    Replacement(
                      lessonNumber: lessonNumber,
                      replaceFrom: replaceFrom,
                      replaceTo: replaceTo,
                      updatedAt: updatedAt,
                      changeDate: currentDate,
                      group: normalizedGroupCode,
                    ),
                  );
                }
              }
            }
          }
        }

        nextElement = nextElement.nextElementSibling;
      }
    }

    return changes;
  }

  /// Парсит замены, в которых встречается выбранный преподаватель.
  List<Replacement> parseScheduleChangesForTeacher(
    Document document,
    String teacherName,
  ) {
    final List<Replacement> changes = [];

    final today = DateTime.now();
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    final String todayDate =
        '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';
    final String tomorrowDate =
        '${tomorrow.day.toString().padLeft(2, '0')}.${tomorrow.month.toString().padLeft(2, '0')}.${tomorrow.year}';

    final matcher = _TeacherNameMatcher(teacherName);
    if (!matcher.isValid) return changes;

    final dateHeaders = document.querySelectorAll('h4');
    final RegExp dateRegExp = RegExp(r'(\d{2}\.\d{2}\.\d{4})');

    for (var header in dateHeaders) {
      final text = header.text.trim();
      if (!text.startsWith('Замены на')) continue;

      final match = dateRegExp.firstMatch(text);
      if (match == null) continue;

      final currentDate = match.group(1)!;
      if (currentDate != todayDate && currentDate != tomorrowDate) continue;

      Element? nextElement = header.nextElementSibling;

      while (nextElement != null) {
        if (nextElement.localName == 'h4' &&
            nextElement.text.trim().startsWith('Замены на')) {
          break;
        }

        Element? table;
        if (nextElement.localName == 'div' &&
            nextElement.classes.contains('table-responsive')) {
          table = nextElement.querySelector('table.table');
        } else if (nextElement.localName == 'table' &&
            nextElement.classes.contains('table')) {
          table = nextElement;
        }

        if (table != null) {
          final group = _groupFromCaption(
            table.querySelector('caption')?.text ?? '',
          );
          final rows = table.querySelectorAll(
            'tbody > tr, tr:not(:first-child)',
          );

          for (var row in rows) {
            final cells = row.querySelectorAll('td');
            if (cells.length != 4) continue;

            final lessonNumber = cells[0].text.trim();
            final replaceFrom = cells[1].text.trim();
            final replaceTo = cells[2].text.trim();
            final updatedAt = cells[3].text.trim();
            final searchable = '$replaceFrom $replaceTo';

            if (!matcher.matches(searchable)) continue;

            changes.add(
              Replacement(
                lessonNumber: lessonNumber,
                replaceFrom: replaceFrom,
                replaceTo: replaceTo,
                updatedAt: updatedAt,
                changeDate: currentDate,
                group: group,
              ),
            );
          }
        }

        nextElement = nextElement.nextElementSibling;
      }
    }

    return changes;
  }

  String _groupFromCaption(String caption) {
    final normalized = caption.replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = RegExp(
      r'([А-ЯA-Z]\d{1,3}(?:[-–][А-ЯA-Z0-9]+)+)',
    ).firstMatch(normalized.toUpperCase());
    if (match != null) return match.group(1)!.toUpperCase();
    return normalized
        .replaceAll(RegExp(r'^\s*группа\s*[:\-]?\s*', caseSensitive: false), '')
        .trim();
  }
}

class _TeacherNameMatcher {
  _TeacherNameMatcher(String teacherName) {
    final parts = teacherName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;

    final wordsWithoutDots = parts.where((p) => !p.contains('.')).toList();
    if (wordsWithoutDots.isNotEmpty) {
      final candidates = wordsWithoutDots.where((w) => w.length > 2).toList();
      if (candidates.isNotEmpty) {
        if (candidates.contains(parts.first)) {
          lastName = parts.first.toLowerCase();
        } else {
          lastName = candidates.last.toLowerCase();
        }
      } else {
        lastName = wordsWithoutDots.first.toLowerCase();
      }
    } else {
      lastName = parts.last.toLowerCase();
    }

    final otherParts = parts.where((p) => p.toLowerCase() != lastName).toList();
    if (otherParts.isNotEmpty) {
      final rest = otherParts.join(' ').toLowerCase();
      if (rest.contains('.')) {
        initialsNormalized = rest.replaceAll(' ', '');
      } else {
        final initials = otherParts
            .take(2)
            .map((p) => p.isNotEmpty ? p[0].toLowerCase() : '')
            .where((c) => c.isNotEmpty)
            .toList();
        initialsNormalized = initials.map((c) => '$c.').join();
      }
    }
  }

  String lastName = '';
  String initialsNormalized = '';

  bool get isValid => lastName.isNotEmpty;

  bool matches(String text) {
    final normalized = text.toLowerCase();
    final nameRegex = RegExp(
      r'(^|\s|[^а-яёa-z])' + RegExp.escape(lastName) + r'($|\s|[^а-яёa-z])',
      caseSensitive: false,
    );

    if (!nameRegex.hasMatch(normalized)) return false;
    if (initialsNormalized.isEmpty) return true;
    if (!normalized.contains('.')) return true;

    return normalized.replaceAll(' ', '').contains(initialsNormalized);
  }
}
