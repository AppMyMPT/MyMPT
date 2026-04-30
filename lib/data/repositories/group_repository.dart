import 'package:my_mpt/data/datasources/remote/group_remote_datasource.dart';
import 'package:my_mpt/data/models/group.dart';
import 'package:my_mpt/data/repositories/specialty_repository.dart';
import 'package:my_mpt/domain/repositories/group_repository_interface.dart';

class GroupRepository implements GroupRepositoryInterface {
  final GroupRemoteDatasource _parserService = GroupRemoteDatasource();
  final SpecialtyRepository _specialtyRepository = SpecialtyRepository();

  @override
  Future<List<Group>> getGroupsBySpecialty(
    String specialtyCode, {
    bool forceRefresh = false,
  }) async {
    try {
      String? specialtyName = _specialtyRepository.getSpecialtyNameByCode(specialtyCode);

      if (specialtyName == null) {
        await _specialtyRepository.getSpecialties(forceRefresh: forceRefresh);
        specialtyName = _specialtyRepository.getSpecialtyNameByCode(specialtyCode);
      }

      if (specialtyName == null || specialtyName.trim().isEmpty) {
        return [];
      }

      final groupInfos = await _parserService.parseGroups(
        specialtyName,
        forceRefresh,
      );

      groupInfos.sort(_compareGroups);
      return groupInfos;
    } catch (_) {
      return [];
    }
  }

  int _compareGroups(Group a, Group b) {
    final componentsA = _parseGroupCode(a.code);
    final componentsB = _parseGroupCode(b.code);

    final specialtyComparison = componentsA.specialty.compareTo(componentsB.specialty);
    if (specialtyComparison != 0) return specialtyComparison;

    final yearComparison = componentsB.year.compareTo(componentsA.year);
    if (yearComparison != 0) return yearComparison;

    return componentsA.number.compareTo(componentsB.number);
  }

  _GroupComponents _parseGroupCode(String groupCode) {
    String specialty = '';
    int number = 0;
    int year = 0;

    try {
      String firstPart = groupCode;
      const separators = [',', ';', '/'];
      for (final separator in separators) {
        final index = groupCode.indexOf(separator);
        if (index != -1) {
          firstPart = groupCode.substring(0, index).trim();
          break;
        }
      }

      final parts = firstPart.split('-');
      if (parts.length >= 3) {
        specialty = parts[0];
        number = int.tryParse(parts[1]) ?? 0;
        year = int.tryParse(parts[2]) ?? 0;
      }
    } catch (_) {}

    return _GroupComponents(specialty, number, year);
  }
}

class _GroupComponents {
  final String specialty;
  final int number;
  final int year;

  _GroupComponents(this.specialty, this.number, this.year);
}
