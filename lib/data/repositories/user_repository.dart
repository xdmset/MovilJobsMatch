// lib/data/repositories/user_repository.dart

import '../../core/services/api_service.dart';

class UserRepository {
  UserRepository._();
  static final UserRepository instance = UserRepository._();

  final _api = ApiService.instance;

  // DELETE /api/v1/user/{user_id}
  Future<void> eliminarCuenta(int userId) async {
    await _api.delete('/user/$userId');
  }
}