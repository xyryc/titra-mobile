import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/core/local_db/app_database.dart';
import 'package:titra/core/push/push_notification_controller.dart';
import 'package:titra/core/push/push_token_repository.dart';
import 'package:titra/core/services/native_call_overlay_manager.dart';
import 'package:titra/core/services/navigation_service.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/sync/chat_sync_coordinator.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/theme/app_theme.dart';
import 'package:titra/features/auth/data/auth_repository.dart';
import 'package:titra/features/auth/data/user_repository.dart';
import 'package:titra/features/call/data/calls_repository.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';
import 'package:titra/features/call/presentation/widgets/call_status_overlay.dart';
import 'package:titra/features/chat/data/files_repository.dart';
import 'package:titra/features/chat/data/messaging_repository.dart';
import 'package:titra/features/auth/presentation/view/create_identity_screen.dart';
import 'package:titra/features/auth/presentation/view/login_screen.dart';
import 'package:titra/features/auth/presentation/view/profile_setup_screen.dart';
import 'package:titra/features/home/data/conversations_repository.dart';
import 'package:titra/features/home/data/home_repository.dart';
import 'package:titra/features/bottom_navigation/presentation/view/bottom_nav_screen.dart';
import 'package:titra/features/call/presentation/view_models/calls_view_model.dart';
import 'package:titra/features/home/presentation/view_models/home_view_model.dart';
import 'package:titra/features/profile/presentation/view_models/profile_view_model.dart';
import 'package:titra/features/onboarding/presentation/view/onboarding_screen.dart';
import 'package:titra/features/status/data/status_repository.dart';

import 'core/constants/app_size.dart';

class TitraApp extends StatelessWidget {
  const TitraApp({super.key, required this.navigatorKey, required this.prefs});

  final GlobalKey<NavigatorState> navigatorKey;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NavigationService>(
          create: (_) => NavigationService(),
        ),
        Provider<SnackbarService>(
          create: (_) => SnackbarService(navigatorKey: navigatorKey),
        ),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(prefs: prefs),
        ),
        ChangeNotifierProxyProvider<SessionController, RealtimeService>(
          create: (_) => RealtimeService(),
          update: (_, session, previous) {
            final svc = previous ?? RealtimeService();
            svc.syncSessionToken(session.sessionToken, session.hydrated);
            return svc;
          },
        ),
        Provider<ApiClient>(
          create: (ctx) => ApiClient(
            snackbarService: ctx.read<SnackbarService>(),
            sessionController: ctx.read<SessionController>(),
          ),
        ),
        Provider<AppDatabase>(create: (_) => AppDatabase()),
        Provider<PushTokenRepository>(
          create: (ctx) => PushTokenRepository(ctx.read<ApiClient>()),
        ),
        Provider<PushNotificationController>(
          create: (ctx) => PushNotificationController(
            navigatorKey: navigatorKey,
            sessionController: ctx.read<SessionController>(),
            realtimeService: ctx.read<RealtimeService>(),
            pushTokenRepository: ctx.read<PushTokenRepository>(),
          ),
        ),
        Provider<AuthRepository>(
          create: (ctx) => AuthRepository(
            ctx.read<ApiClient>(),
            ctx.read<SessionController>(),
          ),
        ),
        ChangeNotifierProvider<ProfileViewModel>(
          create: (ctx) =>
              ProfileViewModel(authRepository: ctx.read<AuthRepository>()),
        ),
        Provider<UserRepository>(
          create: (ctx) => UserRepository(ctx.read<ApiClient>()),
        ),
        Provider<FilesRepository>(
          create: (ctx) => FilesRepository(ctx.read<ApiClient>()),
        ),
        Provider<MessagingRepository>(
          create: (ctx) => MessagingRepository(
            ctx.read<ApiClient>(),
            ctx.read<AppDatabase>(),
            ctx.read<FilesRepository>(),
          ),
        ),
        Provider<HomeRepository>(
          create: (ctx) => HomeRepository(ctx.read<ApiClient>()),
        ),
        Provider<ConversationsRepository>(
          create: (ctx) => ConversationsRepository(
            ctx.read<ApiClient>(),
            ctx.read<AppDatabase>(),
          ),
        ),
        Provider<CallsRepository>(
          create: (ctx) =>
              CallsRepository(ctx.read<ApiClient>(), ctx.read<AppDatabase>()),
        ),
        Provider<ChatSyncCoordinator>(
          lazy: false,
          create: (ctx) => ChatSyncCoordinator(
            db: ctx.read<AppDatabase>(),
            realtime: ctx.read<RealtimeService>(),
            messagingRepository: ctx.read<MessagingRepository>(),
            sessionController: ctx.read<SessionController>(),
          ),
        ),
        ChangeNotifierProvider<CallsViewModel>(
          create: (ctx) =>
              CallsViewModel(callsRepository: ctx.read<CallsRepository>()),
        ),
        ChangeNotifierProvider<IncomingCallCoordinator>(
          create: (ctx) => IncomingCallCoordinator(
            navigatorKey: navigatorKey,
            callsRepository: ctx.read<CallsRepository>(),
            conversationsRepository: ctx.read<ConversationsRepository>(),
          ),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          create: (ctx) => HomeViewModel(
            conversationsRepository: ctx.read<ConversationsRepository>(),
            sessionController: ctx.read<SessionController>(),
            realtimeService: ctx.read<RealtimeService>(),
          ),
        ),
        ChangeNotifierProvider<StatusRepository>(
          create: (ctx) => StatusRepository(ctx.read<ApiClient>()),
        ),
      ],
      child: _AppCoordinator(navigatorKey: navigatorKey),
    );
  }
}

class _AppCoordinator extends StatefulWidget {
  const _AppCoordinator({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<_AppCoordinator> createState() => _AppCoordinatorState();
}

class _AppCoordinatorState extends State<_AppCoordinator>
    with WidgetsBindingObserver {
  bool _pushBootstrapStarted = false;
  bool _pushBootstrapCompleted = false;


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final session = context.read<SessionController>();

    await session.hydrate();

    if (!mounted) return;

    context.read<IncomingCallCoordinator>().attach(
      context.read<RealtimeService>(),
      session,
    );
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final coord = context.read<IncomingCallCoordinator>();
      final active = coord.activeCall;
      // Show overlay only if there is an active call and the call screen is NOT currently visible
      if (active != null && !coord.isCallScreenVisible) {
        unawaited(coord.showActiveCallOverlay());
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(NativeCallOverlayManager.instance.dismiss());
      context.read<IncomingCallCoordinator>().onAppResumed();

      if (mounted) {
        final session = context.read<SessionController>();
        context.read<RealtimeService>().reconnectIfNeeded(session.sessionToken);
        if (session.sessionToken != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              context.read<PushNotificationController>().consumePendingOpen(),
            );
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionController>(
      builder: (context, session, _) {
        if (session.hydrated &&
            session.sessionToken != null &&
            !_pushBootstrapStarted) {
          _pushBootstrapStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              if (!context.mounted) return;
              final push = context.read<PushNotificationController>();
              await push.initialize();
              if (!context.mounted) return;
              unawaited(push.onSessionBecameAuthenticated());
              await push.consumePendingOpen();
            } finally {
              if (mounted) {
                setState(() {
                  _pushBootstrapCompleted = true;
                });
              }
            }
          });
        }
        if (session.hydrated && session.sessionToken == null) {
          _pushBootstrapStarted = false;
          _pushBootstrapCompleted = false;
        }

        if (!session.hydrated) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          );
        }

        return Builder(
          builder: (context) {
            final navService = context.read<NavigationService>();
            return MaterialApp(
              navigatorKey: widget.navigatorKey,
              navigatorObservers: [AppRouteObserver(navService)],
              title: 'Titra',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ThemeMode.light,
              builder: (context, child) {
                AppSize.init(context);
                return CallStatusOverlay(child: child ?? const SizedBox.shrink());
              },
              home: _resolveRoot(session),
            );
          },
        );
      },
    );
  }

  Widget _resolveRoot(SessionController session) {
    if (session.sessionToken != null && !_pushBootstrapCompleted) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return _resolveHome(session);
  }

  Widget _resolveHome(SessionController session) {
    if (session.sessionToken != null && session.needsProfileSetup) {
      return const ProfileSetupScreen();
    }
    if (session.sessionToken != null) {
      return const BottomWrapperScreen();
    }
    if (!session.onboardingCompleted) {
      return OnboardingScreen(
        onComplete: () {
          context.read<SessionController>().completeOnboarding();
        },
      );
    }
    if (session.authPage == AuthPage.login) {
      return LoginScreen(
        onCreateIdentityPressed: () => session.showCreateIdentity(),
      );
    }
    return CreateIdentityScreen(onLoginPressed: () => session.showLogin());
  }
}
