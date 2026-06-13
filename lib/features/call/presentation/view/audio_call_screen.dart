import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/utils/titra_id_utils.dart';
import 'package:titra/features/call/data/calls_repository.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';

import '../view_models/audio_call_view_model.dart';
import '../widgets/call_status_header.dart';

// ─── Light-mode color constants ───────────────────────────────────────────────
// Replace these with your AppColors values or keep inline.
class _LightCallColors {
  static const background       = Color(0xFFFFFFFF); // pure white
  static const backgroundSoft   = Color(0xFFF4F6F8); // surface / card
  static const backgroundMuted  = Color(0xFFEEF1F5); // muted chip bg
  static const border           = Color(0xFFE2E6EB); // chip / card border
  static const borderStrong     = Color(0xFFCDD3DC); // avatar ring
  static const textPrimary      = Color(0xFF0F1923); // main text
  static const textSecondary    = Color(0xFF5C6878); // sub text / labels
  static const textMuted        = Color(0xFF8B97A6); // timer, hints
  static const primary          = Color(0xFF3B7BF6); // brand blue
  static const primaryLight     = Color(0xFFDDE9FF); // avatar glow
  static const secondary        = Color(0xFF22C68A); // connected green
  static const secondaryLight   = Color(0xFFD1F5E8);
  static const errorColor       = Color(0xFFEF4444); // end-call / error
  static const errorLight       = Color(0xFFFFE4E4);
  static const iconBg           = Color(0xFFF0F2F5); // idle control bg
  static const iconActiveBg     = Color(0xFF3B7BF6); // active control bg
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AudioCallScreen extends StatelessWidget {
  const AudioCallScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    required this.conversationId,
    required this.peerUserId,
    required this.isOutgoing,
    this.avatarUrl,
    this.showTitraId = true,
    this.callSessionId,
    this.remoteOffer,
    this.preBufferedIceCandidates,
    this.incomingCallCoordinator,
  });

  final String contactName;
  final String contactId;
  final String conversationId;
  final String peerUserId;
  final bool isOutgoing;
  final String? avatarUrl;

  /// When false (typical incoming call), hide the Titra ID chip under the name.
  final bool showTitraId;

  /// Callee only.
  final String? callSessionId;
  final Map<String, dynamic>? remoteOffer;

  /// ICE from peer while incoming UI was showing (see [IncomingCallCoordinator]).
  final List<Map<String, dynamic>>? preBufferedIceCandidates;
  final IncomingCallCoordinator? incomingCallCoordinator;

  @override
  Widget build(BuildContext context) {
    final coordinator = context.read<IncomingCallCoordinator>();
    final existingVm = coordinator.activeViewModel;

    if (existingVm is AudioCallViewModel &&
        existingVm.activeCallSessionId != null &&
        existingVm.activeCallSessionId == callSessionId) {
      return ChangeNotifierProvider.value(
        key: const ValueKey('audio-call-provider-value'),
        value: existingVm,
        child: const _AudioCallView(),
      );
    }

    return ChangeNotifierProvider(
      create: (ctx) => AudioCallViewModel(
        callsRepository: ctx.read<CallsRepository>(),
        realtimeService: ctx.read<RealtimeService>(),
        sessionController: ctx.read<SessionController>(),
        contactName: contactName,
        contactId: contactId,
        conversationId: conversationId,
        peerUserId: peerUserId,
        isOutgoing: isOutgoing,
        avatarUrl: avatarUrl,
        showTitraId: showTitraId,
        callSessionId: callSessionId,
        remoteOffer: remoteOffer,
        preBufferedIceCandidates: preBufferedIceCandidates,
        incomingCallCoordinator: incomingCallCoordinator,
      ),
      child: const _AudioCallView(),
    );
  }
}

// ─── Stateful view ────────────────────────────────────────────────────────────

class _AudioCallView extends StatefulWidget {
  const _AudioCallView();

  @override
  State<_AudioCallView> createState() => _AudioCallViewState();
}

class _AudioCallViewState extends State<_AudioCallView> {
  AudioCallViewModel? _vm;
  IncomingCallCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<AudioCallViewModel>();
      _coordinator = context.read<IncomingCallCoordinator>();
      _coordinator?.setCallScreenVisible(true);
      _vm = vm;
      vm.addListener(_onVm);

      _onVm();
    });
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVm);
    _coordinator?.setCallScreenVisible(false);
    _coordinator = null;
    _vm = null;
    super.dispose();
  }
  void _onVm() {
    final vm = _vm;
    if (!mounted || vm == null) return;

    if (!vm.remoteEnded && !vm.localEnded && vm.error == null) return;

    vm.removeListener(_onVm);
    _vm = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AudioCallViewModel>();
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: _LightCallColors.background,
        body: Stack(
          children: [
            // Hidden audio renderer (1×1 px, barely visible)
            if (vm.remoteAudioRendererReady)
              Positioned(
                left: 0,
                top: 0,
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0.01,
                  child: RTCVideoView(vm.remoteAudioRenderer),
                ),
              ),

            SafeArea(
              child: Column(
                children: [
                  _buildCallStatusHeader(context, vm),
                  const Spacer(),
                  _buildAvatar(vm),
                  const SizedBox(height: 24),
                  _buildIdentity(vm),
                  const SizedBox(height: 14),
                  _buildStatusInfo(vm),
                  const Spacer(),
                  _buildControls(vm),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Call status header (Messenger style) ────────────────────────────────────

  Widget _buildCallStatusHeader(BuildContext context, AudioCallViewModel vm) {
    final status = vm.error ??
        (vm.connected
            ? 'On call'
            : vm.callerSetupPhase
                ? 'Starting secure call...'
                : vm.callerRingingPhase
                ? 'Ringing...'
                : vm.connecting
                ? 'Connecting...'
                : 'Waiting');

    return CallStatusHeader(
      title: vm.contactName,
      statusText: status,
      durationText: vm.connected ? vm.durationFormatted : '',
      isConnected: vm.connected,
      isError: vm.error != null,
      darkStyle: false,
      onBack: () {
        _coordinator?.setCallScreenVisible(false);
        unawaited(_coordinator?.showActiveCallOverlay());
        Navigator.of(context).pop();
      },
      onMoreTap: null,
    );
  }

  // ── Avatar ──────────────────────────────────────────────────────────────────

  Widget _buildAvatar(AudioCallViewModel vm) {
    final hasAvatar = vm.avatarUrl != null && vm.avatarUrl!.isNotEmpty;
    return Container(
      width: 184,
      height: 184,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _LightCallColors.borderStrong, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _LightCallColors.primary.withValues(alpha: 0.14),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(vm.avatarUrl!, fit: BoxFit.cover)
            : Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF5B9BFF), // lighter blue
                Color(0xFF3B7BF6), // primary blue
                Color(0xFF22C68A), // secondary green
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _initialsFromName(vm.contactName),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 58,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ── Name + Titra ID ─────────────────────────────────────────────────────────

  Widget _buildIdentity(AudioCallViewModel vm) {
    return Column(
      children: [
        Text(
          vm.contactName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _LightCallColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (vm.showTitraId)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _LightCallColors.backgroundMuted,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _LightCallColors.border),
            ),
            child: Text(
              formatTitraIdWithPrefix(vm.contactId),
              style: const TextStyle(
                color: _LightCallColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
      ],
    );
  }

  // ── Status pill + duration ──────────────────────────────────────────────────

  Widget _buildStatusInfo(AudioCallViewModel vm) {
    final status =
        vm.error ??
            (vm.connected
                ? 'On call'
                : vm.callerSetupPhase
                ? 'Starting secure call...'
                : vm.callerRingingPhase
                ? 'Ringing...'
                : vm.connecting
                ? 'Connecting...'
                : 'Waiting');

    final Color dotColor;
    final Color pillBg;
    final Color pillBorder;
    if (vm.error != null) {
      dotColor   = _LightCallColors.errorColor;
      pillBg     = _LightCallColors.errorLight;
      pillBorder = _LightCallColors.errorColor.withValues(alpha: 0.25);
    } else if (vm.connected) {
      dotColor   = _LightCallColors.secondary;
      pillBg     = _LightCallColors.secondaryLight;
      pillBorder = _LightCallColors.secondary.withValues(alpha: 0.25);
    } else {
      dotColor   = _LightCallColors.primary;
      pillBg     = _LightCallColors.primaryLight;
      pillBorder = _LightCallColors.primary.withValues(alpha: 0.25);
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: pillBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  color: vm.error != null
                      ? _LightCallColors.errorColor
                      : vm.connected
                      ? _LightCallColors.secondary
                      : _LightCallColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (vm.connected)
          Text(
            vm.durationFormatted,
            style: const TextStyle(
              color: _LightCallColors.textMuted,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
      ],
    );
  }

  // ── Control buttons ─────────────────────────────────────────────────────────

  Widget _buildControls(AudioCallViewModel vm) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: _LightCallColors.backgroundSoft,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _LightCallColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LightControlButton(
              icon: vm.isSpeakerOn
                  ? Icons.volume_up_rounded
                  : Icons.hearing_rounded,
              label: 'Speaker',
              onTap: vm.toggleSpeaker,
              isActive: vm.isSpeakerOn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LightControlButton(
              icon: vm.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: 'Mute',
              onTap: vm.toggleMute,
              isActive: vm.isMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _EndCallButton(onTap: () => vm.endCall())),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

/// A circular control button with an optional active state (filled blue).
class _LightControlButton extends StatelessWidget {
  const _LightControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isActive
              ? _LightCallColors.iconActiveBg
              : _LightCallColors.iconBg,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                icon,
                color: isActive ? Colors.white : _LightCallColors.textPrimary,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: _LightCallColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Red end-call button.
class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: _LightCallColors.errorColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 58,
              height: 58,
              child: Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'End',
          style: TextStyle(
            color: _LightCallColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

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
