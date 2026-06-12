import 'dart:io';
import 'dart:ui';

import 'package:cupertino_native/components/tab_bar.dart';
import 'package:cupertino_native/style/sf_symbol.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/constants/app_size.dart';

import '../../../../core/session/session_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/view/add_person_screen.dart';
import '../../../home/presentation/view/calls_tab_content.dart';
import '../../../home/presentation/view/chats_tab_content.dart';
import '../../../home/presentation/view/create_group_screen.dart';
import '../../../home/presentation/view_models/home_view_model.dart';
import '../../../profile/presentation/view/profile_content.dart';
import '../../../status/presentation/view/status_tab_content.dart';

class BottomWrapperScreen extends StatefulWidget {
  const BottomWrapperScreen({super.key});

  @override
  State<BottomWrapperScreen> createState() => _BottomWrapperScreenState();
}

class _BottomWrapperScreenState extends State<BottomWrapperScreen> {
  final List<ScrollController> _controllers = List.generate(
    4,
    (_) => ScrollController(),
  );
  int selectedIndex = 0;
  bool _navVisible = true;

  final List<String> titles = const ['Chats', 'Status', 'Calls', 'Profile'];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_onScroll);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeViewModel>().loadConversations();
    });
  }

  void _onScroll() {
    final c = _controllers[selectedIndex];
    if (!c.hasClients) return;
    final goingDown = c.position.userScrollDirection == ScrollDirection.reverse;
    final goingUp = c.position.userScrollDirection == ScrollDirection.forward;
    if (goingDown && _navVisible) {
      setState(() => _navVisible = false);
    } else if (goingUp && !_navVisible) {
      setState(() => _navVisible = true);
    }
  }

  void _handleTabChange(int index) {
    if (selectedIndex == index && _navVisible) {
      return;
    }
    setState(() {
      selectedIndex = index;
      _navVisible = true;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_onScroll);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildIOSLayout();
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.backgroundLight,
      body: Stack(  // ← removed SafeArea wrapper here
        children: [
          Column(
            children: [
              SafeArea(child: _buildHeader(context)), // ← SafeArea only on header
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: [
                    ChatsTabContent(scrollController: _controllers[0]),
                    StatusTabContent(scrollController: _controllers[1]),
                    CallsTabContent(scrollController: _controllers[2]),
                    ProfileContent(scrollController: _controllers[3]),
                  ],
                ),
              ),
            ],
          ),

          // Positioned(
          //   left: 12,
          //   right: 12,
          //   bottom: 16,
          //   child: AnimatedSlide(
          //     offset: _navVisible ? Offset.zero : const Offset(0, 1.5),
          //     duration: const Duration(milliseconds: 300),
          //     curve: Curves.easeInOut,
          //     child: AnimatedOpacity(
          //       opacity: _navVisible ? 1.0 : 0.0,
          //       duration: const Duration(milliseconds: 250),
          //       curve: Curves.easeInOut,
          //       child: _buildTelegramNav(),
          //     ),
          //   ),
          // ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: _buildTelegramNav()
          ),

          if (selectedIndex == 0)
            Positioned(bottom: 110, right: 18, child: _buildFab(context)),
        ],
      ),
    );
  }

  // Replace DotCurvedBottomNav with this iOS-style nav

  Widget _buildTelegramNav() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: Colors.white.withValues(alpha: 0.80),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.80),
              width: 0.8,
            ),
          ),
          child: SizedBox(
            height: AppSize.height * 0.07,
            child: Row(
              children: [
                _navItem(0, "asset/bottomNav/chat.png",         "asset/bottomNav/chat.png",        'Chats'),
                _navItem(1, "asset/bottomNav/social-media.png", "asset/bottomNav/social-media.png",'Status'),
                _navItem(2, "asset/bottomNav/phone.png",        "asset/bottomNav/phone.png",       'Calls'),
                _navItem(3, "asset/bottomNav/user.png",         "asset/bottomNav/user.png",        'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildIOSLayout() {
    final unreadCount = context.watch<HomeViewModel>().totalUnreadCount;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundLight,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: IndexedStack(
                        index: selectedIndex,
                        children: [
                          ChatsTabContent(scrollController: _controllers[0]),
                          StatusTabContent(scrollController: _controllers[1]),
                          CallsTabContent(scrollController: _controllers[2]),
                          ProfileContent(scrollController: _controllers[3]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: CNTabBar(
                  items: const [
                    CNTabBarItem(
                      label: 'Chats',
                      icon: CNSymbol('bubble.left.and.bubble.right.fill'),
                      //bubble.left.and.bubble.right.fill
                    ),
                    CNTabBarItem(
                      label: 'Status',
                      icon: CNSymbol('circle.dashed'),
                    ),
                    CNTabBarItem(label: 'Calls', icon: CNSymbol('phone.fill')),
                    CNTabBarItem(
                      label: 'Profile',
                      icon: CNSymbol('person.fill'),
                    ),
                  ],
                  currentIndex: selectedIndex,
                  tint: const Color(0xFF0EB587),
                  backgroundColor: Colors.transparent,
                  height: 85,
                  onTap: _handleTabChange,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 60,
                  child: IgnorePointer(
                    child: _buildIosUnreadBadge(context, unreadCount),
                  ),
                ),

              if (selectedIndex == 0)
                Positioned(bottom: 100, right: 18, child: _buildFab(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIosUnreadBadge(BuildContext context, int unreadCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalInset = 16.0;
        final availableWidth = constraints.maxWidth - (horizontalInset * 2);
        final tabWidth = availableWidth / 4;
        final badgeLeft = horizontalInset + (tabWidth * 0.5);

        return Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: Offset(badgeLeft, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(
      int index,
      String iconPath,
      String activeIconPath,
      String label,
      ) {
    final active = selectedIndex == index;
    const inactiveColor = Color(0xFF49494B);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTabChange(index),
          borderRadius: BorderRadius.circular(50),
          child: SizedBox(
            height: double.infinity,
            child: Center(                          //  Center wraps everything
              child: AnimatedScale(
                scale: active ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: active
                        ? const Color(0xFF0EB587).withValues(alpha: 0.12)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,   //  min so it doesn't stretch
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        active ? activeIconPath : iconPath,
                        width: active ? 24 : 22,
                        height: active ? 24 : 22,
                        color: active
                            ? const Color(0xFF0EB587)
                            : inactiveColor,
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          fontSize: active ? 9 : 8,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? const Color(0xFF0EB587)
                              : inactiveColor,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,  // center text too
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildHeader(BuildContext context) {
    final title = titles[selectedIndex];
    final session = context.watch<SessionController>();
    final user = session.user;
    final displayName = user?.profileName ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final avatarUrl = user?.profileImageUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onBackgroundLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      elevation: 4,
      // Added a nice soft shadow
      shape: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.warning, width: 0.08),
      ),
      // Keeps the classic round FAB look
      onPressed: () async {
        final choice = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => const ChatOptionsBottomSheet(),
        );

        if (!context.mounted || choice == null) return;

        if (choice == 'group') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPersonScreen()),
          );
        }
      },
      child: const Icon(Icons.message, color: Colors.white, size: 26),
    );
  }
}

class ChatOptionsBottomSheet extends StatelessWidget {
  const ChatOptionsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              height: 5,
              width: 48,
              decoration: BoxDecoration(
                color: theme.hintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            // New Chat Option
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 12,
              ),
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                ),
              ),
              title: const Text(
                'New chat',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              subtitle: Text(
                'Start a direct message with a contact',
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => Navigator.pop(context, 'direct'),
            ),

            // New Group Option
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 12,
              ),
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                child: const Icon(Icons.group_add_rounded, color: Colors.teal),
              ),
              title: const Text(
                'New group',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              subtitle: Text(
                'Create a space for multiple people',
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => Navigator.pop(context, 'group'),
            ),

            const SizedBox(height: 16), // Bottom safety spacing
          ],
        ),
      ),
    );
  }
}
