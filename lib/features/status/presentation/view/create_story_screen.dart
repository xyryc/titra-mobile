import 'package:flutter/material.dart';
import 'package:titra/features/status/presentation/view/widgets/create_story_content.dart';

class CreateStoryScreen extends StatelessWidget {
  const CreateStoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateStoryContent(isInsideSheet: false);
  }
}