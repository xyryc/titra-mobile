/// Minimal user info from `GET /users` (ignores sensitive server fields).
class PublicUser {
  const PublicUser({
    required this.id,
    required this.accountId,
    required this.profileName,
  });

  final String id;
  final String accountId;
  final String profileName;

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    return PublicUser(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      profileName: json['profileName'] as String? ?? 'User',
    );
  }
}
