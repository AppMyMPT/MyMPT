import 'package:html/parser.dart' as html_parser;

class TeacherFullNameParser {
  static final RegExp _fullNamePattern = RegExp(
    r"^[А-ЯЁ][а-яё]+(?:[-'][А-ЯЁа-яё]+)?"
    r"(?:\s+[А-ЯЁ][а-яё]+(?:[-'][А-ЯЁа-яё]+)?){2}"
    r"(?:\s+(?:оглы|кызы))?$",
  );

  List<String> parse(String html) {
    final document = html_parser.parse(html);
    final namesByKey = <String, String>{};

    var candidates = document.querySelectorAll('.inner-page-teachers-name');
    if (candidates.isEmpty) {
      candidates = document.querySelectorAll(
        '.inner-page-teachers-item img[alt]',
      );
    }

    for (final element in candidates) {
      final source = element.attributes['alt'] ?? element.text;
      final name = source.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (!_fullNamePattern.hasMatch(name)) continue;
      namesByKey.putIfAbsent(name.toLowerCase(), () => name);
    }

    final names = namesByKey.values.toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }
}
