import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/push/background_fcm_handler.dart';
import 'core/services/native_call_overlay_manager.dart';
import 'firebase_options.dart';

// ─── Native Overlay Entry Point ──────────────────────────────────────────────

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      color: Colors.transparent,
      debugShowCheckedModeBanner: false,
      home: _CallOverlay(),
    ),
  );
}

class _CallOverlay extends StatefulWidget {
  const _CallOverlay();

  @override
  State<_CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<_CallOverlay> {
  StreamSubscription<dynamic>? _overlaySub;
  String _duration = '00:00';
  String _callSessionId = '';
  String _avatarUrl = '';
  String _callerName = 'Titra';
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _overlaySub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted) return;
      if (data is Map) {
        final action = data['action']?.toString();
        if (action == 'update_call_overlay') {
          setState(() {
            _duration = data['duration']?.toString().trim() ?? '00:00';
            _callSessionId = data['callSessionId']?.toString().trim() ?? '';
            _avatarUrl = data['avatarUrl']?.toString().trim() ?? '';
            _callerName = data['callerName']?.toString().trim() ?? 'Titra';
            _isMuted = data['isMuted']?.toString() == '1';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _overlaySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return  Container(
          width: 240,
          height: 350,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white12, width: 2),
          ),
          child: Column(
            children: [
              // 1. Avatar / Preview Area (Tappable to return)
              Expanded(
                child: GestureDetector(
                  onTap: _returnToCall,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(27),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: _avatarUrl.isNotEmpty
                              ? Image.network(_avatarUrl, fit: BoxFit.cover)
                              : const Icon(Icons.person_rounded,
                                  color: Colors.white24, size: 80),
                        ),
                      ),
                      // Gradient Overlay for Timer readability
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black87,
                                Colors.black,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Caller Name & Timer
                      Positioned(
                        bottom: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _callerName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _duration,
                              style: const TextStyle(
                                color: Color(0xFF22C68A),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.none,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 2. Control Buttons
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF222222),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: _isMuted ? Colors.redAccent : Colors.white70,
                      onTap: _toggleMute,
                    ),
                    _ControlButton(
                      icon: Icons.call_end_rounded,
                      color: Colors.red,
                      onTap: _endCall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Future<void> _returnToCall() async {
    debugPrint('[CallOverlay] Action: launch_app, sessionId: $_callSessionId');
    // String payloads are the only reliable format between isolates
    await FlutterOverlayWindow.shareData('LAUNCH_APP');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _toggleMute() async {
    debugPrint('[CallOverlay] Action: toggle_mute, sessionId: $_callSessionId');
    // String payloads work reliably; Map payloads often lost between isolates
    await FlutterOverlayWindow.shareData('toggle_mute');
  }

  Future<void> _endCall() async {
    debugPrint('[CallOverlay] Action: end_call, sessionId: $_callSessionId');
    await FlutterOverlayWindow.shareData('end_call');
    // Wait for main app to process before closing
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await FlutterOverlayWindow.closeOverlay();
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

// ─── App Main Entry Point ────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    } catch (e, st) {
      debugPrint('[Push] Firebase not initialized: $e\n$st',);
    }
  }

  // Request SYSTEM_ALERT_WINDOW on Android at startup
  if (!kIsWeb && Platform.isAndroid) {
    await NativeCallOverlayManager.instance.checkAndRequestPermission();
  }

  final prefs = await SharedPreferences.getInstance();

  final navigatorKey = GlobalKey<NavigatorState>();

  runApp(
    TitraApp(
      navigatorKey: navigatorKey,
      prefs: prefs,
    ),
  );
}
