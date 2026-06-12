import 'dart:convert';

import 'call_log_model.dart';

/// Demo call log list for the Calls tab. Replace with API when ready.
class DemoCallLogs {
  DemoCallLogs._();

  /// Demo profile pictures from Pravatar (https://pravatar.cc).
  static const String _raw = '''
[
  {
    "id": "call_1",
    "contactId": "849-392-1029",
    "contactName": "Alice M.",
    "type": "received",
    "timestamp": "10:42 AM",
    "durationSeconds": 120,
    "avatarUrl": "https://i.pravatar.cc/150?u=alice",
    "isNumericId": false
  },
  {
    "id": "call_2",
    "contactId": "884-902-1102",
    "contactName": "884-902-1102",
    "type": "missed",
    "timestamp": "Yesterday",
    "durationSeconds": null,
    "avatarUrl": null,
    "isNumericId": true
  },
  {
    "id": "call_3",
    "contactId": "team_alpha",
    "contactName": "Team Alpha",
    "type": "sent",
    "timestamp": "Yesterday",
    "durationSeconds": 45,
    "avatarUrl": "https://i.pravatar.cc/150?u=teamalpha",
    "isNumericId": false
  },
  {
    "id": "call_4",
    "contactId": "442-199-0012",
    "contactName": "442-199-0012",
    "type": "missed",
    "timestamp": "Sunday",
    "durationSeconds": null,
    "avatarUrl": null,
    "isNumericId": true
  },
  {
    "id": "call_5",
    "contactId": "sarah",
    "contactName": "Sarah J.",
    "type": "sent",
    "timestamp": "Last week",
    "durationSeconds": 320,
    "avatarUrl": "https://i.pravatar.cc/150?u=sarah",
    "isNumericId": false
  },
  {
    "id": "call_6",
    "contactId": "alice_2",
    "contactName": "Alice M.",
    "type": "missed",
    "timestamp": "Last week",
    "durationSeconds": null,
    "avatarUrl": "https://i.pravatar.cc/150?u=alice",
    "isNumericId": false
  },
  {
    "id": "call_group_audio_1",
    "contactId": "chat_project_omega",
    "contactName": "Project Omega",
    "type": "sent",
    "timestamp": "Today",
    "durationSeconds": 180,
    "avatarUrl": "https://i.pravatar.cc/150?u=projectomega",
    "isNumericId": false,
    "isGroup": true,
    "participantNames": ["Alice M.", "Bob", "Sarah J.", "You"],
    "isVideo": false
  },
  {
    "id": "call_group_video_1",
    "contactId": "chat_design_team",
    "contactName": "Design Team",
    "type": "received",
    "timestamp": "Yesterday",
    "durationSeconds": 420,
    "avatarUrl": "https://i.pravatar.cc/150?u=designteam",
    "isNumericId": false,
    "isGroup": true,
    "participantNames": ["Alice M.", "Bob", "You"],
    "isVideo": true
  },
  {
    "id": "call_group_audio_2",
    "contactId": "chat_project_omega",
    "contactName": "Project Omega",
    "type": "received",
    "timestamp": "Last week",
    "durationSeconds": 600,
    "avatarUrl": "https://i.pravatar.cc/150?u=projectomega",
    "isNumericId": false,
    "isGroup": true,
    "participantNames": ["Alice M.", "Bob", "Sarah J.", "You"],
    "isVideo": false
  }
]
''';

  static List<CallLogEntry> get callLogs {
    final list = jsonDecode(_raw) as List<dynamic>;
    return list
        .map((e) => CallLogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
