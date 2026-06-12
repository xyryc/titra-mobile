import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/status/data/status_repository.dart';
import 'package:titra/features/status/data/story_model.dart';
import 'package:titra/features/status/presentation/view/story_viewer_screen.dart';
import 'package:titra/features/status/presentation/view/widgets/create_story_bottom_sheet.dart';

/// Status tab: My status row + contacts with active stories (from API).
class StatusTabContent extends StatefulWidget {
  const StatusTabContent({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<StatusTabContent> createState() => _StatusTabContentState();
}

class _StatusTabContentState extends State<StatusTabContent>
    with WidgetsBindingObserver {
  Future<void> _openCreateStory() async {
    final posted = await showCreateStoryBottomSheet(context);
    if (posted == true && mounted) {
      await context.read<StatusRepository>().loadFeed(force: true);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StatusRepository>().loadFeed();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<StatusRepository>().loadFeed();
    }
  }

  Future<void> _onRefresh() async {
    await context.read<StatusRepository>().loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<StatusRepository>();
    final session = context.watch<SessionController>();

    if (repo.loading &&
        repo.myStatusContact.stories.isEmpty &&
        repo.contactsWithActiveStories.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (repo.loadError != null &&
        repo.myStatusContact.id.isEmpty &&
        repo.contactsWithActiveStories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                repo.loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => repo.loadFeed(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final myContact = repo.myStatusContact;
    final contacts = repo.contactsWithActiveStories;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _onRefresh,
      child: ListView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _MyStatusRow(
            contact: myContact,
            avatarUrl: session.user?.profileImageUrl ?? myContact.avatarUrl,
            onTap: () {
              if (myContact.stories.isEmpty) {
                _openCreateStory();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        StoryViewerScreen(contact: myContact, isMyStatus: true),
                  ),
                );
              }
            },
            onAddTap: myContact.stories.isNotEmpty ? _openCreateStory : null,
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Recent updates',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          if (contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'No status updates',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ...contacts.map(
              (c) => _StatusContactTile(
                contact: c,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          StoryViewerScreen(contact: c, isMyStatus: false),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _MyStatusRow extends StatelessWidget {
  const _MyStatusRow({
    required this.contact,
    this.avatarUrl,
    required this.onTap,
    this.onAddTap,
  });

  final StatusContact contact;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    final hasStories = contact.stories.isNotEmpty;
    final count = contact.stories.length;
    final subtitle = hasStories
        ? '$count ${count == 1 ? 'story' : 'stories'} · ${_timeAgo(contact.latestStoryAt!)}'
        : 'Add status';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _AvatarWithRing(
              avatarUrl: avatarUrl,
              hasStories: hasStories,
              showAddRing: !hasStories,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onBackgroundLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (onAddTap != null)
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: onAddTap,
                tooltip: 'Add story',
                style: IconButton.styleFrom(foregroundColor: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _StatusContactTile extends StatelessWidget {
  const _StatusContactTile({required this.contact, required this.onTap});

  final StatusContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeAgo = contact.latestStoryAt != null
        ? _timeAgo(contact.latestStoryAt!)
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _AvatarWithRing(
              avatarUrl: contact.avatarUrl,
              hasStories: true,
              showAddRing: false,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onBackgroundLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeAgo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _AvatarWithRing extends StatelessWidget {
  const _AvatarWithRing({
    this.avatarUrl,
    required this.hasStories,
    required this.showAddRing,
  });

  final String? avatarUrl;
  final bool hasStories;
  final bool showAddRing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: showAddRing
            ? LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : hasStories
            ? const LinearGradient(
                colors: [
                  Color(0xFFF58529),
                  Color(0xFFDD2A7B),
                  Color(0xFF8134AF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.outlineLight,
          backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
              ? NetworkImage(avatarUrl!)
              : null,
          child: showAddRing
              ? Icon(Icons.add_rounded, color: Colors.grey.shade600, size: 28)
              : (avatarUrl == null || avatarUrl!.isEmpty)
              ? Icon(
                  Icons.person_rounded,
                  color: Colors.grey.shade600,
                  size: 28,
                )
              : null,
        ),
      ),
    );
  }
}
