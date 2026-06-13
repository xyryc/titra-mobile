import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/call/data/call_participant.dart';
import 'package:titra/features/call/data/calls_repository.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';
import 'package:titra/features/call/presentation/view_models/group_audio_call_view_model.dart';
import 'package:titra/features/call/presentation/widgets/call_status_header.dart';

class GroupAudioCallScreen extends StatelessWidget {
  const GroupAudioCallScreen({
    super.key,
    required this.groupName,
    required this.conversationId,
    required this.remotePeerUserIds,
    required this.peerNamesById,
    required this.isOutgoing,
    this.callSessionId,
    required this.incomingCallCoordinator,
  });

  final String groupName;
  final String conversationId;
  final List<String> remotePeerUserIds;
  final Map<String, String> peerNamesById;
  final bool isOutgoing;
  final String? callSessionId;
  final IncomingCallCoordinator incomingCallCoordinator;

  @override
  Widget build(BuildContext context) {
    final coordinator = context.read<IncomingCallCoordinator>();
    final existingVm = coordinator.activeViewModel;

    if (existingVm is GroupAudioCallViewModel &&
        existingVm.activeCallSessionId != null &&
        existingVm.activeCallSessionId == callSessionId) {
      return ChangeNotifierProvider.value(
        value: existingVm,
        child: const _GroupAudioCallView(),
      );
    }

    return ChangeNotifierProvider(
      create: (ctx) => GroupAudioCallViewModel(
        callsRepository: ctx.read<CallsRepository>(),
        realtimeService: ctx.read<RealtimeService>(),
        sessionController: ctx.read<SessionController>(),
        groupName: groupName,
        conversationId: conversationId,
        remotePeerUserIds: remotePeerUserIds,
        peerNamesById: peerNamesById,
        isOutgoing: isOutgoing,
        callSessionId: callSessionId,
        incomingCallCoordinator: coordinator,
      ),
      child: const _GroupAudioCallView(),
    );
  }
}

class _GroupAudioCallView extends StatefulWidget {
  const _GroupAudioCallView();

  @override
  State<_GroupAudioCallView> createState() => _GroupAudioCallViewState();
}

class _GroupAudioCallViewState extends State<_GroupAudioCallView> {
  GroupAudioCallViewModel? _vm;
  IncomingCallCoordinator? _coordinator;
  Timer? _controlsHideTimer;
  bool _controlsVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator = context.read<IncomingCallCoordinator>();
    _coordinator?.setCallScreenVisible(true);
    final vm = context.read<GroupAudioCallViewModel>();
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

    if (vm.ended || vm.error != null) {
      _vm?.removeListener(_handleVmChanged);
      _vm = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    if (!vm.connected && !_controlsVisible) {
      setState(() => _controlsVisible = true);
      return;
    }
    if (vm.connected) {
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
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleControlsHide();
  }

  void _showParticipantSheet(BuildContext context, GroupAudioCallViewModel vm) {
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
                    Text(
                      '${vm.participantCount}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _AudioParticipantRow(
                  name: 'You',
                  subtitle: 'In call',
                  muted: vm.isMuted,
                  speaking: false,
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
                      return _AudioParticipantRow(
                        name: participant.name,
                        subtitle: participant.isMuted ? 'Muted' : 'Listening',
                        muted: participant.isMuted,
                        speaking:
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
    final vm = context.watch<GroupAudioCallViewModel>();
    if (vm.error != null && !vm.connecting) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(vm.error!, textAlign: TextAlign.center),
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
        backgroundColor: AppColors.white,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showControlsTemporarily,
          child: Stack(
            children: [
              ...vm.remoteAudioRenderers.entries.map(
                (entry) => Positioned(
                  left: 0,
                  top: 0,
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0.01,
                    child: entry.value.srcObject != null
                        ? RTCVideoView(entry.value)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              SafeArea(
                child: _buildCallStatusHeader(context, vm),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  MediaQuery.of(context).padding.top + 82,
                  18,
                  132,
                ),
                child: _AudioParticipantGrid(vm: vm),
              ),
              Positioned(
                right: 16,
                bottom:
                    MediaQuery.of(context).padding.bottom +
                    (_controlsVisible ? 108 : 20),
                child: _YouAudioCard(
                  muted: vm.isMuted,
                  speakerOn: vm.isSpeakerOn,
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
                      child: _AudioControls(
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

  Widget _buildCallStatusHeader(BuildContext context, GroupAudioCallViewModel vm) {
    final status = vm.error ??
        (vm.connected
            ? 'Group call'
            : vm.connecting
                ? 'Starting call...'
                : 'Waiting');

    return CallStatusHeader(
      title: vm.groupName,
      statusText: status,
      durationText: vm.connected ? vm.durationFormatted : '',
      isConnected: vm.connected,
      isError: vm.error != null,
      darkStyle: true,
      onBack: () {
        _coordinator?.setCallScreenVisible(false);
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

// ─── Audio Participant Grid ─────────────────────────────────────────────────────

class _AudioParticipantGrid extends StatelessWidget {
  const _AudioParticipantGrid({required this.vm});

  final GroupAudioCallViewModel vm;

  @override
  Widget build(BuildContext context) {
    final participants = vm.orderedParticipants;
    if (participants.isEmpty) {
      return Center(
        child: Text(
          'Waiting for participants',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.66),
            fontSize: 15,
          ),
        ),
      );
    }

    if (participants.length == 1) {
      final participant = participants.first;
      final active =
          participant.isSpeaking || vm.activeSpeakerUserId == participant.id;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 420),
          child: _AudioParticipantCard(
            participant: participant,
            activeSpeaker: active,
            featured: true,
          ),
        ),
      );
    }

    return GridView.builder(
      itemCount: participants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: participants.length <= 2 ? 0.92 : 0.88,
      ),
      itemBuilder: (context, index) {
        final participant = participants[index];
        final active =
            participant.isSpeaking || vm.activeSpeakerUserId == participant.id;
        return _AudioParticipantCard(
          participant: participant,
          activeSpeaker: active,
        );
      },
    );
  }
}

class _AudioParticipantCard extends StatelessWidget {
  const _AudioParticipantCard({
    required this.participant,
    required this.activeSpeaker,
    this.featured = false,
  });

  final CallParticipant participant;
  final bool activeSpeaker;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: activeSpeaker
              ? AppColors.secondaryLight
              : Colors.white.withValues(alpha: 0.1),
          width: activeSpeaker ? 2.4 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: activeSpeaker
                ? AppColors.secondary.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.16),
            blurRadius: activeSpeaker ? 22 : 16,
            spreadRadius: activeSpeaker ? 2 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(featured ? 24 : 16),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: featured ? 108 : 82,
              height: featured ? 108 : 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _initialsFromName(participant.name),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: featured ? 38 : 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: featured ? 18 : 14),
            Text(
              participant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: featured ? 20 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              activeSpeaker
                  ? 'Speaking'
                  : (participant.isMuted ? 'Muted' : 'Listening'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: featured ? 13 : 12,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StateBadge(
                  icon: participant.isMuted
                      ? Icons.mic_off_rounded
                      : Icons.mic_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── You Audio Card (PIP) ───────────────────────────────────────────────────────

class _YouAudioCard extends StatelessWidget {
  const _YouAudioCard({required this.muted, required this.speakerOn});

  final bool muted;
  final bool speakerOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Y',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              if (muted) const _StateBadge(icon: Icons.mic_off_rounded),
              if (speakerOn) const _StateBadge(icon: Icons.volume_up_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Audio Controls ──────────────────────────────────────────────────────────────

class _AudioControls extends StatelessWidget {
  const _AudioControls({required this.vm, required this.onEnd});

  final GroupAudioCallViewModel vm;
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
              icon: vm.isSpeakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              active: vm.isSpeakerOn,
              onTap: vm.toggleSpeaker,
            ),
            const SizedBox(width: 14),
            Material(
              color: const Color(0xFFEF4444),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onEnd,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 58,
                  height: 58,
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

// ─── Participant Row (Sheet) ────────────────────────────────────────────────────

class _AudioParticipantRow extends StatelessWidget {
  const _AudioParticipantRow({
    required this.name,
    required this.subtitle,
    required this.muted,
    required this.speaking,
  });

  final String name;
  final String subtitle;
  final bool muted;
  final bool speaking;

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
            _initialsFromName(name),
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
                name,
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
        if (speaking)
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
          muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: muted ? Colors.white54 : Colors.white70,
          size: 18,
        ),
      ],
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.icon});

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
