import '../entities/specialty.dart';

abstract class SpecialtyRepositoryInterface {
  Future<List<Specialty>> getSpecialties({bool forceRefresh = false});
}
