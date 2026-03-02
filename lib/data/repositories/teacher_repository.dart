import 'package:my_mpt/data/datasources/remote/teacher_remote_datasource.dart';
import 'package:my_mpt/data/models/teacher.dart';

abstract class TeacherRepositoryInterface {
  Future<List<Teacher>> getTeachers({bool forceRefresh = false});
}

class TeacherRepository implements TeacherRepositoryInterface {
  TeacherRepository({TeacherRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? TeacherRemoteDatasource();

  final TeacherRemoteDatasource _remoteDatasource;

  @override
  Future<List<Teacher>> getTeachers({bool forceRefresh = false}) {
    return _remoteDatasource.fetchTeachers(forceRefresh: forceRefresh);
  }
}
