// import 'dart:async';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:provider/provider.dart';
// import 'package:titra/core/realtime/realtime_service.dart';
// import 'package:titra/core/services/snackbar_service.dart';
// import 'package:titra/core/session/session_controller.dart';
// import 'package:titra/core/theme/app_colors.dart';
// import 'package:titra/core/utils/titra_id_utils.dart';
// import 'package:titra/features/call/presentation/view/audio_call_screen.dart';
// import 'package:titra/features/call/presentation/view/group_audio_call_screen.dart';
// import 'package:titra/features/call/presentation/view/group_video_call_screen.dart';
// import 'package:titra/features/call/presentation/view/video_call_screen.dart';
// import 'package:titra/features/chat/data/message_model.dart';
// import 'package:titra/features/chat/data/messaging_repository.dart';
// import 'package:titra/features/chat/presentation/view_models/chat_view_model.dart';
// import 'package:titra/features/chat/presentation/widgets/mic_hold_record_button.dart';
// import 'package:titra/features/chat/presentation/widgets/voice_message_bar.dart';
// import 'package:titra/features/bottom_navigation/presentation/view/bottom_nav_screen.dart';
// import 'package:titra/features/home/data/conversations_repository.dart';
//
// class ChatScreen extends StatelessWidget {
//   const ChatScreen({
//     super.key,
//     required this.contactName,
//     required this.contactId,
//     this.conversationId,
//     this.avatarUrl,
//     this.isGroup = false,
//     this.participantNames,
//     this.messagingEnabled = true,
//     this.peerUserId,
//     this.groupMemberUserIds,
//     this.openedFromNotification = false,
//   });
//
//   final String contactName;
//   final String contactId;
//   final String? conversationId;
//   final String? avatarUrl;
//   final bool isGroup;
//   final List<String>? participantNames;
//   final bool messagingEnabled;
//   final String? peerUserId;
//   final List<String>? groupMemberUserIds;
//   final bool openedFromNotification;
//
//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (ctx) => ChatViewModel(
//         sessionController: ctx.read<SessionController>(),
//         conversationsRepository: ctx.read<ConversationsRepository>(),
//         messagingRepository: ctx.read<MessagingRepository>(),
//         snackbarService: ctx.read<SnackbarService>(),
//         realtimeService: ctx.read<RealtimeService>(),
//         contactName: contactName,
//         contactId: contactId,
//         conversationId: conversationId,
//         avatarUrl: avatarUrl,
//         isGroup: isGroup,
//         participantNames: participantNames,
//         messagingEnabled: messagingEnabled,
//         peerUserId: peerUserId,
//         groupMemberUserIds: groupMemberUserIds,
//       )..bootstrap(), //Called ONLY ONCE during provider creation
//       child: _ChatView(openedFromNotification: openedFromNotification),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _ChatView extends StatefulWidget {
//   const _ChatView({required this.openedFromNotification});
//
//   final bool openedFromNotification;
//
//   @override
//   State<_ChatView> createState() => _ChatViewState();
// }
//
// class _ChatViewState extends State<_ChatView> {
//   // ── Call helpers ─────────────────────────────────────────────────────────────
//
//   Future<void> _handleBack(BuildContext context) async {
//     final nav = Navigator.of(context, rootNavigator: true);
//     if (await nav.maybePop()) return;
//     if (!context.mounted) return;
//     await nav.pushReplacement<void, void>(
//       MaterialPageRoute<void>(builder: (_) => const BottomWrapperScreen()),
//     );
//   }
//
//   Future<void> _startOutgoingCall(
//     BuildContext context,
//     ChatViewModel vm, {
//     required bool video,
//   }) async {
//     if (vm.isGroup) return;
//     final snack = context.read<SnackbarService>();
//     final ok = await vm.ensurePeerForCall();
//     if (!context.mounted) return;
//     if (!ok || vm.effectiveConversationId == null) {
//       snack.showError('Could not start call. Open chat when online.');
//       return;
//     }
//     final conv = vm.effectiveConversationId!;
//     final peer = vm.effectivePeerUserId!;
//     await Navigator.of(context).push<void>(
//       MaterialPageRoute<void>(
//         builder: (_) => video
//             ? VideoCallScreen(
//                 contactName: vm.contactName,
//                 contactId: vm.contactId,
//                 conversationId: conv,
//                 peerUserId: peer,
//                 isOutgoing: true,
//                 avatarUrl: vm.avatarUrl,
//               )
//             : AudioCallScreen(
//                 contactName: vm.contactName,
//                 contactId: vm.contactId,
//                 conversationId: conv,
//                 peerUserId: peer,
//                 isOutgoing: true,
//                 avatarUrl: vm.avatarUrl,
//               ),
//       ),
//     );
//   }
//
//   Future<void> _startGroupOutgoingCall(
//     BuildContext context,
//     ChatViewModel vm, {
//     required bool video,
//   }) async {
//     final snack = context.read<SnackbarService>();
//     final ok = await vm.ensureGroupMembersForCall();
//     if (!context.mounted) return;
//     if (!ok || vm.remoteUserIdsForGroupCall.isEmpty) {
//       snack.showError('Could not load group members for call.');
//       return;
//     }
//     if (vm.remoteUserIdsForGroupCall.length > 4) {
//       snack.showError('Group calls support up to 4 other participants.');
//       return;
//     }
//     final ids = vm.remoteUserIdsForGroupCall;
//     final names = vm.participantNames;
//     final peerNames = <String, String>{};
//     for (var i = 0; i < ids.length; i++) {
//       peerNames[ids[i]] = (names != null && i < names.length)
//           ? names[i]
//           : 'User';
//     }
//     final conv = vm.effectiveConversationId!;
//     await Navigator.of(context).push<void>(
//       MaterialPageRoute<void>(
//         builder: (_) => video
//             ? GroupVideoCallScreen(
//                 groupName: vm.contactName,
//                 conversationId: conv,
//                 remotePeerUserIds: ids,
//                 peerNamesById: peerNames,
//                 isOutgoing: true,
//               )
//             : GroupAudioCallScreen(
//                 groupName: vm.contactName,
//                 conversationId: conv,
//                 remotePeerUserIds: ids,
//                 peerNamesById: peerNames,
//                 isOutgoing: true,
//               ),
//       ),
//     );
//   }
//
//   // ── Build ────────────────────────────────────────────────────────────────────
//
//   final TextEditingController messageController = TextEditingController();
//   final FocusNode messageFocus = FocusNode();
//
//
//   @override
//   Widget build(BuildContext context) {
//     final vm = context.watch<ChatViewModel>();
//     return PopScope<void>(
//       canPop: !widget.openedFromNotification,
//       onPopInvokedWithResult: (didPop, _) {
//         if (didPop || !widget.openedFromNotification) return;
//         _handleBack(context);
//       },
//       child: Scaffold(
//         backgroundColor: const Color(0xFFFFFFFF),
//         body: GestureDetector(
//           behavior: HitTestBehavior.translucent,
//           onTap: () {
//             FocusScope.of(context).unfocus();
//           },
//           child: Stack(
//             children: [
//               // Subtle top tint
//               Positioned(
//                 top: 0,
//                 left: 0,
//                 right: 0,
//                 height: 200,
//                 child: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [
//                         AppColors.primary.withValues(alpha: 0.06),
//                         Colors.transparent,
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//               Column(
//                 children: [
//                   _buildHeader(context, vm),
//                   Expanded(child: _buildMessageBody(context, vm)),
//                   _buildInputFooter(context, vm),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Header ───────────────────────────────────────────────────────────────────
//
//   Widget _buildHeader(BuildContext context, ChatViewModel vm) {
//     final topPadding = MediaQuery.of(context).padding.top;
//
//     final hasAvatar = vm.avatarUrl != null && vm.avatarUrl!.isNotEmpty;
//     final title = vm.contactName.trim().isNotEmpty ? vm.contactName : 'Chat';
//     final subtitle = vm.isGroup && vm.participantNames != null
//         ? '${vm.participantNames!.length} participants'
//         : vm.peerOnline
//         ? 'Online'
//         : 'ID: ${formatTitraIdWithPrefix(vm.contactId)}';
//
//     return Container(
//       padding: EdgeInsets.fromLTRB(6, topPadding + 6, 10, 10),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8FAFC).withValues(alpha: 0.98),
//         border: Border(bottom: BorderSide(color: AppColors.outlineLight)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.04),
//             blurRadius: 12,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           IconButton(
//             onPressed: () => _handleBack(context),
//             icon: const Icon(Icons.arrow_back_ios_new_rounded),
//             iconSize: 20,
//             color: AppColors.primary,
//             splashRadius: 22,
//           ),
//
//           Stack(
//             clipBehavior: Clip.none,
//             children: [
//               CircleAvatar(
//                 radius: 23,
//                 backgroundColor: AppColors.primary.withValues(alpha: 0.12),
//                 backgroundImage: hasAvatar ? NetworkImage(vm.avatarUrl!) : null,
//                 child: !hasAvatar
//                     ? Text(
//                         title[0].toUpperCase(),
//                         style: const TextStyle(
//                           color: AppColors.primary,
//                           fontWeight: FontWeight.w800,
//                           fontSize: 18,
//                         ),
//                       )
//                     : null,
//               ),
//
//               if (!vm.isGroup && vm.peerOnline)
//                 Positioned(
//                   right: 1,
//                   bottom: 1,
//                   child: Container(
//                     width: 13,
//                     height: 13,
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF22C55E),
//                       shape: BoxShape.circle,
//                       border: Border.all(color: Colors.white, width: 2),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//
//           const SizedBox(width: 12),
//
//           Expanded(
//             child: InkWell(
//               borderRadius: BorderRadius.circular(12),
//               onTap: () {
//                 // Optional: open profile / group info screen
//               },
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 4),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       title,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 17,
//                         fontWeight: FontWeight.w800,
//                         color: AppColors.onBackgroundLight,
//                         letterSpacing: -0.2,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       subtitle,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         fontSize: 12.5,
//                         color: vm.peerOnline && !vm.isGroup
//                             ? const Color(0xFF16A34A)
//                             : Colors.grey.shade600,
//                         fontWeight: vm.peerOnline && !vm.isGroup
//                             ? FontWeight.w600
//                             : FontWeight.w400,
//                         fontFamily: vm.isGroup || vm.peerOnline
//                             ? null
//                             : 'monospace',
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(width: 6),
//
//           _HeaderActionButton(
//             icon: Icons.videocam_rounded,
//             enabled: vm.isGroup ? vm.canPlaceGroupWebrtcCall : true,
//             onTap: () {
//               if (vm.isGroup) {
//                 _startGroupOutgoingCall(context, vm, video: true);
//               } else {
//                 _startOutgoingCall(context, vm, video: true);
//               }
//             },
//           ),
//
//           const SizedBox(width: 6),
//
//           _HeaderActionButton(
//             icon: Icons.call_rounded,
//             enabled: vm.isGroup ? vm.canPlaceGroupWebrtcCall : true,
//             onTap: () {
//               if (vm.isGroup) {
//                 _startGroupOutgoingCall(context, vm, video: false);
//               } else {
//                 _startOutgoingCall(context, vm, video: false);
//               }
//             },
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Message body ─────────────────────────────────────────────────────────────
//
//   Widget _buildMessageBody(BuildContext context, ChatViewModel vm) {
//     if (vm.messagingEnabled && vm.loading && vm.messages.isEmpty) {
//       return const Center(
//         child: CircularProgressIndicator(color: AppColors.primary),
//       );
//     }
//     if (vm.messagingEnabled && vm.loadError != null && vm.messages.isEmpty) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 vm.loadError!,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: Colors.grey.shade700),
//               ),
//               const SizedBox(height: 16),
//               FilledButton(
//                 onPressed: () => vm.bootstrap(),
//                 child: const Text('Retry'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//     return ListView(
//       reverse: true,
//       controller: vm.messageScrollController,
//       padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
//       children: [
//         ...vm.messages.reversed.map(
//           (m) => _MessageBubble(
//             message: m,
//             avatarUrl: m.isFromMe ? null : (m.senderAvatarUrl ?? vm.avatarUrl),
//             contactName: m.isFromMe
//                 ? vm.contactName
//                 : (m.senderName ?? vm.contactName),
//             showSenderLabel: vm.isGroup && !m.isFromMe && m.senderName != null,
//             onCallLogTap: vm.isGroup
//                 ? null
//                 : (video) => _startOutgoingCall(context, vm, video: video),
//           ),
//         ),
//
//         const SizedBox(height: 16),
//
//         const Center(
//           child: Text(
//             'Today',
//             style: TextStyle(
//               fontSize: 12,
//               color: Color(0xFF94A3B8),
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//
//         const SizedBox(height: 16),
//
//         // TOP BAR (because reverse: true)
//         Center(child: _buildEncryptedBanner()),
//       ],
//     );
//   }
//
//   Widget _buildEncryptedBanner() {
//     return Center(
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         decoration: BoxDecoration(
//           color: Colors.grey.shade200.withValues(alpha: 0.8),
//           borderRadius: BorderRadius.circular(999),
//           border: Border.all(color: Colors.white54),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.lock_rounded, size: 14, color: Colors.grey.shade600),
//             const SizedBox(width: 6),
//             Text(
//               'Messages are End-to-End Encrypted',
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey.shade700,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Input footer ─────────────────────────────────────────────────────────────
//
//   Widget _buildInputFooter(BuildContext context, ChatViewModel vm) {
//     final bottomPad = MediaQuery.of(context).padding.bottom;
//
//     // Messaging disabled
//     if (!vm.messagingEnabled) {
//       return _FooterShell(
//         bottomPad: bottomPad,
//         child: Row(
//           children: [
//             Icon(
//               Icons.info_outline_rounded,
//               color: AppColors.primary.withValues(alpha: 0.85),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 'Messaging is not connected yet. You can start a chat in a future update.',
//                 style: TextStyle(
//                   fontSize: 13,
//                   color: Colors.grey.shade700,
//                   height: 1.35,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     // Error banner (messages already loaded)
//     if (vm.loadError != null && vm.messages.isNotEmpty) {
//       return Container(
//         width: double.infinity,
//         padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomPad),
//         color: Colors.orange.shade50,
//         child: Row(
//           children: [
//             Icon(
//               Icons.warning_amber_rounded,
//               size: 20,
//               color: Colors.orange.shade800,
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 vm.loadError!,
//                 style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
//               ),
//             ),
//             TextButton(
//               onPressed: () => vm.bootstrap(),
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }
//
//     // Initial loading
//     if (vm.loading && vm.messages.isEmpty) {
//       return _FooterShell(
//         bottomPad: bottomPad,
//         child: Row(
//           children: [
//             const SizedBox(
//               width: 22,
//               height: 22,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: AppColors.primary,
//               ),
//             ),
//             const SizedBox(width: 12),
//             Text(
//               'Connecting…',
//               style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
//             ),
//           ],
//         ),
//       );
//     }
//
//     // Main composer
//     final canUseInput = vm.inputEnabled;
//     final canEditInput =
//         vm.messagingEnabled &&
//         !vm.loading &&
//         vm.loadError == null &&
//         vm.effectiveConversationId != null;
//
//     return SafeArea(
//       top: false,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//         decoration: BoxDecoration(color: Colors.transparent),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // Peer typing indicator
//             if (vm.peerTyping)
//               Padding(
//                 padding: const EdgeInsets.only(left: 4, bottom: 6),
//                 child: Row(
//                   children: [
//                     // Text(
//                     //   vm.peerTypingLabel,
//                     //   style: TextStyle(
//                     //     fontSize: 12,
//                     //     color: Colors.grey.shade600,
//                     //     fontStyle: FontStyle.italic,
//                     //   ),
//                     // ),
//                     const SizedBox(width: 6),
//                     const _TypingDots(),
//                   ],
//                 ),
//               ),
//
//             // Input pill row
//             Row(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 // Attach
//                 _CircleIconButton(
//                   icon: Icons.add_rounded,
//                   onPressed: canUseInput
//                       ? () => _showAttachBottomSheet(context, vm)
//                       : null,
//                 ),
//                 const SizedBox(width: 6),
//
//                 // Text field pill
//                 Expanded(
//                   child: Container(
//                     constraints: const BoxConstraints(minHeight: 44),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 4,
//                       vertical: 4,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(22),
//                       border: Border.all(color: Colors.grey.shade300),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         Expanded(
//                           child: // TextField — use vm's controller and focus node
//                           TextField(
//                             focusNode: vm.messageFocusNode,      // ← vm's focus node
//                             controller: vm.inputController,      // ← vm's controller
//                             enabled: canEditInput,
//                             keyboardType: TextInputType.multiline,
//                             textInputAction: TextInputAction.newline,
//                             minLines: 1,
//                             maxLines: 5,
//                             style: const TextStyle(fontSize: 15, height: 1.4),
//                             decoration: InputDecoration(
//                               hintText: 'Aa',
//                               hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
//                               border: InputBorder.none,
//                               isDense: true,
//                               contentPadding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
//                             ),
//                             onChanged: (_) => vm.onComposerTextChanged(),
//                             onSubmitted: (_) {
//                               if (canUseInput) vm.sendMessage();
//                               // No need to re-request focus here; vm.sendMessage() already does it
//                             },
//                           ),
//                         ),
//                         // Emoji (bottom-aligned inside pill)
//                         Padding(
//                           padding: const EdgeInsets.only(bottom: 2, right: 2),
//                           child: _CircleIconButton(
//                             icon: Icons.emoji_emotions_outlined,
//                             size: 20,
//                             diameter: 32,
//                             color: Colors.grey.shade400,
//                             onPressed: canUseInput
//                                 ? () => _showEmojiPicker(context, vm)
//                                 : null,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//
//                 const SizedBox(width: 6),
//
//                 // Send / mic
//                 ListenableBuilder(
//                   listenable: vm.inputController,
//                   builder: (context, _) {
//                     final hasText = vm.inputController.text.trim().isNotEmpty;
//                     if (hasText) {
//                       return _SendButton(
//                         sending: vm.sending,
//                         enabled: canUseInput,
//                           onTap: () => vm.sendMessage()
//                       );
//                     }
//                     return MicHoldRecordButton(
//                       enabled: canUseInput,
//                       busy: vm.sending,
//                       onShortTap: vm.showVoiceRecordHint,
//                       onVoiceCommitted: vm.sendVoiceFromFile,
//                       onPermissionDenied: () {
//                         context.read<SnackbarService>().showError(
//                           'Microphone permission is required to record voice.',
//                         );
//                       },
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Bottom sheets ─────────────────────────────────────────────────────────────
//
//   void _showAttachBottomSheet(BuildContext context, ChatViewModel vm) {
//     Future<void> pickAndSend(ImageSource source) async {
//       final picker = ImagePicker();
//       final x = await picker.pickImage(
//         source: source,
//         imageQuality: 85,
//         maxWidth: 2048,
//       );
//       if (x == null) return;
//       await vm.sendImageFromPath(x.path);
//     }
//
//     showModalBottomSheet<void>(
//       context: context,
//       backgroundColor: Colors.transparent,
//       builder: (ctx) => Container(
//         decoration: BoxDecoration(
//           color: Theme.of(ctx).scaffoldBackgroundColor,
//           borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//         ),
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(ctx).padding.bottom + 16,
//         ),
//         child: SafeArea(
//           top: false,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const SizedBox(height: 12),
//               Container(
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade300,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 'Attachment',
//                 style: Theme.of(
//                   ctx,
//                 ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 16),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   _attachOption(ctx, Icons.camera_alt_rounded, 'Camera', () {
//                     Navigator.pop(ctx);
//                     Future<void>.microtask(
//                       () => pickAndSend(ImageSource.camera),
//                     );
//                   }),
//                   _attachOption(
//                     ctx,
//                     Icons.photo_library_rounded,
//                     'Gallery',
//                     () {
//                       Navigator.pop(ctx);
//                       Future<void>.microtask(
//                         () => pickAndSend(ImageSource.gallery),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _attachOption(
//     BuildContext context,
//     IconData icon,
//     String label,
//     VoidCallback onTap,
//   ) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(12),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, size: 28, color: AppColors.primary),
//             const SizedBox(height: 6),
//             Text(
//               label,
//               style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _showEmojiPicker(BuildContext context, ChatViewModel vm) {
//     const emojis = [
//       '😀',
//       '😃',
//       '😄',
//       '😁',
//       '😅',
//       '😂',
//       '🤣',
//       '😊',
//       '😇',
//       '🙂',
//       '😉',
//       '😍',
//       '🥰',
//       '😘',
//       '😗',
//       '👍',
//       '👎',
//       '👏',
//       '🙌',
//       '❤️',
//       '🧡',
//       '💛',
//       '💚',
//       '💙',
//       '💜',
//       '💕',
//       '💯',
//       '🎉',
//       '🔥',
//       '✨',
//       '⭐',
//       '🙏',
//     ];
//     showModalBottomSheet<void>(
//       context: context,
//       backgroundColor: Colors.transparent,
//       builder: (ctx) => Container(
//         height: 280,
//         decoration: BoxDecoration(
//           color: Theme.of(ctx).scaffoldBackgroundColor,
//           borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//         ),
//         padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 8),
//         child: SafeArea(
//           top: false,
//           child: Column(
//             children: [
//               const SizedBox(height: 8),
//               Container(
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade300,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 'Emoji',
//                 style: Theme.of(
//                   ctx,
//                 ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 12),
//               Expanded(
//                 child: GridView.builder(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: 8,
//                     mainAxisSpacing: 4,
//                     crossAxisSpacing: 4,
//                     childAspectRatio: 1,
//                   ),
//                   itemCount: emojis.length,
//                   itemBuilder: (_, i) => InkWell(
//                     onTap: () {
//                       vm.insertEmoji(emojis[i]);
//                       Navigator.pop(ctx);
//                     },
//                     borderRadius: BorderRadius.circular(8),
//                     child: Center(
//                       child: Text(
//                         emojis[i],
//                         style: const TextStyle(fontSize: 24),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Shared footer shell (disabled / loading states)
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _FooterShell extends StatelessWidget {
//   const _FooterShell({required this.child, required this.bottomPad});
//
//   final Widget child;
//   final double bottomPad;
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF2F4F7).withValues(alpha: 0.95),
//         border: Border(top: BorderSide(color: AppColors.outlineLight)),
//       ),
//       child: child,
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Circle icon button
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _CircleIconButton extends StatelessWidget {
//   const _CircleIconButton({
//     required this.icon,
//     this.onPressed,
//     this.size = 24,
//     this.diameter = 38,
//     this.color,
//   });
//
//   final IconData icon;
//   final VoidCallback? onPressed;
//   final double size;
//   final double diameter;
//   final Color? color;
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: diameter,
//       height: diameter,
//       child: Material(
//         color: Colors.black12,
//         shape: const CircleBorder(),
//         child: InkWell(
//           onTap: onPressed,
//           customBorder: const CircleBorder(),
//           child: Icon(
//             icon,
//             size: size,
//             color: onPressed == null
//                 ? Colors.grey.shade300
//                 : (color ?? Colors.grey.shade600),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Send button
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _SendButton extends StatelessWidget {
//   const _SendButton({
//     required this.sending,
//     required this.enabled,
//     required this.onTap,
//   });
//
//   final bool sending;
//   final bool enabled;
//   final VoidCallback onTap;
//
//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: enabled
//           ? AppColors.primary
//           : AppColors.primary.withValues(alpha: 0.45),
//       shape: const CircleBorder(),
//       elevation: enabled ? 2 : 0,
//       shadowColor: AppColors.primary.withValues(alpha: 0.4),
//       child: InkWell(
//         onTap: (enabled && !sending) ? onTap : null,
//         customBorder: const CircleBorder(),
//         child: SizedBox(
//           width: 40,
//           height: 40,
//           child: sending
//               ? const Padding(
//                   padding: EdgeInsets.all(10),
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: Colors.white,
//                   ),
//                 )
//               : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Outgoing status icon
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _OutgoingStatusIcon extends StatelessWidget {
//   const _OutgoingStatusIcon({required this.status});
//
//   final MessageStatus status;
//
//   @override
//   Widget build(BuildContext context) {
//     final grey = Colors.grey.shade500;
//     switch (status) {
//       case MessageStatus.pending:
//         return Icon(Icons.schedule_rounded, size: 14, color: grey);
//       case MessageStatus.sent:
//         return Icon(Icons.done_rounded, size: 14, color: grey);
//       case MessageStatus.delivered:
//         return Icon(Icons.done_all_rounded, size: 14, color: grey);
//       case MessageStatus.read:
//         return Icon(Icons.done_all_rounded, size: 14, color: AppColors.primary);
//       case MessageStatus.failed:
//         return const Icon(
//           Icons.error_outline_rounded,
//           size: 14,
//           color: Color(0xFFDC2626),
//         );
//     }
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Message bubble
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _MessageBubble extends StatelessWidget {
//   const _MessageBubble({
//     required this.message,
//     this.avatarUrl,
//     required this.contactName,
//     this.showSenderLabel = false,
//     this.onCallLogTap,
//   });
//
//   final MessageModel message;
//   final String? avatarUrl;
//   final String contactName;
//   final bool showSenderLabel;
//   final Future<void> Function(bool video)? onCallLogTap;
//
//   @override
//   Widget build(BuildContext context) {
//     final isMe = message.isFromMe;
//     final maxWidth = MediaQuery.of(context).size.width * 0.78;
//
//     return Padding(
//       padding: EdgeInsets.only(
//         left: isMe ? 56 : 12,
//         right: isMe ? 12 : 56,
//         bottom: 10,
//       ),
//       child: Row(
//         mainAxisAlignment: isMe
//             ? MainAxisAlignment.end
//             : MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           if (!isMe) ...[
//             _BubbleAvatar(avatarUrl: avatarUrl, name: contactName),
//             const SizedBox(width: 8),
//           ],
//
//           Flexible(
//             child: Column(
//               crossAxisAlignment: isMe
//                   ? CrossAxisAlignment.end
//                   : CrossAxisAlignment.start,
//               children: [
//                 if (!isMe && showSenderLabel && message.senderName != null)
//                   Padding(
//                     padding: const EdgeInsets.only(left: 4, bottom: 4),
//                     child: Text(
//                       message.senderName!,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w700,
//                         color: AppColors.primary,
//                       ),
//                     ),
//                   ),
//
//                 Container(
//                   constraints: BoxConstraints(maxWidth: maxWidth),
//                   clipBehavior: Clip.antiAlias,
//                   decoration: BoxDecoration(
//                     color: isMe
//                         ? AppColors.primary.withValues(alpha: 0.13)
//                         : AppColors.outlineLight.withValues(alpha: 0.30),
//                     borderRadius: BorderRadius.only(
//                       topLeft: const Radius.circular(14),
//                       topRight: const Radius.circular(14),
//                       bottomLeft: Radius.circular(isMe ? 10 : 0),
//                       bottomRight: Radius.circular(isMe ? 0 : 10),
//                     ),
//                     border: Border.all(
//                       color: isMe
//                           ? AppColors.primary.withValues(alpha: 0.18)
//                           : AppColors.outlineLight,
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withValues(alpha: 0.035),
//                         blurRadius: 10,
//                         offset: const Offset(0, 3),
//                       ),
//                     ],
//                   ),
//                   child: _buildBubbleContent(context),
//                 ),
//
//                 const SizedBox(height: 4),
//
//                 Padding(
//                   padding: EdgeInsets.only(
//                     left: isMe ? 0 : 4,
//                     right: isMe ? 4 : 0,
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         message.timestamp,
//                         style: TextStyle(
//                           fontSize: 10.5,
//                           color: Colors.grey.shade500,
//                         ),
//                       ),
//                       if (isMe) ...[
//                         const SizedBox(width: 4),
//                         _OutgoingStatusIcon(status: message.status),
//                       ],
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBubbleContent(BuildContext context) {
//     if (_showImageBubble()) return _buildImageBubble(context);
//     if (_isVoiceBubble()) return _buildVoiceBubble(context);
//     if (_isCallLogBubble()) return _buildCallLogBubble(context);
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
//       child: Text(
//         message.text,
//         style: TextStyle(
//           fontSize: 15,
//           height: 1.35,
//           color: message.isFromMe
//               ? AppColors.onBackgroundLight
//               : const Color(0xFF1E293B),
//           fontWeight: FontWeight.w400,
//         ),
//       ),
//     );
//   }
//
//   bool _showImageBubble() =>
//       message.contentKind == MessageContentKind.image &&
//       message.imageUrl != null &&
//       message.imageUrl!.isNotEmpty;
//
//   bool _isVoiceBubble() {
//     final u = message.voiceAudioUrl;
//     return message.contentKind == MessageContentKind.voice &&
//         u != null &&
//         u.isNotEmpty;
//   }
//
//   bool _isCallLogBubble() =>
//       message.contentKind == MessageContentKind.callLog &&
//       message.callLog != null;
//
//   static String _formatCallDuration(int sec) {
//     final m = sec ~/ 60;
//     final s = sec % 60;
//     return m > 0 ? '$m min, $s sec' : '$s sec';
//   }
//
//   Widget _buildCallLogBubble(BuildContext context) {
//     final log = message.callLog!;
//     final outgoing = message.isFromMe;
//     final media = log.isVideo ? 'Video' : 'Voice';
//     final missedIncoming =
//         !outgoing &&
//         (log.outcome == CallLogOutcome.missed ||
//             log.outcome == CallLogOutcome.cancelled);
//
//     final String title;
//     final String subtitle;
//
//     if (log.outcome == CallLogOutcome.completed) {
//       title = '$media call';
//       subtitle = _formatCallDuration(log.durationSec ?? 0);
//     } else if (missedIncoming) {
//       title = 'Missed $media call';
//       subtitle = 'Tap to call back';
//     } else if (log.outcome == CallLogOutcome.cancelled) {
//       title = '$media call';
//       subtitle = 'No answer';
//     } else {
//       title = '$media call';
//       subtitle = 'Declined';
//     }
//
//     final IconData icon;
//     final Color iconColor;
//
//     if (missedIncoming) {
//       icon = log.isVideo
//           ? Icons.missed_video_call_rounded
//           : Icons.call_missed_rounded;
//       iconColor = const Color(0xFFE53935);
//     } else if (log.outcome == CallLogOutcome.completed) {
//       icon = log.isVideo ? Icons.videocam_rounded : Icons.call_rounded;
//       iconColor = AppColors.primary;
//     } else {
//       icon = log.isVideo ? Icons.videocam_rounded : Icons.call_made_rounded;
//       iconColor = Colors.grey.shade600;
//     }
//
//     final row = Padding(
//       padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
//       child: Row(
//         children: [
//           Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               color: outgoing
//                   ? Colors.white.withValues(alpha: 0.7)
//                   : Colors.grey.shade100,
//               shape: BoxShape.circle,
//             ),
//             child: Icon(icon, color: iconColor, size: 22),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w700,
//                     color: Color(0xFF0F172A),
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   subtitle,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//
//     if (onCallLogTap == null) return row;
//
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(onTap: () => onCallLogTap!(log.isVideo), child: row),
//     );
//   }
//
//   Widget _buildVoiceBubble(BuildContext context) {
//     final w = (MediaQuery.of(context).size.width * 0.65)
//         .clamp(210.0, 320.0)
//         .toDouble();
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//       child: SizedBox(
//         width: w,
//         child: VoiceMessageBar(
//           source: message.voiceAudioUrl!,
//           durationMs: (message.voiceDurationMs ?? 1).clamp(1, 3600000),
//           isOutgoing: message.isFromMe,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildImagePreview() {
//     final u = message.imageUrl;
//
//     if (u == null || u.isEmpty) {
//       return Center(
//         child: Icon(Icons.image_rounded, size: 44, color: Colors.grey.shade400),
//       );
//     }
//
//     if (u.startsWith('http://') || u.startsWith('https://')) {
//       return Image.network(
//         u,
//         fit: BoxFit.cover,
//         loadingBuilder: (context, child, progress) {
//           if (progress == null) return child;
//
//           return Center(
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               color: AppColors.primary,
//             ),
//           );
//         },
//         errorBuilder: (_, _, _) => Center(
//           child: Icon(
//             Icons.broken_image_rounded,
//             size: 44,
//             color: Colors.grey.shade400,
//           ),
//         ),
//       );
//     }
//
//     final file = File(u);
//     if (file.existsSync()) {
//       return Image.file(file, fit: BoxFit.cover);
//     }
//
//     return Center(
//       child: Icon(
//         Icons.broken_image_rounded,
//         size: 44,
//         color: Colors.grey.shade400,
//       ),
//     );
//   }
//
//   void _openImageFullScreen(BuildContext context) {
//     final u = message.imageUrl;
//     if (u == null || u.isEmpty) return;
//
//     Navigator.of(context).push<void>(
//       MaterialPageRoute<void>(
//         fullscreenDialog: true,
//         builder: (_) => _FullScreenChatImage(imageUrl: u),
//       ),
//     );
//   }
//
//   Widget _buildImageBubble(BuildContext context) {
//     final hasCaption = message.text.trim().isNotEmpty;
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Material(
//           color: Colors.transparent,
//           child: InkWell(
//             onTap: () => _openImageFullScreen(context),
//             child: Ink(
//               height: 180,
//               width: double.infinity,
//               decoration: BoxDecoration(color: Colors.grey.shade200),
//               child: _buildImagePreview(),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Full-screen image viewer
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _BubbleAvatar extends StatelessWidget {
//   const _BubbleAvatar({required this.avatarUrl, required this.name});
//
//   final String? avatarUrl;
//   final String name;
//
//   @override
//   Widget build(BuildContext context) {
//     final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
//     final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
//
//     return CircleAvatar(
//       radius: 15,
//       backgroundColor: AppColors.primary.withValues(alpha: 0.12),
//       backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
//       child: !hasAvatar
//           ? Text(
//               initial,
//               style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.primary,
//               ),
//             )
//           : null,
//     );
//   }
// }
//
// //+0 241-889-6480
//
// class _FullScreenChatImage extends StatelessWidget {
//   const _FullScreenChatImage({required this.imageUrl});
//
//   final String imageUrl;
//
//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.sizeOf(context);
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           Center(
//             child: InteractiveViewer(
//               minScale: 0.5,
//               maxScale: 4,
//               child: SizedBox(
//                 width: size.width,
//                 height: size.height,
//                 child: _body(),
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Align(
//               alignment: Alignment.topRight,
//               child: IconButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 icon: const Icon(
//                   Icons.close_rounded,
//                   color: Colors.white,
//                   size: 28,
//                 ),
//                 style: IconButton.styleFrom(backgroundColor: Colors.white24),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _body() {
//     if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
//       return Image.network(
//         imageUrl,
//         fit: BoxFit.contain,
//         loadingBuilder: (context, child, progress) {
//           if (progress == null) return child;
//           return const Center(
//             child: SizedBox(
//               width: 36,
//               height: 36,
//               child: CircularProgressIndicator(
//                 color: Colors.white54,
//                 strokeWidth: 2,
//               ),
//             ),
//           );
//         },
//         errorBuilder: (_, __, ___) => const Center(
//           child: Icon(
//             Icons.broken_image_rounded,
//             color: Colors.white38,
//             size: 72,
//           ),
//         ),
//       );
//     }
//     final file = File(imageUrl);
//     if (file.existsSync()) return Image.file(file, fit: BoxFit.contain);
//     return const Center(
//       child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 72),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Typing dots
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _TypingDots extends StatefulWidget {
//   const _TypingDots();
//
//   @override
//   State<_TypingDots> createState() => _TypingDotsState();
// }
//
// class _TypingDotsState extends State<_TypingDots>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller = AnimationController(
//     vsync: this,
//     duration: const Duration(milliseconds: 1400),
//   )..repeat();
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final baseStyle = TextStyle(
//       fontSize: 30,
//       height: 3,
//       fontWeight: FontWeight.w600,
//       color: Colors.grey.shade600,
//     );
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (context, _) {
//         final phase = _controller.value * 3;
//         return Row(
//           mainAxisSize: MainAxisSize.min,
//           children: List.generate(3, (i) {
//             final active = (phase - i).abs() < 0.35;
//             return Opacity(
//               opacity: active ? 1.0 : 0.35,
//               child: Icon(Icons.fiber_manual_record, size: 13),
//             );
//           }),
//         );
//       },
//     );
//   }
// }
//
// class _HeaderActionButton extends StatelessWidget {
//   const _HeaderActionButton({
//     required this.icon,
//     required this.enabled,
//     required this.onTap,
//   });
//
//   final IconData icon;
//   final bool enabled;
//   final VoidCallback onTap;
//
//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: enabled
//           ? AppColors.primary.withValues(alpha: 0.10)
//           : Colors.grey.shade100,
//       shape: const CircleBorder(),
//       child: InkWell(
//         onTap: enabled ? onTap : null,
//         customBorder: const CircleBorder(),
//         child: SizedBox(
//           width: 40,
//           height: 40,
//           child: Icon(
//             icon,
//             size: 22,
//             color: enabled ? AppColors.primary : Colors.grey.shade400,
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/utils/titra_id_utils.dart';
import 'package:titra/features/call/presentation/view/audio_call_screen.dart';
import 'package:titra/features/call/presentation/view/group_audio_call_screen.dart';
import 'package:titra/features/call/presentation/view/group_video_call_screen.dart';
import 'package:titra/features/call/presentation/view/video_call_screen.dart';
import 'package:titra/features/chat/data/message_model.dart';
import 'package:titra/features/chat/data/messaging_repository.dart';
import 'package:titra/features/chat/presentation/view_models/chat_view_model.dart';
import 'package:titra/features/chat/presentation/widgets/mic_hold_record_button.dart';
import 'package:titra/features/chat/presentation/widgets/voice_message_bar.dart';
import 'package:titra/features/bottom_navigation/presentation/view/bottom_nav_screen.dart';
import 'package:titra/features/home/data/conversations_repository.dart';

import '../../../call/data/incoming_call_coordinator.dart';

typedef _InputFooterState = ({
  bool messagingEnabled,
  String? loadError,
  bool hasMessages,
  bool loading,
  bool peerTyping,
  bool canUseInput,
  bool canEditInput,
});

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    this.conversationId,
    this.avatarUrl,
    this.isGroup = false,
    this.participantNames,
    this.messagingEnabled = true,
    this.peerUserId,
    this.groupMemberUserIds,
    this.openedFromNotification = false,
  });

  final String contactName;
  final String contactId;
  final String? conversationId;
  final String? avatarUrl;
  final bool isGroup;
  final List<String>? participantNames;
  final bool messagingEnabled;
  final String? peerUserId;
  final List<String>? groupMemberUserIds;
  final bool openedFromNotification;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = _createViewModel();
    _viewModel.bootstrap();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_shouldRecreateViewModel(oldWidget)) return;
    final nextViewModel = _createViewModel();
    nextViewModel.bootstrap();
    final previousViewModel = _viewModel;
    _viewModel = nextViewModel;
    previousViewModel.dispose();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  ChatViewModel _createViewModel() {
    return ChatViewModel(
      sessionController: context.read<SessionController>(),
      conversationsRepository: context.read<ConversationsRepository>(),
      messagingRepository: context.read<MessagingRepository>(),
      snackbarService: context.read<SnackbarService>(),
      realtimeService: context.read<RealtimeService>(),
      contactName: widget.contactName,
      contactId: widget.contactId,
      conversationId: widget.conversationId,
      avatarUrl: widget.avatarUrl,
      isGroup: widget.isGroup,
      participantNames: widget.participantNames,
      messagingEnabled: widget.messagingEnabled,
      peerUserId: widget.peerUserId,
      groupMemberUserIds: widget.groupMemberUserIds,
    );
  }

  bool _shouldRecreateViewModel(ChatScreen oldWidget) {
    return oldWidget.contactId != widget.contactId ||
        oldWidget.conversationId != widget.conversationId ||
        oldWidget.isGroup != widget.isGroup ||
        oldWidget.messagingEnabled != widget.messagingEnabled ||
        oldWidget.peerUserId != widget.peerUserId ||
        oldWidget.avatarUrl != widget.avatarUrl ||
        oldWidget.contactName != widget.contactName;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatViewModel>.value(
      value: _viewModel,
      child: _ChatView(openedFromNotification: widget.openedFromNotification),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChatView extends StatefulWidget {
  const _ChatView({required this.openedFromNotification});

  final bool openedFromNotification;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  // ── Call helpers ─────────────────────────────────────────────────────────────

  Future<void> _handleBack(BuildContext context) async {
    final nav = Navigator.of(context, rootNavigator: true);
    if (await nav.maybePop()) return;
    if (!context.mounted) return;
    await nav.pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => const BottomWrapperScreen()),
    );
  }

  Future<void> _startOutgoingCall(
    BuildContext context,
    ChatViewModel vm, {
    required bool video,
  }) async {
    if (vm.isGroup) return;
    final snack = context.read<SnackbarService>();
    final ok = await vm.ensurePeerForCall();
    if (!context.mounted) return;
    if (!ok || vm.effectiveConversationId == null) {
      snack.showError('Could not start call. Open chat when online.');
      return;
    }
    final conv = vm.effectiveConversationId!;
    final peer = vm.effectivePeerUserId!;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: video ? '/video_call' : '/audio_call'),
        builder: (_) => video
            ? VideoCallScreen(
                contactName: vm.contactName,
                contactId: vm.contactId,
                conversationId: conv,
                peerUserId: peer,
                isOutgoing: true,
                avatarUrl: vm.avatarUrl,
              )
            : AudioCallScreen(
                contactName: vm.contactName,
                contactId: vm.contactId,
                conversationId: conv,
                peerUserId: peer,
                isOutgoing: true,
                avatarUrl: vm.avatarUrl,
              ),
      ),
    );
  }

  Future<void> _startGroupOutgoingCall(
    BuildContext context,
    ChatViewModel vm, {
    required bool video,
  }) async {
    final snack = context.read<SnackbarService>();
    final ok = await vm.ensureGroupMembersForCall();
    if (!context.mounted) return;
    if (!ok || vm.remoteUserIdsForGroupCall.isEmpty) {
      snack.showError('Could not load group members for call.');
      return;
    }
    if (vm.remoteUserIdsForGroupCall.length > 4) {
      snack.showError('Group calls support up to 4 other participants.');
      return;
    }
    final ids = vm.remoteUserIdsForGroupCall;
    final names = vm.participantNames;
    final peerNames = <String, String>{};
    for (var i = 0; i < ids.length; i++) {
      peerNames[ids[i]] = (names != null && i < names.length)
          ? names[i]
          : 'User';
    }
    final conv = vm.effectiveConversationId!;
    final coordinator = context.read<IncomingCallCoordinator>();

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: video ? '/video_call' : '/audio_call'),
        builder: (_) => video
            ? GroupVideoCallScreen(
                groupName: vm.contactName,
                conversationId: conv,
                remotePeerUserIds: ids,
                peerNamesById: peerNames,
                isOutgoing: true,
                incomingCallCoordinator: coordinator,
              )
            : GroupAudioCallScreen(
                groupName: vm.contactName,
                conversationId: conv,
                remotePeerUserIds: ids,
                peerNamesById: peerNames,
                isOutgoing: true,
                incomingCallCoordinator: coordinator,
              ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !widget.openedFromNotification,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !widget.openedFromNotification) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 200,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Consumer<ChatViewModel>(
                    builder: (context, vm, _) => _buildHeader(context, vm),
                  ),
                  Expanded(
                    child: Consumer<ChatViewModel>(
                      builder: (context, vm, _) =>
                          _buildMessageBody(context, vm),
                    ),
                  ),

                  Selector<ChatViewModel, _InputFooterState>(
                    selector: (_, vm) => (
                    messagingEnabled: vm.messagingEnabled,
                    loadError: vm.loadError,
                    hasMessages: vm.messages.isNotEmpty,
                    loading: vm.loading,
                    peerTyping: vm.peerTyping,
                    canUseInput: vm.inputEnabled,
                    canEditInput:
                    vm.messagingEnabled &&
                        vm.loadError == null &&
                        vm.effectiveConversationId != null,
                    ),
                    shouldRebuild: (prev, next) =>
                    prev.messagingEnabled != next.messagingEnabled ||
                        prev.loadError != next.loadError ||
                        prev.loading != next.loading ||       // only when loading truly changes
                        prev.peerTyping != next.peerTyping ||
                        prev.canUseInput != next.canUseInput ||
                        prev.canEditInput != next.canEditInput,
                    builder: (context, state, _) => _buildInputFooter(
                      context,
                      context.read<ChatViewModel>(),
                      state,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, ChatViewModel vm) {
    final topPadding = MediaQuery.of(context).padding.top;
    final hasAvatar = vm.avatarUrl != null && vm.avatarUrl!.isNotEmpty;
    final title = vm.contactName.trim().isNotEmpty ? vm.contactName : 'Chat';
    final subtitle = vm.isGroup && vm.participantNames != null
        ? '${vm.participantNames!.length} participants'
        : vm.peerOnline
        ? 'Online'
        : 'ID: ${formatTitraIdWithPrefix(vm.contactId)}';

    return Container(
      padding: EdgeInsets.fromLTRB(6, topPadding + 6, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC).withValues(alpha: 0.98),
        border: Border(bottom: BorderSide(color: AppColors.outlineLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _handleBack(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            iconSize: 20,
            color: AppColors.primary,
            splashRadius: 22,
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: hasAvatar ? NetworkImage(vm.avatarUrl!) : null,
                child: !hasAvatar
                    ? Text(
                        title[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              if (!vm.isGroup && vm.peerOnline)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onBackgroundLight,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: vm.peerOnline && !vm.isGroup
                            ? const Color(0xFF16A34A)
                            : Colors.grey.shade600,
                        fontWeight: vm.peerOnline && !vm.isGroup
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontFamily: vm.isGroup || vm.peerOnline
                            ? null
                            : 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _HeaderActionButton(
            icon: Icons.videocam_rounded,
            enabled: vm.isGroup ? vm.canPlaceGroupWebrtcCall : true,
            onTap: () {
              if (vm.isGroup) {
                _startGroupOutgoingCall(context, vm, video: true);
              } else {
                _startOutgoingCall(context, vm, video: true);
              }
            },
          ),
          const SizedBox(width: 6),
          _HeaderActionButton(
            icon: Icons.call_rounded,
            enabled: vm.isGroup ? vm.canPlaceGroupWebrtcCall : true,
            onTap: () {
              if (vm.isGroup) {
                _startGroupOutgoingCall(context, vm, video: false);
              } else {
                _startOutgoingCall(context, vm, video: false);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Message body ─────────────────────────────────────────────────────────────

  Widget _buildMessageBody(BuildContext context, ChatViewModel vm) {
    if (vm.messagingEnabled && vm.loading && vm.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (vm.messagingEnabled && vm.loadError != null && vm.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                vm.loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => vm.bootstrap(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      reverse: true,
      controller: vm.messageScrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        ...vm.messages.reversed.map(
          (m) => _MessageBubble(
            message: m,
            avatarUrl: m.isFromMe ? null : (m.senderAvatarUrl ?? vm.avatarUrl),
            contactName: m.isFromMe
                ? vm.contactName
                : (m.senderName ?? vm.contactName),
            showSenderLabel: vm.isGroup && !m.isFromMe && m.senderName != null,
            onCallLogTap: vm.isGroup
                ? null
                : (video) => _startOutgoingCall(context, vm, video: video),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Today',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: _buildEncryptedBanner()),
      ],
    );
  }

  Widget _buildEncryptedBanner() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white54),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              'Messages are End-to-End Encrypted',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input footer ─────────────────────────────────────────────────────────────

  Widget _buildInputFooter(
    BuildContext context,
    ChatViewModel vm,
    _InputFooterState state,
  ) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (!state.messagingEnabled) {
      return _FooterShell(
        bottomPad: bottomPad,
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Messaging is not connected yet. You can start a chat in a future update.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state.loadError != null && state.hasMessages) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomPad),
        color: Colors.orange.shade50,
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: Colors.orange.shade800,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.loadError!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ),
            TextButton(
              onPressed: () => vm.bootstrap(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.loading && !state.hasMessages) {
      return _FooterShell(
        bottomPad: bottomPad,
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Connecting…',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.peerTyping)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(children: const [SizedBox(width: 6), _TypingDots()]),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ComposerActionScope(
                  child: _CircleIconButton(
                    icon: Icons.add_rounded,
                    onPressed: state.canUseInput
                        ? () => _showAttachBottomSheet(context, vm)
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('chat_input_field'),
                            controller: vm.inputController,
                            focusNode: vm.messageFocusNode,
                            enabled: state.canEditInput,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            minLines: 1,
                            maxLines: 5,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                            decoration: InputDecoration(
                              hintText: 'Aa',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                            ),
                            onChanged: (_) => vm.onComposerTextChanged(),
                            // REMOVE onSubmitted completely
                          ),
                        ),
                        _ComposerActionScope(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2, right: 2),
                            child: _CircleIconButton(
                              icon: Icons.emoji_emotions_outlined,
                              size: 20,
                              diameter: 32,
                              color: Colors.grey.shade400,
                              onPressed: state.canUseInput
                                  ? () => _showEmojiPicker(context, vm)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    vm.inputController,
                    vm.sendingNotifier,
                  ]),
                  builder: (context, _) {
                    final sending = vm.sendingNotifier.value;
                    final hasText = vm.inputController.text.trim().isNotEmpty;
                    if (hasText) {
                      return _ComposerActionScope(
                        child: _SendButton(
                          sending: sending,
                          enabled: state.canUseInput,
                          onTap: () => vm.sendMessage(),
                        ),
                      );
                    }
                    return _ComposerActionScope(
                      child: MicHoldRecordButton(
                        enabled: state.canUseInput,
                        busy: sending,
                        onShortTap: vm.showVoiceRecordHint,
                        onVoiceCommitted: vm.sendVoiceFromFile,
                        onPermissionDenied: () {
                          context.read<SnackbarService>().showError(
                            'Microphone permission is required to record voice.',
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// ── Bottom sheets ─────────────────────────────────────────────────────────────

void _showAttachBottomSheet(BuildContext context, ChatViewModel vm) {
  Future<void> pickAndSend(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (x == null) return;
    await vm.sendImageFromPath(x.path);
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(ctx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Attachment',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(ctx, Icons.camera_alt_rounded, 'Camera', () {
                  Navigator.pop(ctx);
                  Future<void>.microtask(() => pickAndSend(ImageSource.camera));
                }),
                _attachOption(ctx, Icons.photo_library_rounded, 'Gallery', () {
                  Navigator.pop(ctx);
                  Future<void>.microtask(
                    () => pickAndSend(ImageSource.gallery),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _attachOption(
  BuildContext context,
  IconData icon,
  String label,
  VoidCallback onTap,
) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    ),
  );
}

void _showEmojiPicker(BuildContext context, ChatViewModel vm) {
  const emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😅',
    '😂',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😗',
    '👍',
    '👎',
    '👏',
    '🙌',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '💕',
    '💯',
    '🎉',
    '🔥',
    '✨',
    '⭐',
    '🙏',
  ];
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: 280,
      decoration: BoxDecoration(
        color: Theme.of(ctx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 8),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Emoji',
              style: Theme.of(
                ctx,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemCount: emojis.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () {
                    vm.insertEmoji(emojis[i]);
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: Text(
                      emojis[i],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer shell
// ─────────────────────────────────────────────────────────────────────────────

class _FooterShell extends StatelessWidget {
  const _FooterShell({required this.child, required this.bottomPad});

  final Widget child;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: AppColors.outlineLight)),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circle icon button
// ─────────────────────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    this.onPressed,
    this.size = 24,
    this.diameter = 38,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double diameter;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        color: Colors.black12,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(
            icon,
            size: size,
            color: onPressed == null
                ? Colors.grey.shade300
                : (color ?? Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Send button
// ─────────────────────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.sending,
    required this.enabled,
    required this.onTap,
  });

  final bool sending;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: Material(
        color: enabled
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        elevation: enabled ? 2 : 0,
        shadowColor: AppColors.primary.withValues(alpha: 0.4),
        child: InkWell(
          onTap: (enabled && !sending) ? onTap : null,
          customBorder: const CircleBorder(),
          focusColor: Colors.transparent,
          child: SizedBox(
            width: 40,
            height: 40,
            child: sending
                ? const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Outgoing status icon
// ─────────────────────────────────────────────────────────────────────────────

class _OutgoingStatusIcon extends StatelessWidget {
  const _OutgoingStatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final grey = Colors.grey.shade500;
    switch (status) {
      case MessageStatus.pending:
        return Icon(Icons.schedule_rounded, size: 14, color: grey);
      case MessageStatus.sent:
        return Icon(Icons.done_rounded, size: 14, color: grey);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 14, color: grey);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 14, color: AppColors.primary);
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Color(0xFFDC2626),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.avatarUrl,
    required this.contactName,
    this.showSenderLabel = false,
    this.onCallLogTap,
  });

  final MessageModel message;
  final String? avatarUrl;
  final String contactName;
  final bool showSenderLabel;
  final Future<void> Function(bool video)? onCallLogTap;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 56 : 12,
        right: isMe ? 12 : 56,
        bottom: 10,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _BubbleAvatar(avatarUrl: avatarUrl, name: contactName),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe && showSenderLabel && message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      message.senderName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary.withValues(alpha: 0.13)
                        : AppColors.outlineLight.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 10 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 10),
                    ),
                    border: Border.all(
                      color: isMe
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.outlineLight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.035),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _buildBubbleContent(context),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(
                    left: isMe ? 0 : 4,
                    right: isMe ? 4 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.timestamp,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _OutgoingStatusIcon(status: message.status),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    if (_showImageBubble()) return _buildImageBubble(context);
    if (_isVoiceBubble()) return _buildVoiceBubble(context);
    if (_isCallLogBubble()) return _buildCallLogBubble(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: 15,
          height: 1.35,
          color: message.isFromMe
              ? AppColors.onBackgroundLight
              : const Color(0xFF1E293B),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  bool _showImageBubble() =>
      message.contentKind == MessageContentKind.image &&
      message.imageUrl != null &&
      message.imageUrl!.isNotEmpty;

  bool _isVoiceBubble() {
    final u = message.voiceAudioUrl;
    return message.contentKind == MessageContentKind.voice &&
        u != null &&
        u.isNotEmpty;
  }

  bool _isCallLogBubble() =>
      message.contentKind == MessageContentKind.callLog &&
      message.callLog != null;

  static String _formatCallDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return m > 0 ? '$m min, $s sec' : '$s sec';
  }

  Widget _buildCallLogBubble(BuildContext context) {
    final log = message.callLog!;
    final outgoing = message.isFromMe;
    final media = log.isVideo ? 'Video' : 'Voice';
    final missedIncoming =
        !outgoing &&
        (log.outcome == CallLogOutcome.missed ||
            log.outcome == CallLogOutcome.cancelled);

    final String title;
    final String subtitle;

    if (log.outcome == CallLogOutcome.completed) {
      title = '$media call';
      subtitle = _formatCallDuration(log.durationSec ?? 0);
    } else if (missedIncoming) {
      title = 'Missed $media call';
      subtitle = 'Tap to call back';
    } else if (log.outcome == CallLogOutcome.cancelled) {
      title = '$media call';
      subtitle = 'No answer';
    } else {
      title = '$media call';
      subtitle = 'Declined';
    }

    final IconData icon;
    final Color iconColor;

    if (missedIncoming) {
      icon = log.isVideo
          ? Icons.missed_video_call_rounded
          : Icons.call_missed_rounded;
      iconColor = const Color(0xFFE53935);
    } else if (log.outcome == CallLogOutcome.completed) {
      icon = log.isVideo ? Icons.videocam_rounded : Icons.call_rounded;
      iconColor = AppColors.primary;
    } else {
      icon = log.isVideo ? Icons.videocam_rounded : Icons.call_made_rounded;
      iconColor = Colors.grey.shade600;
    }

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: outgoing
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onCallLogTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: () => onCallLogTap!(log.isVideo), child: row),
    );
  }

  Widget _buildVoiceBubble(BuildContext context) {
    final w = (MediaQuery.of(context).size.width * 0.65)
        .clamp(210.0, 320.0)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: SizedBox(
        width: w,
        child: VoiceMessageBar(
          source: message.voiceAudioUrl!,
          durationMs: (message.voiceDurationMs ?? 1).clamp(1, 3600000),
          isOutgoing: message.isFromMe,
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final u = message.imageUrl;
    if (u == null || u.isEmpty) {
      return Center(
        child: Icon(Icons.image_rounded, size: 44, color: Colors.grey.shade400),
      );
    }
    if (u.startsWith('http://') || u.startsWith('https://')) {
      return Image.network(
        u,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          );
        },
        errorBuilder: (_, _, _) => Center(
          child: Icon(
            Icons.broken_image_rounded,
            size: 44,
            color: Colors.grey.shade400,
          ),
        ),
      );
    }
    final file = File(u);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    return Center(
      child: Icon(
        Icons.broken_image_rounded,
        size: 44,
        color: Colors.grey.shade400,
      ),
    );
  }

  void _openImageFullScreen(BuildContext context) {
    final u = message.imageUrl;
    if (u == null || u.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenChatImage(imageUrl: u),
      ),
    );
  }

  Widget _buildImageBubble(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openImageFullScreen(context),
            child: Ink(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade200),
              child: _buildImagePreview(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen image viewer
// ─────────────────────────────────────────────────────────────────────────────

class _BubbleAvatar extends StatelessWidget {
  const _BubbleAvatar({required this.avatarUrl, required this.name});

  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 15,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
      child: !hasAvatar
          ? Text(
              initial,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}

class _FullScreenChatImage extends StatelessWidget {
  const _FullScreenChatImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: _body(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.white38,
            size: 72,
          ),
        ),
      );
    }
    final file = File(imageUrl);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.contain);
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 72),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing dots
// ─────────────────────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.value * 3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final active = (phase - i).abs() < 0.35;
            return Opacity(
              opacity: active ? 1.0 : 0.35,
              child: const Icon(Icons.fiber_manual_record, size: 13),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header action button
// ─────────────────────────────────────────────────────────────────────────────

class _ComposerActionScope extends StatelessWidget {
  const _ComposerActionScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(child: child);
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? AppColors.primary.withValues(alpha: 0.10)
          : Colors.grey.shade100,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? AppColors.primary : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
