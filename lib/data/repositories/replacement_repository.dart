import 'package:my_mpt/data/datasources/remote/replacement_remote_datasource.dart';
import 'package:my_mpt/domain/entities/replacement.dart';
import 'package:my_mpt/domain/repositories/replacement_repository_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReplacementRepository implements ReplacementRepositoryInterface {
  final ReplacementRemoteDatasource _changesService =
      ReplacementRemoteDatasource();

  static const String _selectedGroupKey = 'selected_group';
  static const String _selectedRoleKey = 'selected_role';
  static const String _teacherNameKey = 'teacher';

  /// Получить замены в расписании для конкретной группы
  @override
  Future<List<Replacement>> getScheduleChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_selectedRoleKey) ?? 'student';

      final List changes;
      if (role == 'student') {
        final groupCode = await _getSelectedGroupCode();
        if (groupCode.isEmpty) {
          return [];
        }
        changes = await _changesService.parseScheduleChangesForGroup(groupCode);
      } else {
        final teacherName = prefs.getString(_teacherNameKey) ?? '';
        if (teacherName.trim().isEmpty) {
          return [];
        }
        changes = await _changesService.parseScheduleChangesForTeacher(
          teacherName,
        );
      }

      // Преобразуем модели замен в сущности замен
      return changes.map((change) {
        return Replacement(
          lessonNumber: change.lessonNumber,
          replaceFrom: change.replaceFrom,
          replaceTo: change.replaceTo,
          updatedAt: change.updatedAt,
          changeDate: change.changeDate,
          group: change.group,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Получает код выбранной группы из настроек или из переменной окружения
  Future<String> _getSelectedGroupCode() async {
    try {
      // Проверяем переменную окружения first
      const envGroup = String.fromEnvironment('SELECTED_GROUP');
      if (envGroup.isNotEmpty) {
        return envGroup;
      }

      // Если переменная окружения не задана, используем SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedGroupKey) ?? '';
    } catch (e) {
      return '';
    }
  }
}
