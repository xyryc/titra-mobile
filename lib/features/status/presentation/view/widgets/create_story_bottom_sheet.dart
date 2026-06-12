import 'package:flutter/material.dart';
import 'package:titra/features/status/presentation/view/widgets/create_story_content.dart';

Future<bool?> showCreateStoryBottomSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.40,
      child: const ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        child: CreateStoryContent(isInsideSheet: true),
      ),
    ),
  );
}
