import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_mpt/core/services/teacher_full_name_service.dart';
import 'package:my_mpt/core/utils/teacher_full_name_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses a fresh cache immediately without a network request', () async {
    final cachedNames = <String>[
      'Новый Иван Иванович',
      ...List.generate(19, (index) => 'Тестов$index Иван Иванович'),
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    SharedPreferences.setMockInitialValues({
      'teacher_full_names_v1': jsonEncode(cachedNames),
      'teacher_full_names_last_success_v1':
          DateTime.now().millisecondsSinceEpoch,
    });

    var networkRequests = 0;
    final service = TeacherFullNameService(
      client: MockClient((_) async {
        networkRequests++;
        return http.Response('', 500);
      }),
    );

    await service.initialize();

    expect(networkRequests, 0);
    expect(resolveTeacherFullName('Новый И.И.'), 'Новый Иван Иванович');
  });
}
