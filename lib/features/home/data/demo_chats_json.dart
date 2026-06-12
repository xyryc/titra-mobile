import 'dart:convert';

import 'chat_model.dart';

/// Demo chat list for the home screen. Replace with API when ready.
class DemoChatsJson {
  DemoChatsJson._();

  /// Demo profile pictures from Pravatar (https://pravatar.cc).
  static const String _raw = '''
[
  {
    "id": "chat_alice",
    "name": "Alice M.",
    "avatarUrl": "https://i.pravatar.cc/150?u=alice",
    "contactDisplayId": "849-392-1029",
    "lastMessage": "Hey, is the key updated for the new server?",
    "timestamp": "10:42 AM",
    "unreadCount": 2,
    "status": "received",
    "isNumericId": false
  },
  {
    "id": "chat_8849021102",
    "name": "884-902-1102",
    "avatarUrl": null,
    "lastMessage": "File received. Encrypted archive unlocked.",
    "timestamp": "Yesterday",
    "unreadCount": 0,
    "status": "read",
    "isNumericId": true
  },
  {
    "id": "chat_teamalpha",
    "name": "Team Alpha",
    "avatarUrl": "https://i.pravatar.cc/150?u=teamalpha",
    "lastMessage": "Meeting at 5. Bring the hardware key.",
    "timestamp": "Tuesday",
    "unreadCount": 0,
    "status": "read",
    "isNumericId": false
  },
  {
    "id": "chat_4421990012",
    "name": "442-199-0012",
    "avatarUrl": null,
    "lastMessage": "Identity verification request sent.",
    "timestamp": "Sunday",
    "unreadCount": 0,
    "status": "sent",
    "isNumericId": true
  },
  {
    "id": "chat_sarah",
    "name": "Sarah J.",
    "avatarUrl": "https://i.pravatar.cc/150?u=sarah",
    "lastMessage": "Thanks!",
    "timestamp": "Last Week",
    "unreadCount": 0,
    "status": "read",
    "isNumericId": false
  },
  {
    "id": "chat_project_omega",
    "name": "Project Omega",
    "avatarUrl": "https://i.pravatar.cc/150?u=projectomega",
    "lastMessage": "Alice M.: Sounds good. I'll share the deck before 5.",
    "timestamp": "11:20 AM",
    "unreadCount": 1,
    "status": "received",
    "isNumericId": false,
    "isGroup": true,
    "memberNames": ["Alice M.", "Bob", "Sarah J.", "You"]
  },
  {
    "id": "chat_design_team",
    "name": "Design Team",
    "avatarUrl": "https://i.pravatar.cc/150?u=designteam",
    "lastMessage": "Bob: New mockups are in the drive.",
    "timestamp": "Yesterday",
    "unreadCount": 0,
    "status": "read",
    "isNumericId": false,
    "isGroup": true,
    "memberNames": ["Alice M.", "Bob", "You"]
  }
]
''';

  static List<ChatModel> get chats {
    final list = jsonDecode(_raw) as List<dynamic>;
    return list
        .map((e) => ChatModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
