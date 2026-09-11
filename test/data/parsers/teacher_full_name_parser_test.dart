import 'package:flutter_test/flutter_test.dart';
import 'package:my_mpt/data/parsers/teacher_full_name_parser.dart';

void main() {
  test('parses and deduplicates names from REA teacher cards', () {
    const html = '''
      <div class="inner-page-teachers-name">
        <a>Чурилов Андрей Викторович</a>
      </div>
      <div class="inner-page-teachers-name">
        Азизов Амиль Камиль оглы
      </div>
      <div class="inner-page-teachers-name">
        Чурилов Андрей Викторович
      </div>
      <div class="inner-page-teachers-name">Преподаватель</div>
    ''';

    expect(TeacherFullNameParser().parse(html), [
      'Азизов Амиль Камиль оглы',
      'Чурилов Андрей Викторович',
    ]);
  });

  test('falls back to image alt attributes when name blocks are absent', () {
    const html = '''
      <div class="inner-page-teachers-item">
        <img alt="Клопов Дмитрий Анатольевич">
      </div>
    ''';

    expect(TeacherFullNameParser().parse(html), ['Клопов Дмитрий Анатольевич']);
  });
}
