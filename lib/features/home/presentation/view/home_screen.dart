import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/home/presentation/view/calls_tab_content.dart';
import 'package:titra/features/home/presentation/view/chats_tab_content.dart';
import 'package:titra/features/home/presentation/view_models/home_view_model.dart';
import 'package:titra/features/profile/presentation/view/profile_content.dart';
import 'package:titra/features/status/presentation/view/status_tab_content.dart';

/// Home screen – Chats list, search, FAB, curved dotted bottom nav (Chats / Calls / Settings).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeViewModel>().loadConversations();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final selectedIndex = vm.selectedNavIndex;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, selectedIndex),
            Expanded(
              child: selectedIndex == 0
                  ? ChatsTabContent(scrollController: _scrollController)
                  : selectedIndex == 1
                      ? StatusTabContent(scrollController: _scrollController)
                      : selectedIndex == 2
                          ? CallsTabContent(scrollController: _scrollController)
                          : ProfileContent(scrollController: _scrollController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int selectedIndex) {
    final titles = ['Chats', 'Status', 'Calls', 'Profile'];
    final title = titles[selectedIndex.clamp(0, 3)];
    final session = context.watch<SessionController>();
    final user = session.user;
    final displayName = user?.profileName ?? 'User';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final avatarUrl = user?.profileImageUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
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
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onBackgroundLight,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
