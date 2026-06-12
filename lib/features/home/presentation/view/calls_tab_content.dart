import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/call/data/call_history_entry.dart';
import 'package:titra/features/call/presentation/view_models/calls_view_model.dart';

/// Calls tab: scrollable history from `GET calls/history`.
class CallsTabContent extends StatefulWidget {
  const CallsTabContent({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<CallsTabContent> createState() => _CallsTabContentState();
}

class _CallsTabContentState extends State<CallsTabContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CallsViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CallsViewModel>();

    if (vm.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (vm.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                vm.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => vm.load(force: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (vm.items.isEmpty) {
      return Center(
        child: Text(
          'No call history yet',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => vm.load(force: true),
      child: ListView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        children: _buildSectionedChildren(context, vm.items),
      ),
    );
  }
}

class _DaySection {
  _DaySection(this.day);

  /// Local calendar date (year/month/day only).
  final DateTime day;
  final List<CallHistoryEntry> entries = [];
}

DateTime _dateOnlyLocal(DateTime utc) {
  final l = utc.toLocal();
  return DateTime(l.year, l.month, l.day);
}

List<_DaySection> _groupByLocalDay(List<CallHistoryEntry> items) {
  final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final sections = <_DaySection>[];
  for (final e in sorted) {
    final day = _dateOnlyLocal(e.createdAt);
    if (sections.isEmpty || sections.last.day != day) {
      sections.add(_DaySection(day)..entries.add(e));
    } else {
      sections.last.entries.add(e);
    }
  }
  return sections;
}

String _sectionHeaderTitle(DateTime day, Locale locale, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  return DateFormat.yMMMd(locale.toString()).format(day);
}

List<Widget> _buildSectionedChildren(
  BuildContext context,
  List<CallHistoryEntry> items,
) {
  final locale = Localizations.localeOf(context);
  final now = DateTime.now();
  final sections = _groupByLocalDay(items);
  final timeFmt = DateFormat.jm(locale.toString());

  final children = <Widget>[];
  var sectionIndex = 0;
  var anyTileYet = false;

  for (final s in sections) {
    children.add(
      Padding(
        padding: EdgeInsets.fromLTRB(16, sectionIndex == 0 ? 10 : 20, 11, 8),
        child: Text(
          _sectionHeaderTitle(s.day, locale, now),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
    for (final e in s.entries) {
      if (anyTileYet) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 100, right: 20),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        );
      }
      children.add(
        _CallHistoryTile(
          entry: e,
          timeLabel: timeFmt.format(e.createdAt.toLocal()),
        ),
      );
      anyTileYet = true;
    }
    sectionIndex++;
  }
  return children;
}

class _CallHistoryTile extends StatelessWidget {
  const _CallHistoryTile({required this.entry, required this.timeLabel});

  final CallHistoryEntry entry;
  final String timeLabel;

  static String _formatDuration(int sec) {
    if (sec < 3600) {
      final m = sec ~/ 60;
      final s = sec % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _subtitle() {
    final when = timeLabel;
    final outcome = entry.outcome;
    final incoming = entry.direction == 'incoming';

    switch (outcome) {
      case 'completed':
        final dur = entry.durationSec;
        if (dur != null && dur > 0) {
          return incoming
              ? 'Received · $when · ${_formatDuration(dur)}'
              : 'Outgoing · $when · ${_formatDuration(dur)}';
        }
        return incoming ? 'Received · $when' : 'Outgoing · $when';
      case 'missed':
        return 'Missed call · $when';
      case 'declined':
        return 'Declined · $when';
      case 'cancelled':
        return 'Cancelled · $when';
      case 'no_answer':
        return 'Not answered · $when';
      default:
        return 'Call · $when';
    }
  }

  Color _accent() {
    switch (entry.outcome) {
      case 'missed':
      case 'no_answer':
        return const Color(0xFFDC2626);
      case 'declined':
        return const Color(0xFFEA580C);
      case 'cancelled':
        return const Color(0xFF6B7280);
      case 'completed':
        return AppColors.primary;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle();
    final accent = _accent();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CallAvatar(entry: entry),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.onBackgroundLight,
                        ),
                      ),
                    ),
                    Icon(
                      entry.isVideo
                          ? CupertinoIcons.video_camera_solid
                          : CupertinoIcons.phone_fill,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.1,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallAvatar extends StatelessWidget {
  const _CallAvatar({required this.entry});

  final CallHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final url = entry.peerAvatarUrl;
    if (url != null && url.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 0.6),
        ),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.black26,
          backgroundImage: NetworkImage(url),
        ),
      );
    }
    if (entry.isGroup) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.outlineLight),
        ),
        child: Icon(Icons.group_rounded, size: 28, color: Colors.grey.shade600),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade300, Colors.grey.shade400],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70),
      ),
      child: Icon(Icons.person_rounded, size: 28, color: Colors.grey.shade600),
    );
  }
}
