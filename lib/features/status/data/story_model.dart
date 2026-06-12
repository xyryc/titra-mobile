/// Media type for a story.
enum StoryMediaType {
  image,
  video,
}

/// Single story item (one image or video in a user's story sequence).
class StoryModel {
  const StoryModel({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    this.durationSeconds,
  });

  final String id;
  final String userId;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final String? caption;
  final DateTime createdAt;
  /// For video; for image use default 4–5s in viewer.
  final int? durationSeconds;

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'];
    return StoryModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      mediaType: json['mediaType'] == 'video' ? StoryMediaType.video : StoryMediaType.image,
      caption: json['caption'] as String?,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType == StoryMediaType.video ? 'video' : 'image',
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }
}

/// Contact with stories for the Status list (id, name, avatar, stories).
class StatusContact {
  const StatusContact({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.stories,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final List<StoryModel> stories;

  /// Latest story timestamp for "time ago" display.
  DateTime? get latestStoryAt => stories.isEmpty ? null : stories.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);

  factory StatusContact.fromJson(Map<String, dynamic> json) {
    final storiesRaw = json['stories'];
    final stories = storiesRaw is List
        ? storiesRaw
            .whereType<Map>()
            .map((e) => StoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <StoryModel>[];
    final avatar = json['avatarUrl'];
    return StatusContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'User',
      avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
      stories: stories,
    );
  }
}

/// One row from `GET /stories/:id/viewers`.
class StoryViewer {
  const StoryViewer({
    required this.userId,
    required this.profileName,
    this.profileImageUrl,
    required this.accountId,
    required this.viewedAt,
  });

  final String userId;
  final String profileName;
  final String? profileImageUrl;
  final String accountId;
  final DateTime viewedAt;

  factory StoryViewer.fromJson(Map<String, dynamic> json) {
    final viewedRaw = json['viewedAt'];
    return StoryViewer(
      userId: json['userId']?.toString() ?? '',
      profileName: json['profileName']?.toString() ?? 'User',
      profileImageUrl: () {
        final u = json['profileImageUrl'];
        return u is String && u.isNotEmpty ? u : null;
      }(),
      accountId: json['accountId']?.toString() ?? '',
      viewedAt: viewedRaw is String ? DateTime.tryParse(viewedRaw) ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Returns true if [createdAt] is within the last 24 hours.
bool isWithinLast24Hours(DateTime createdAt) {
  return DateTime.now().difference(createdAt) < const Duration(hours: 24);
}

/// Filters stories to only those within the last 24 hours.
List<StoryModel> filterStoriesWithin24Hours(List<StoryModel> stories) {
  return stories.where((s) => isWithinLast24Hours(s.createdAt)).toList();
}
