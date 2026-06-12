class UserSummary {
  const UserSummary({
    required this.id,
    required this.accountId,
    required this.profileName,
    this.profileImageUrl,
  });

  final String id;
  final String accountId;
  final String profileName;
  final String? profileImageUrl;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final image = json['profileImageUrl'];
    return UserSummary(
      id: json['id']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      profileName: json['profileName']?.toString() ?? 'User',
      profileImageUrl: image != null && image.toString().isNotEmpty ? image.toString() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'profileName': profileName,
        'profileImageUrl': profileImageUrl,
      };
}
