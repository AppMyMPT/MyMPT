import 'package:my_mpt/data/datasources/remote/speciality_remote_datasource.dart';
import 'package:my_mpt/domain/entities/specialty.dart';
import 'package:my_mpt/domain/repositories/specialty_repository_interface.dart';

class SpecialtyRepository implements SpecialtyRepositoryInterface {
  final SpecialityRemoteDatasource _parserService = SpecialityRemoteDatasource();

  List<Specialty>? _cachedSpecialties;
  Map<String, String>? _codeToNameCache;

  @override
  Future<List<Specialty>> getSpecialties({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && _cachedSpecialties != null && _cachedSpecialties!.isNotEmpty) {
        return _cachedSpecialties!;
      }

      final tabs = await _parserService.parseTabList(forceRefresh: forceRefresh);
      final specialties = tabs.map(_createSpecialtyFromTab).toList();
      specialties.sort((a, b) => a.name.compareTo(b.name));

      _cachedSpecialties = specialties;
      _codeToNameCache = {for (final s in specialties) s.code: s.name};
      return specialties;
    } catch (_) {
      return _cachedSpecialties ?? [];
    }
  }

  Specialty _createSpecialtyFromTab(Map<String, String> tab) {
    String code = tab['href'] ?? '';
    String name = tab['name'] ?? '';

    if (code.startsWith('#specialty-')) {
      code = code.substring(11).toUpperCase();
    } else if (code.startsWith('#')) {
      code = name;
    }

    if (name.isEmpty) {
      name = tab['ariaControls'] ?? '';
    }

    return Specialty(code: code, name: name);
  }

  String? getSpecialtyNameByCode(String code) {
    final result = _codeToNameCache?[code];
    if (result != null) return result;

    if (_codeToNameCache != null) {
      for (final entry in _codeToNameCache!.entries) {
        if (entry.value == code) return entry.value;
      }
    }

    return null;
  }
}
