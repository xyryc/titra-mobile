import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/call/data/calls_repository.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';

import '../view_models/video_call_view_model.dart';
import '../widgets/call_status_header.dart';

class VideoCallScreen extends StatelessWidget {
  const VideoCallScreen({
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
  final bool showTitraId;
  final String? callSessionId;
  final Map<String, dynamic>? remoteOffer;
  final List<Map<String, dynamic>>? preBufferedIceCandidates;
  final IncomingCallCoordinator? incomingCallCoordinator;

  @override
  Widget build(BuildContext context) {
    final coordinator = context.read<IncomingCallCoordinator>();
    final existingVm = coordinator.activeViewModel;

    if (existingVm is VideoCallViewModel &&
        existingVm.activeCallSessionId != null &&
        existingVm.activeCallSessionId == callSessionId) {
      return ChangeNotifierProvider.value(
        value: existingVm,
        child: const _VideoCallView(),
      );
    }

    return ChangeNotifierProvider(
      create: (ctx) => VideoCallViewModel(
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
      child: const _VideoCallView(),
    );
  }
}

class _VideoCallView extends StatefulWidget {
  const _VideoCallView();

  @override
  State<_VideoCallView> createState() => _VideoCallViewState();
}

class _VideoCallViewState extends State<_VideoCallView> {
  VideoCallViewModel? _vm;
  IncomingCallCoordinator? _coordinator;
  bool _showLocalAsMain = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<VideoCallViewModel>();
      _coordinator = context.read<IncomingCallCoordinator>();
      _coordinator?.setCallScreenVisible(true);
      _vm = vm;
      vm.addListener(_onVm);
    });
  }

  void _onVm() {
    final vm = _vm;
    if (!mounted || vm == null) return;

    // Auto-pop if call ended or a fatal error occurred
    if (!vm.remoteEnded && !vm.localEnded && vm.error == null) return;

    // Unsubscribe first
    vm.removeListener(_onVm);
    _vm = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _vm?.removeListener(_onVm);
    _coordinator?.setCallScreenVisible(false);
    unawaited(_coordinator?.showActiveCallOverlay());
    _coordinator = null;
    _vm = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VideoCallViewModel>();
    final mainIsLocal = _showLocalAsMain;

    return PopScope(
        canPop: true,
        child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _StageLayer(vm: vm, showLocalAsMain: mainIsLocal),
            const _VideoOverlayBackdrop(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  _buildCallStatusHeader(context, vm),
                  const SizedBox(height: 10),
                  if (vm.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.errorLight.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          vm.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade100,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 84,
              right: 16,
              child: _buildPip(vm, showLocalAsMain: mainIsLocal),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: _buildControlBar(context, vm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallStatusHeader(BuildContext context, VideoCallViewModel vm) {
    final status = vm.error ??
        (vm.connected
            ? 'On video call'
            : vm.callerSetupPhase
                ? 'Starting secure call...'
                : vm.callerRingingPhase
                ? 'Ringing...'
                : 'Connecting...');

    return CallStatusHeader(
      title: vm.contactName,
      statusText: status,
      durationText: vm.connected ? vm.durationFormatted : '',
      isConnected: vm.connected,
      isError: vm.error != null,
      darkStyle: true,
      onBack: () {
        _coordinator?.setCallScreenVisible(false);
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildPip(VideoCallViewModel vm, {required bool showLocalAsMain}) {
    final renderer = showLocalAsMain ? vm.remoteRenderer : vm.localRenderer;
    final hasVideo = showLocalAsMain
        ? vm.remoteRenderer.srcObject != null
        : vm.renderersReady &&
              vm.localRenderer.srcObject != null &&
              vm.isVideoOn;
    final label = showLocalAsMain ? vm.contactName : 'You';
    final mirror = !showLocalAsMain;
    return GestureDetector(
      onTap: _swapFeeds,
      child: Container(
        width: 108,
        height: 152,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: hasVideo
              ? RTCVideoView(
                  renderer,
                  mirror: mirror,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : _MiniVideoPlaceholder(label: label),
        ),
      ),
    );
  }

  void _swapFeeds() {
    setState(() {
      _showLocalAsMain = !_showLocalAsMain;
    });
  }

  Widget _buildControlBar(BuildContext context, VideoCallViewModel vm) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _VideoControlButton(
              icon: vm.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              active: !vm.isMuted,
              label: 'Mute',
              onTap: vm.toggleMute,
            ),
            _VideoControlButton(
              icon: vm.isVideoOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              active: vm.isVideoOn,
              label: 'Video',
              onTap: vm.toggleVideo,
            ),
            _VideoControlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              onTap: vm.switchCamera,
            ),
            _EndCallButton(onTap: () => vm.endCall()),
          ],
        ),
      ),
    );
  }

}

/// Remote video + placeholder (uses [VideoCallViewModel.remoteRenderer]).
class _StageLayer extends StatelessWidget {
  const _StageLayer({required this.vm, required this.showLocalAsMain});

  final VideoCallViewModel vm;
  final bool showLocalAsMain;

  @override
  Widget build(BuildContext context) {
    final renderer = showLocalAsMain ? vm.localRenderer : vm.remoteRenderer;
    final hasVideo = showLocalAsMain
        ? vm.renderersReady &&
              vm.localRenderer.srcObject != null &&
              vm.isVideoOn
        : vm.remoteRenderer.srcObject != null &&
          vm.remoteRenderer.srcObject!.getVideoTracks().isNotEmpty;

    if (!vm.renderersReady || !hasVideo) {
      return _RemoteVideoPlaceholder(
        avatarUrl: showLocalAsMain ? null : vm.avatarUrl,
        contactName: showLocalAsMain ? 'You' : vm.contactName,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundLight,
            AppColors.secondaryLight.withValues(alpha: 0.38),
            AppColors.primaryLight.withValues(alpha: 0.28),
          ],
        ),
      ),
      child: RTCVideoView(
        renderer,
        key: ValueKey(
          showLocalAsMain
              ? 'local-main-${vm.isVideoOn}-${renderer.srcObject?.id ?? 'pending'}'
              : 'remote-main-${vm.remoteVideoStreamKey ?? 'pending'}',
        ),
        mirror: showLocalAsMain,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}

class _RemoteVideoPlaceholder extends StatelessWidget {
  const _RemoteVideoPlaceholder({this.avatarUrl, required this.contactName});

  final String? avatarUrl;
  final String contactName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundLight,
            AppColors.secondaryLight.withValues(alpha: 0.4),
            AppColors.primary.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? Image.network(avatarUrl!, fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
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
                          _initialsFromName(contactName),
                          style: const TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              contactName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.onBackgroundLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoOverlayBackdrop extends StatelessWidget {
  const _VideoOverlayBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark.withValues(alpha: 0.16),
              Colors.transparent,
              AppColors.secondaryDark.withValues(alpha: 0.18),
            ],
            stops: const [0.0, 0.36, 1.0],
          ),
        ),
      ),
    );
  }
}

class _MiniVideoPlaceholder extends StatelessWidget {
  const _MiniVideoPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight.withValues(alpha: 0.72),
            AppColors.secondary.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _initialsFromName(label),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
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

class _VideoControlButton extends StatelessWidget {
  const _VideoControlButton({
    required this.icon,
    this.active = true,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: active
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.36),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(icon, size: 26, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: const Color(0xFFEF4444),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.call_end_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'End',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
