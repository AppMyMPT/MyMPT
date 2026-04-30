import '../../data/models/group.dart';

abstract class GroupRepositoryInterface {
  Future<List<Group>> getGroupsBySpecialty(
    String specialtyCode, {
    bool forceRefresh = false,
  });
}
