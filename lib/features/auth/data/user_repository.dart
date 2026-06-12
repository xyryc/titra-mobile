import 'package:titra/core/api/api_client.dart';
import 'package:titra/features/auth/data/models/public_user.dart';

enum UserSearchResult {
  notFound,
  isSelf,
  found,
}

class UserSearchOutcome {
  const UserSearchOutcome(this.result, [this.user]);

  final UserSearchResult result;
  final PublicUser? user;
}

/// Uses `GET /users/directory` and filters by 10-digit [accountId].
class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  Future<UserSearchOutcome> searchByAccountId({
    required String tenDigits,
    required String? currentAccountId,
  }) async {
    final response = await _api.get<dynamic>('/users/directory', showFeedback: false);
    final raw = response.data;
    List<dynamic> list;
    if (raw is Map && raw['data'] != null) {
      final data = raw['data'];
      if (data is List) {
        list = data;
      } else {
        list = [];
      }
    } else if (raw is List) {
      list = raw;
    } else {
      list = [];
    }

    PublicUser? match;
    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['accountId']?.toString();
      if (id == tenDigits) {
        match = PublicUser.fromJson(map);
        break;
      }
    }

    if (match == null) {
      return const UserSearchOutcome(UserSearchResult.notFound);
    }
    if (currentAccountId != null && match.accountId == currentAccountId) {
      return const UserSearchOutcome(UserSearchResult.isSelf);
    }
    return UserSearchOutcome(UserSearchResult.found, match);
  }
}
