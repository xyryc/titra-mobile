class CallParticipant {
  const CallParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isMuted = false,
    this.isVideoEnabled = true,
    this.isSpeaking = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isMuted;
  final bool isVideoEnabled;
  final bool isSpeaking;

  CallParticipant copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isMuted,
    bool? isVideoEnabled,
    bool? isSpeaking,
  }) {
    return CallParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}
