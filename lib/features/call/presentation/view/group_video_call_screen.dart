import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/call/data/call_participant.dart';
import 'package:titra/features/call/data/calls_repository.dart';
import 'package:titra/features/call/presentation/view_models/group_video_call_view_model.dart';

import '../../data/incoming_call_coordinator.dart';
import '../widgets/call_status_header.dart';

class GroupVideoCallScreen extends StatelessWidget {
  const GroupVideoCallScreen({
    super.key,
    required this.groupName,
    required this.conversationId,
    required this.remotePeerUserIds,
    required this.peerNamesById,
    required this.isOutgoing,
    this.callSessionId,
    this.incomingCallCoordinator,
  });

  final String groupName;
  final String conversationId;
  final List<String> remotePeerUserIds;
  final Map<String, String> peerNamesById;
  final bool isOutgoing;
  final String? callSessionId;
  final IncomingCallCoordinator? incomingCallCoordinator;

  @override
  Widget build(BuildContext context) {
    final coordinator = context.read<IncomingCallCoordinator>();
    final existingVm = coordinator.activeViewModel;

    if (existingVm is GroupVideoCallViewModel &&
        existingVm.callSessionId == callSessionId) {
      return ChangeNotifierProvider.value(
        value: existingVm,
        child: const _GroupVideoCallView(),
      );
    }

    return ChangeNotifierProvider(
      create: (ctx) => GroupVideoCallViewModel(
        callsRepository: ctx.read<CallsRepository>(),
        realtimeService: ctx.read<RealtimeService>(),
        sessionController: ctx.read<SessionController>(),
        groupName: groupName,
        conversationId: conversationId,
        remotePeerUserIds: remotePeerUserIds,
        peerNamesById: peerNamesById,
        isOutgoing: isOutgoing,
        callSessionId: callSessionId,
        incomingCallCoordinator: incomingCallCoordinator,
      ),
      child: const _GroupVideoCallView(),
    );
  }
}

class _GroupVideoCallView extends StatefulWidget {
  const _GroupVideoCallView();

  @override
  State<_GroupVideoCallView> createState() => _GroupVideoCallViewState();
}

class _GroupVideoCallViewState extends State<_GroupVideoCallView> {
  GroupVideoCallViewModel? _vm;
  IncomingCallCoordinator? _coordinator;
  Timer? _controlsHideTimer;
  Timer? _labelsHideTimer;
  bool _controlsVisible = true;
  bool _labelsVisible = true;
  bool _seededParticipantIds = false;
  Set<String> _knownParticipantIds = <String>{};

  @override
  void initState() {
    super.initState();
    _showLabelsTemporarily();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator ??= context.read<IncomingCallCoordinator>();
    _coordinator?.setCallScreenVisible(true);
    final vm = context.read<GroupVideoCallViewModel>();
    if (!identical(_vm, vm)) {
      _vm?.removeListener(_handleVmChanged);
      _vm = vm;
      _vm!.addListener(_handleVmChanged);
      _handleVmChanged();
    }
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _labelsHideTimer?.cancel();
    _vm?.removeListener(_handleVmChanged);
    _coordinator?.setCallScreenVisible(false);
    unawaited(_coordinator?.showActiveCallOverlay());
    _coordinator = null;
    _vm = null;
    super.dispose();
  }

  void _handleVmChanged() {
    final vm = _vm;
    if (!mounted || vm == null) return;

    // Auto-pop if call ended or a fatal error occurred
    if (vm.ended || vm.error != null) {
      _vm?.removeListener(_handleVmChanged);
      _vm = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    final participantIds = vm.participants.map((p) => p.id).toSet();
    if (!_seededParticipantIds) {
      _knownParticipantIds = participantIds;
      _seededParticipantIds = true;
    } else {
      final newIds = participantIds.difference(_knownParticipantIds);
      _knownParticipantIds = participantIds;
      if (newIds.isNotEmpty) {
        _showLabelsTemporarily();
      }
    }

    if (!vm.connected && !_controlsVisible) {
      if (mounted) {
        setState(() => _controlsVisible = true);
      }
      return;
    }
    if (vm.connected && _controlsVisible) {
      _scheduleControlsHide();
    }
  }

  void _scheduleControlsHide() {
    _controlsHideTimer?.cancel();
    final vm = _vm;
    if (vm == null || !vm.connected) return;
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _showControlsTemporarily() {
    if (!mounted) return;
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleControlsHide();
  }

  void _showLabelsTemporarily() {
    _labelsHideTimer?.cancel();
    if (mounted) {
      setState(() => _labelsVisible = true);
    }
    _labelsHideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _labelsVisible = false);
    });
  }

  void _handleStageTap() {
    _showControlsTemporarily();
    _showLabelsTemporarily();
  }

  void _showParticipantSheet(BuildContext context, GroupVideoCallViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101715),
      isScrollControlled: true,
      builder: (context) {
        final participants = vm.orderedParticipants;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Participants',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${vm.participantCount}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ParticipantListRow(
                  title: 'You',
                  subtitle: vm.isVideoOn ? 'Video on' : 'Video off',
                  isMuted: vm.isMuted,
                  isVideoEnabled: vm.isVideoOn,
                  isSpeaking: false,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: participants.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white10, height: 16),
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      return _ParticipantListRow(
                        title: participant.name,
                        subtitle:
                            vm.hasRemoteVideoFor(participant.id) &&
                                participant.isVideoEnabled
                            ? 'Video on'
                            : 'Audio only',
                        isMuted: participant.isMuted,
                        isVideoEnabled: participant.isVideoEnabled,
                        isSpeaking:
                            participant.isSpeaking ||
                            vm.activeSpeakerUserId == participant.id,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupVideoCallViewModel>();
    if (vm.error != null && !vm.connecting) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vm.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleStageTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ParticipantStage(
                vm: vm,
                showLabels: _labelsVisible,
                onExpandParticipant: (participant) {
                  final renderer = vm.remoteRenderers[participant.id];
                  _openExpandedFeed(
                    context,
                    title: participant.name,
                    renderer: renderer,
                  );
                },
                onFocusParticipant: vm.focusParticipant,
              ),
              if (vm.remoteVideoReadyCount == 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _EmptyRemoteState(vm: vm),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: _buildCallStatusHeader(context, vm),
              ),
              Positioned(
                right: 16,
                bottom:
                    MediaQuery.of(context).padding.bottom +
                    (_controlsVisible ? 118 : 22),
                child: _LocalPipTile(
                  mirror: true,
                  label: 'You',
                  renderer: vm.localRenderer,
                  videoEnabled: vm.isVideoOn,
                  muted: vm.isMuted,
                  onTap: () {
                    _openExpandedFeed(
                      context,
                      title: 'You',
                      renderer: vm.localRenderer,
                      mirror: true,
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 14,
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 180),
                    offset: _controlsVisible
                        ? Offset.zero
                        : const Offset(0, 0.24),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _controlsVisible ? 1 : 0,
                      child: _BottomControls(
                        vm: vm,
                        onEnd: () async {
                          await vm.endCall();
                          if (context.mounted) Navigator.of(context).pop();
                        },
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

  void _openExpandedFeed(
    BuildContext context, {
    required String title,
    RTCVideoRenderer? renderer,
    bool mirror = false,
  }) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) {
        return _ExpandedVideoFeed(
          title: title,
          renderer: renderer,
          mirror: mirror,
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  Widget _buildCallStatusHeader(BuildContext context, GroupVideoCallViewModel vm) {
    final status = vm.error ??
        (vm.connected
            ? 'Group video call'
            : vm.statusLabel.isNotEmpty
                ? vm.statusLabel
                : 'Connecting...');

    return CallStatusHeader(
      title: vm.groupName,
      statusText: status,
      durationText: vm.connected ? vm.durationFormatted : '',
      isConnected: vm.connected,
      isError: vm.error != null,
      darkStyle: true,
      onBack: () {
        _coordinator?.setCallScreenVisible(false);
        unawaited(_coordinator?.showActiveCallOverlay());
        Navigator.of(context).pop();
      },
      actions: [
        Material(
          color: Colors.black.withValues(alpha: 0.34),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => _showParticipantSheet(context, vm),
            customBorder: const CircleBorder(),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.group_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _ParticipantStage extends StatelessWidget {
  const _ParticipantStage({
    required this.vm,
    required this.showLabels,
    required this.onExpandParticipant,
    required this.onFocusParticipant,
  });

  final GroupVideoCallViewModel vm;
  final bool showLabels;
  final ValueChanged<CallParticipant> onExpandParticipant;
  final ValueChanged<String> onFocusParticipant;

  @override
  Widget build(BuildContext context) {
    final participants = vm.orderedParticipants;
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeTop = MediaQuery.of(context).padding.top;
    const horizontalInset = 12.0;
    const topInset = 74.0;
    const bottomInset = 132.0;
    const gap = 12.0;
    final orientation = MediaQuery.of(context).orientation;

    Widget tileFor(
      CallParticipant participant, {
      bool compact = false,
      bool forceLabel = false,
      VoidCallback? onTap,
    }) {
      final renderer = vm.remoteRenderers[participant.id];
      return _ParticipantVideoTile(
        participant: participant,
        renderer: renderer,
        showVideo:
            participant.isVideoEnabled && vm.hasRemoteVideoFor(participant.id),
        isActiveSpeaker:
            participant.isSpeaking || vm.activeSpeakerUserId == participant.id,
        showLabel: showLabels || forceLabel,
        compact: compact,
        onTap: onTap ?? () => onExpandParticipant(participant),
      );
    }

    if (participants.length == 1) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          safeTop + topInset,
          horizontalInset,
          bottomInset,
        ),
        child: tileFor(participants.first, forceLabel: true),
      );
    }

    if (participants.length == 2) {
      final axis = orientation == Orientation.landscape
          ? Axis.horizontal
          : Axis.vertical;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          safeTop + topInset,
          horizontalInset,
          bottomInset,
        ),
        child: Flex(
          direction: axis,
          children: [
            Expanded(child: tileFor(participants[0], forceLabel: true)),
            SizedBox(
              width: axis == Axis.horizontal ? gap : 0,
              height: axis == Axis.vertical ? gap : 0,
            ),
            Expanded(child: tileFor(participants[1], forceLabel: true)),
          ],
        ),
      );
    }

    if (participants.length <= 4) {
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(
          horizontalInset,
          safeTop + topInset,
          horizontalInset,
          bottomInset,
        ),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: orientation == Orientation.landscape ? 1.16 : 0.82,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          return tileFor(participants[index], forceLabel: true);
        },
      );
    }

    final featured = participants.first;
    final overflow = participants.skip(1).toList(growable: false);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalInset,
        safeTop + topInset,
        horizontalInset,
        bottomInset,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: overflow.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final participant = overflow[index];
                return SizedBox(
                  width: 128,
                  child: tileFor(
                    participant,
                    compact: true,
                    onTap: () => onFocusParticipant(participant.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: gap),
          Expanded(child: tileFor(featured, forceLabel: true)),
        ],
      ),
    );
  }

  }

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.vm, required this.onEnd});

  final GroupVideoCallViewModel vm;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ControlButton(
              icon: vm.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              active: !vm.isMuted,
              onTap: vm.toggleMute,
            ),
            const SizedBox(width: 12),
            _ControlButton(
              icon: vm.isVideoOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              active: vm.isVideoOn,
              onTap: vm.toggleVideo,
            ),
            const SizedBox(width: 12),
            _ControlButton(
              icon: vm.isSpeakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              active: vm.isSpeakerOn,
              onTap: vm.toggleSpeaker,
            ),
            const SizedBox(width: 12),
            _ControlButton(
              icon: Icons.cameraswitch_rounded,
              active: true,
              onTap: vm.switchCamera,
            ),
            const SizedBox(width: 14),
            Material(
              color: const Color(0xFFEF4444),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onEnd,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            color: active ? Colors.white : Colors.white70,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _LocalPipTile extends StatelessWidget {
  const _LocalPipTile({
    required this.label,
    required this.renderer,
    required this.videoEnabled,
    required this.muted,
    required this.onTap,
    this.mirror = false,
  });

  final String label;
  final RTCVideoRenderer renderer;
  final bool videoEnabled;
  final bool muted;
  final VoidCallback onTap;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final hasVideo = renderer.srcObject != null && videoEnabled;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 112,
        height: 156,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideo)
                RTCVideoView(
                  renderer,
                  mirror: mirror,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                const _MissingVideoFill(label: 'You'),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (muted || !videoEnabled) ...[
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (muted)
                            const _StatusBubble(icon: Icons.mic_off_rounded),
                          if (!videoEnabled)
                            const _StatusBubble(
                              icon: Icons.videocam_off_rounded,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantVideoTile extends StatelessWidget {
  const _ParticipantVideoTile({
    required this.participant,
    this.renderer,
    required this.showVideo,
    required this.isActiveSpeaker,
    required this.showLabel,
    required this.compact,
    required this.onTap,
  });

  final CallParticipant participant;
  final RTCVideoRenderer? renderer;
  final bool showVideo;
  final bool isActiveSpeaker;
  final bool showLabel;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(compact ? 16 : 22),
          border: Border.all(
            color: isActiveSpeaker
                ? AppColors.secondaryLight
                : Colors.white.withValues(alpha: 0.12),
            width: isActiveSpeaker ? 2.6 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isActiveSpeaker
                  ? AppColors.secondary.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: isActiveSpeaker ? 22 : 16,
              spreadRadius: isActiveSpeaker ? 2 : 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 15 : 21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showVideo && renderer != null)
                RTCVideoView(
                  renderer!,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                _MissingVideoFill(label: participant.name),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (participant.isMuted)
                      const _StatusBubble(icon: Icons.mic_off_rounded),
                    if (!participant.isVideoEnabled) ...[
                      if (participant.isMuted) const SizedBox(width: 6),
                      const _StatusBubble(icon: Icons.videocam_off_rounded),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: showLabel ? 1 : 0,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.54),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        participant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 11 : 13,
                          fontWeight: FontWeight.w600,
                        ),
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
}

class _ParticipantListRow extends StatelessWidget {
  const _ParticipantListRow({
    required this.title,
    required this.subtitle,
    required this.isMuted,
    required this.isVideoEnabled,
    required this.isSpeaking,
  });

  final String title;
  final String subtitle;
  final bool isMuted;
  final bool isVideoEnabled;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.gradient,
          ),
          alignment: Alignment.center,
          child: Text(
            _initialsFromName(title),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (isSpeaking)
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
        Icon(
          isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: isMuted ? Colors.white54 : Colors.white70,
          size: 18,
        ),
        const SizedBox(width: 10),
        Icon(
          isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          color: isVideoEnabled ? Colors.white70 : Colors.white54,
          size: 18,
        ),
      ],
    );
  }
}

class _StatusBubble extends StatelessWidget {
  const _StatusBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 15),
    );
  }
}

class _EmptyRemoteState extends StatelessWidget {
  const _EmptyRemoteState({required this.vm});

  final GroupVideoCallViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_rounded, size: 30, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            vm.statusLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vm.participants.isEmpty
                ? 'Waiting for someone to join this call.'
                : 'Connected people will appear here as soon as their video is ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingVideoFill extends StatelessWidget {
  const _MissingVideoFill({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.9),
            AppColors.surfaceDark,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: Text(
                _initialsFromName(label ?? 'User'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label ?? 'Video off',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Camera off',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedVideoFeed extends StatelessWidget {
  const _ExpandedVideoFeed({
    required this.title,
    this.renderer,
    this.mirror = false,
  });

  final String title;
  final RTCVideoRenderer? renderer;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    final hasVideo = renderer?.srcObject != null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 56, 12, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: hasVideo && renderer != null
                      ? RTCVideoView(
                          renderer!,
                          mirror: mirror,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : _MissingVideoFill(label: title),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initialsFromName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.map((part) => part[0].toUpperCase()).join();
}
