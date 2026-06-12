import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/app_route_observer.dart';
import 'package:titra/features/status/data/status_repository.dart';
import 'package:titra/features/status/data/story_model.dart';
import 'package:titra/features/status/presentation/view/widgets/create_story_bottom_sheet.dart';
import 'package:video_player/video_player.dart';

/// Full-screen story viewer. Shows one contact's stories in sequence with progress and tap navigation.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.contact,
    required this.isMyStatus,
  });

  final StatusContact contact;
  final bool isMyStatus;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with RouteAware {
  int _currentIndex = 0;
  double _progress = 0.0;
  Timer? _timer;
  StatusContact? _effectiveContact;
  VideoPlayerController? _videoController;
  String? _lastMediaStoryKey;
  final Set<String> _viewRecorded = {};
  bool _holdPaused = false;
  static const int _defaultDurationSeconds = 5;
  static const _tickDuration = Duration(milliseconds: 50);

  int _durationSecondsFor(StoryModel story) {
    if (story.mediaType == StoryMediaType.video &&
        story.durationSeconds != null) {
      return story.durationSeconds!.clamp(1, 30);
    }
    return _defaultDurationSeconds;
  }

  List<StoryModel> get _effectiveStories =>
      _effectiveContact?.stories ?? widget.contact.stories;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _timer?.cancel();
    _disposeVideo();
    super.dispose();
  }

  @override
  void didPushNext() {
    _pausePlayback();
  }

  @override
  void didPopNext() {
    _resumePlayback();
  }

  void _pausePlayback() {
    _holdPaused = false;
    _timer?.cancel();
    _timer = null;
    _videoController?.pause();
  }

  void _resumePlayback() {
    final stories = _effectiveStories;
    if (!mounted || stories.isEmpty || _currentIndex >= stories.length) return;
    final story = stories[_currentIndex];
    if (story.mediaType == StoryMediaType.video) {
      _videoController?.play();
    } else {
      _startImageTimer();
    }
  }

  void _startImageTimer() {
    final stories = _effectiveStories;
    if (stories.isEmpty || _currentIndex >= stories.length) return;

    final story = stories[_currentIndex];
    if (story.mediaType != StoryMediaType.image) return;

    final durationSec = _durationSecondsFor(story);
    final totalMs = durationSec * 1000;
    final endTime = DateTime.now().add(Duration(milliseconds: totalMs));

    _timer?.cancel();
    _timer = Timer.periodic(_tickDuration, (_) {
      if (!mounted) return;
      final remaining = endTime.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _timer?.cancel();
        _timer = null;
        _next(stories.length);
        return;
      }
      setState(() {
        _progress = 1.0 - (remaining.inMilliseconds / totalMs);
      });
    });
  }

  /// Continue the image story timer from the current [_progress] (after hold-to-pause).
  void _resumeImageTimerFromProgress() {
    final stories = _effectiveStories;
    if (stories.isEmpty || _currentIndex >= stories.length) return;

    final story = stories[_currentIndex];
    if (story.mediaType != StoryMediaType.image) return;

    final durationSec = _durationSecondsFor(story);
    final totalMs = durationSec * 1000;
    final remainingMs = ((1.0 - _progress) * totalMs).round().clamp(1, totalMs);
    final endTime = DateTime.now().add(Duration(milliseconds: remainingMs));

    _timer?.cancel();
    _timer = Timer.periodic(_tickDuration, (_) {
      if (!mounted) return;
      final remaining = endTime.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _timer?.cancel();
        _timer = null;
        _next(stories.length);
        return;
      }
      setState(() {
        _progress = 1.0 - (remaining.inMilliseconds / totalMs);
      });
    });
  }

  void _pauseHold() {
    if (_holdPaused) return;
    _holdPaused = true;
    _timer?.cancel();
    _timer = null;
    _videoController?.pause();
    if (mounted) setState(() {});
  }

  void _resumeHold() {
    if (!_holdPaused) return;
    _holdPaused = false;
    final stories = _effectiveStories;
    if (stories.isEmpty || _currentIndex >= stories.length) return;
    final story = stories[_currentIndex];
    if (story.mediaType == StoryMediaType.video) {
      _videoController?.play();
    } else {
      _resumeImageTimerFromProgress();
    }
    if (mounted) setState(() {});
  }

  Future<void> _disposeVideo() async {
    final c = _videoController;
    _videoController = null;
    if (c != null) {
      c.removeListener(_onVideoControllerUpdate);
      await c.dispose();
    }
  }

  void _onVideoControllerUpdate() {
    final c = _videoController;
    if (c == null || !mounted) return;
    if (!c.value.isInitialized) return;
    final d = c.value.duration;
    final p = c.value.position;
    if (d.inMilliseconds > 0) {
      setState(() {
        _progress = (p.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
      });
    }
    if (d > Duration.zero && p >= d - const Duration(milliseconds: 100)) {
      c.removeListener(_onVideoControllerUpdate);
      final total = _effectiveStories.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_next(total));
      });
    }
  }

  Future<void> _syncVideoForStory(StoryModel story) async {
    await _disposeVideo();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(story.mediaUrl),
    );
    try {
      await _videoController!.initialize();
    } catch (_) {
      await _disposeVideo();
      if (mounted) setState(() {});
      return;
    }
    _videoController!.addListener(_onVideoControllerUpdate);
    await _videoController!.setLooping(false);
    await _videoController!.play();
    if (mounted) setState(() {});
  }

  Future<void> _activateStoryMedia(StoryModel story) async {
    if (!mounted) return;
    _holdPaused = false;
    _timer?.cancel();
    _timer = null;

    if (!widget.isMyStatus && !_viewRecorded.contains(story.id)) {
      _viewRecorded.add(story.id);
      unawaited(
        context
            .read<StatusRepository>()
            .recordView(story.id)
            .catchError((_) {}),
      );
    }

    if (story.mediaType == StoryMediaType.video) {
      await _syncVideoForStory(story);
    } else {
      await _disposeVideo();
      _startImageTimer();
    }
  }

  void _openViewersSheet(String storyId) {
    final repo = context.read<StatusRepository>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Viewed by',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<StoryViewer>>(
                    future: repo.fetchViewers(storyId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                          ),
                        );
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            'Could not load viewers',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        );
                      }
                      final list = snap.data ?? [];
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            'No views yet',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            Divider(color: Colors.grey.shade700, height: 1),
                        itemBuilder: (context, i) {
                          final v = list[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  v.profileImageUrl != null &&
                                      v.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(v.profileImageUrl!)
                                  : null,
                              child:
                                  v.profileImageUrl == null ||
                                      v.profileImageUrl!.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white54,
                                    )
                                  : null,
                            ),
                            title: Text(
                              v.profileName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              _formatViewedAt(v.viewedAt),
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateStory() async {
    _pausePlayback();
    final posted = await showCreateStoryBottomSheet(context);
    if (!mounted) return;
    if (posted == true) {
      await context.read<StatusRepository>().loadFeed(force: true);
    }
    _resumePlayback();
  }

  String _formatViewedAt(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<StatusRepository>();
    final contact = widget.isMyStatus ? repo.myStatusContact : widget.contact;
    _effectiveContact = contact;

    final stories = contact.stories;
    if (stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: _backButton(),
        ),
        body: const Center(
          child: Text('No stories', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (_currentIndex >= stories.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = stories.length - 1);
      });
    }
    final safeIndex = _currentIndex.clamp(0, stories.length - 1);
    final story = stories[safeIndex];

    final storyKey = '${safeIndex}_${story.id}';
    if (_lastMediaStoryKey != storyKey) {
      _lastMediaStoryKey = storyKey;
      _progress = 0.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_activateStoryMedia(story));
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Use [onTapUp] instead of [onTapDown]: touch-down fired immediately and
        // stole long-press / hold-to-pause, and edge taps popped the viewer.
        onTapUp: (d) {
          final w = MediaQuery.sizeOf(context).width;
          if (d.globalPosition.dx > w / 2) {
            _next(stories.length);
          } else {
            _prev(stories.length);
          }
        },
        onLongPressStart: (_) => _pauseHold(),
        onLongPressEnd: (_) => _resumeHold(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(story),
            SafeArea(
              child: Column(
                children: [
                  _buildProgressBars(stories.length),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _backButton(),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 20,
                          backgroundImage:
                              contact.avatarUrl != null &&
                                  contact.avatarUrl!.isNotEmpty
                              ? NetworkImage(contact.avatarUrl!)
                              : null,
                          child:
                              contact.avatarUrl == null ||
                                  contact.avatarUrl!.isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            contact.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isMyStatus) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.remove_red_eye_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: 'Viewers',
                            onPressed: () => _openViewersSheet(story.id),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Add story',
                            onPressed: _openCreateStory,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (story.caption != null && story.caption!.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 48,
                child: Text(
                  story.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(StoryModel story) {
    if (story.mediaType == StoryMediaType.video) {
      final c = _videoController;
      if (c != null && c.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio == 0
                ? 16 / 9
                : c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        );
      }
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text('Loading video…', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    final isNetwork = story.mediaUrl.startsWith('http');
    return Center(
      child: isNetwork
          ? Image.network(
              story.mediaUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_not_supported,
                color: Colors.white54,
                size: 48,
              ),
            )
          : Image.file(
              File(story.mediaUrl),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.image_not_supported,
                color: Colors.white54,
                size: 48,
              ),
            ),
    );
  }

  Widget _backButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      onPressed: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildProgressBars(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: List.generate(count, (i) {
          final isActive = i == _currentIndex;
          final isPast = i < _currentIndex;
          final fill = isPast ? 1.0 : (isActive ? _progress : 0.0);
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth * fill.clamp(0.0, 1.0);
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (w > 0)
                        Container(
                          width: w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _next(int total) async {
    _timer?.cancel();
    _timer = null;
    await _disposeVideo();
    if (_currentIndex < total - 1) {
      if (mounted) {
        setState(() {
          _currentIndex++;
          _progress = 0.0;
          _lastMediaStoryKey = null;
        });
      }
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _prev(int total) async {
    _timer?.cancel();
    _timer = null;
    await _disposeVideo();
    if (_currentIndex > 0) {
      if (mounted) {
        setState(() {
          _currentIndex--;
          _progress = 0.0;
          _lastMediaStoryKey = null;
        });
      }
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }
}
