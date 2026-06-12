import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.payload});

  final Map<String, String> payload;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  IncomingCallCoordinator? _coordinator;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coordinator = context.read<IncomingCallCoordinator>();
      _coordinator = coordinator;
      coordinator.addListener(_handleCoordinatorChanged);
      if (coordinator.ringing == null) {
        coordinator.presentFromPushData(widget.payload);
      }
    });
  }

  @override
  void dispose() {
    _coordinator?.removeListener(_handleCoordinatorChanged);
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    final coordinator = _coordinator;
    if (!mounted || coordinator == null) return;
    if (_actionInProgress) return;
    if (coordinator.ringing != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _accept() async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
    });
    final coordinator = context.read<IncomingCallCoordinator>();
    final navigator = Navigator.of(context);
    _coordinator?.removeListener(_handleCoordinatorChanged);
    if (navigator.canPop()) {
      navigator.pop();
    }
    unawaited(
      Future<void>.microtask(() async {
        await coordinator.accept();
      }),
    );
  }

  Future<void> _decline() async {
    if (_actionInProgress) return;
    setState(() {
      _actionInProgress = true;
    });
    final coordinator = context.read<IncomingCallCoordinator>();
    final navigator = Navigator.of(context);
    _coordinator?.removeListener(_handleCoordinatorChanged);
    if (navigator.canPop()) {
      navigator.pop();
    }
    unawaited(
      Future<void>.microtask(() async {
        await coordinator.decline();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<IncomingCallCoordinator>();
    final ringing = coordinator.ringing;
    final isVideo =
        ringing?.isVideo ??
        (widget.payload['callType'] ?? '').toUpperCase() == 'VIDEO';
    final callerName =
        ringing?.callerName ??
        widget.payload['initiatorName']?.trim().takeIf((v) => v.isNotEmpty) ??
        'Someone';
    final subtitle = isVideo ? 'Incoming video call' : 'Incoming audio call';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Encrypted call',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD8E1EE), width: 6),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x143B82F6),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _initial(callerName),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                callerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Open in Titra call screen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blueGrey.shade400,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 58,
                      child: OutlinedButton.icon(
                        onPressed: _actionInProgress ? null : _decline,
                        icon: const Icon(Icons.call_end_rounded),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318),
                          side: const BorderSide(color: Color(0xFFFDA29B)),
                          backgroundColor: const Color(0xFFFFF3F2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 58,
                      child: FilledButton.icon(
                        onPressed: _actionInProgress ? null : _accept,
                        icon: Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        ),
                        label: const Text('Accept'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
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

  String _initial(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

extension on String? {
  String? takeIf(bool Function(String value) predicate) {
    final value = this;
    if (value == null) return null;
    return predicate(value) ? value : null;
  }
}
