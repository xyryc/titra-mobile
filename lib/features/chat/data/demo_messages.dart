import 'message_model.dart';

/// Demo messages for the Alice conversation (chat_alice). Used when opening that chat.
class DemoMessages {
  DemoMessages._();

  static List<MessageModel> get aliceConversation => [
        const MessageModel(
          id: 'm1',
          text: 'Hey! Did you get the secure file for the Project Omega review?',
          isFromMe: false,
          timestamp: '10:42 AM',
        ),
        const MessageModel(
          id: 'm2',
          text: 'Yes, just downloading it now. Give me a sec to decrypt it.',
          isFromMe: true,
          timestamp: '10:43 AM',
          status: MessageStatus.delivered,
        ),
        const MessageModel(
          id: 'm3',
          text: "Here's the decrypted chart.",
          imageUrl: null,
          isFromMe: true,
          timestamp: '10:45 AM',
          status: MessageStatus.read,
        ),
        const MessageModel(
          id: 'm4',
          text: "Great. Looks clean. Let's switch to video call in 5 to discuss the anomalies.",
          isFromMe: false,
          timestamp: '10:46 AM',
        ),
        const MessageModel(
          id: 'm5',
          text: 'Sounds good. 🎥',
          isFromMe: true,
          timestamp: '10:46 AM',
          status: MessageStatus.sent,
        ),
      ];

  /// Returns demo messages for any chat. 1v1 chats use conversation lists; groups use groupConversation.
  static List<MessageModel>? forChat(String chatId) {
    if (chatId == 'chat_alice') return aliceConversation;
    if (chatId == 'chat_sarah') return sarahConversation;
    if (chatId == 'chat_8849021102') return numericIdConversation;
    if (chatId == 'chat_teamalpha') return teamAlphaConversation;
    if (chatId == 'chat_4421990012') return verificationConversation;
    if (chatId == 'chat_project_omega') return projectOmegaConversation;
    if (chatId == 'chat_design_team') return designTeamConversation;
    return null;
  }

  /// Demo messages for group chats. Returns messages with senderName for group UI.
  /// [chatId] can be e.g. "chat_project_omega" or "chat_design_team".
  static List<MessageModel> groupConversation(String chatId) {
    if (chatId == 'chat_design_team') {
      return designTeamConversation;
    }
    return projectOmegaConversation;
  }

  static List<MessageModel> get sarahConversation => [
        const MessageModel(
          id: 's1',
          text: 'Hi! Are we still on for lunch tomorrow?',
          isFromMe: false,
          timestamp: 'Last Week',
        ),
        const MessageModel(
          id: 's2',
          text: 'Yes, 1pm at the usual place?',
          isFromMe: true,
          timestamp: 'Last Week',
          status: MessageStatus.read,
        ),
        const MessageModel(
          id: 's3',
          text: 'Perfect. See you then!',
          isFromMe: false,
          timestamp: 'Last Week',
        ),
        const MessageModel(
          id: 's4',
          text: 'Thanks!',
          isFromMe: true,
          timestamp: 'Last Week',
          status: MessageStatus.read,
        ),
      ];

  static List<MessageModel> get numericIdConversation => [
        const MessageModel(
          id: 'n1',
          text: 'Sending the encrypted archive now.',
          isFromMe: true,
          timestamp: 'Yesterday',
          status: MessageStatus.read,
        ),
        const MessageModel(
          id: 'n2',
          text: 'File received. Encrypted archive unlocked.',
          isFromMe: false,
          timestamp: 'Yesterday',
        ),
        const MessageModel(
          id: 'n3',
          text: 'Key rotation completed on my side.',
          isFromMe: false,
          timestamp: 'Yesterday',
        ),
        const MessageModel(
          id: 'n4',
          text: 'Noted. All channels verified.',
          isFromMe: true,
          timestamp: 'Yesterday',
          status: MessageStatus.read,
        ),
      ];

  static List<MessageModel> get teamAlphaConversation => [
        const MessageModel(
          id: 't1',
          text: 'Reminder: sync at 5 today.',
          isFromMe: false,
          timestamp: 'Tuesday',
        ),
        const MessageModel(
          id: 't2',
          text: 'Meeting at 5. Bring the hardware key.',
          isFromMe: false,
          timestamp: 'Tuesday',
        ),
        const MessageModel(
          id: 't3',
          text: "I'll be there. Key ready.",
          isFromMe: true,
          timestamp: 'Tuesday',
          status: MessageStatus.read,
        ),
      ];

  static List<MessageModel> get verificationConversation => [
        const MessageModel(
          id: 'v1',
          text: 'Identity verification request sent.',
          isFromMe: true,
          timestamp: 'Sunday',
          status: MessageStatus.sent,
        ),
        const MessageModel(
          id: 'v2',
          text: 'Request received. Processing.',
          isFromMe: false,
          timestamp: 'Sunday',
        ),
        const MessageModel(
          id: 'v3',
          text: 'Verification complete. You can proceed.',
          isFromMe: false,
          timestamp: 'Sunday',
        ),
      ];

  static List<MessageModel> get projectOmegaConversation => [
        const MessageModel(
          id: 'g1',
          text: "Everyone: we're locking the scope for Phase 2 today. Please confirm by EOD.",
          isFromMe: false,
          timestamp: '10:15 AM',
          senderName: 'Alice M.',
          senderAvatarUrl: 'https://i.pravatar.cc/150?u=alice',
        ),
        const MessageModel(
          id: 'g2',
          text: 'Confirmed from my side.',
          isFromMe: false,
          timestamp: '10:18 AM',
          senderName: 'Bob',
          senderAvatarUrl: 'https://i.pravatar.cc/150?u=bob',
        ),
        const MessageModel(
          id: 'g3',
          text: "I'll need until tomorrow for the security review. Is that ok?",
          isFromMe: true,
          timestamp: '10:22 AM',
          status: MessageStatus.read,
          senderName: 'You',
        ),
        const MessageModel(
          id: 'g4',
          text: 'Yes, that works. Sarah will sync with you.',
          isFromMe: false,
          timestamp: '10:25 AM',
          senderName: 'Alice M.',
          senderAvatarUrl: 'https://i.pravatar.cc/150?u=alice',
        ),
        const MessageModel(
          id: 'g5',
          text: 'Sounds good. I\'ll share the deck before 5.',
          isFromMe: false,
          timestamp: '11:20 AM',
          senderName: 'Alice M.',
          senderAvatarUrl: 'https://i.pravatar.cc/150?u=alice',
        ),
      ];

  static List<MessageModel> get designTeamConversation => [
        const MessageModel(
          id: 'd1',
          text: 'Quick sync at 3pm?',
          isFromMe: false,
          timestamp: '2:00 PM',
          senderName: 'Alice M.',
          senderAvatarUrl: 'https://i.pravatar.cc/150?u=alice',
        ),
        const MessageModel(
          id: 'd2',
          text: "I'm in.",
          isFromMe: true,
          timestamp: '2:05 PM',
          status: MessageStatus.read,
          senderName: 'You',
        ),
        const MessageModel(
          id: 'd3',
          text: 'New mockups are in the drive.',
          isFromMe: false,
          timestamp: 'Yesterday',
          senderName: 'Bob',
          senderAvatarUrl: 'https://i.pravatar.cc/150?u=bob',
        ),
      ];
}
