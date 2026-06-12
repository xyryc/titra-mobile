import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/status/data/status_repository.dart';
import 'package:titra/features/status/data/story_model.dart';
import 'package:titra/features/status/presentation/view_models/create_story_view_model.dart';

import 'create_story_picker_sheet.dart';

class CreateStoryContent extends StatelessWidget {
  const CreateStoryContent({super.key, this.isInsideSheet = false});

  final bool isInsideSheet;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          CreateStoryViewModel(statusRepository: ctx.read<StatusRepository>()),
      child: _CreateStoryBody(isInsideSheet: isInsideSheet),
    );
  }
}

class _CreateStoryBody extends StatefulWidget {
  const _CreateStoryBody({required this.isInsideSheet});

  final bool isInsideSheet;

  @override
  State<_CreateStoryBody> createState() => _CreateStoryBodyState();
}

class _CreateStoryBodyState extends State<_CreateStoryBody> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (xFile == null || !mounted) return;

    context.read<CreateStoryViewModel>().setMedia(
      xFile.path,
      StoryMediaType.image,
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    final xFile = await _picker.pickVideo(source: source);
    if (xFile == null || !mounted) return;

    context.read<CreateStoryViewModel>().setMedia(
      xFile.path,
      StoryMediaType.video,
    );
  }

  void _closePicker() {
    Navigator.of(context).pop(widget.isInsideSheet ? false : null);
  }

  void _backToPicker() {
    _captionController.clear();
    context.read<CreateStoryViewModel>().clearMedia();
  }

  Future<void> _post() async {
    final vm = context.read<CreateStoryViewModel>();
    try {
      final ok = await vm.post(_captionController.text);
      if (!mounted || !ok) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post status. Try again.')),
      );
    }
  }

  Future<void> _postAndAddAnother() async {
    final vm = context.read<CreateStoryViewModel>();
    try {
      await vm.postAndReset(_captionController.text);
      if (!mounted) return;
      _captionController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Status posted')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post status. Try again.')),
      );
    }
  }

  Widget _buildPreview(String pickedPath, StoryMediaType mediaType) {
    if (mediaType == StoryMediaType.image) {
      return Image.file(File(pickedPath), fit: BoxFit.contain);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.videocam_rounded, size: 72, color: Colors.white54),
        SizedBox(height: 12),
        Text(
          'Video selected',
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildPreviewComposer(CreateStoryViewModel vm) {
    final pickedPath = vm.pickedPath!;
    final mediaType = vm.mediaType!;

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.black,
                    ),
                    onPressed: vm.posting ? null : _backToPicker,
                  ),
                  const Expanded(
                    child: Text(
                      'Preview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(child: _buildPreview(pickedPath, mediaType)),
            ),
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _captionController,
                    enabled: !vm.posting,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Add a caption',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: vm.posting ? null : _postAndAddAnother,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: const Text('Add another'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: vm.posting ? null : _post,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: vm.posting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Post'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateStoryViewModel>();

    if (!vm.hasMedia) {
      return CreateStoryPickerSheet(
        onClose: _closePicker,
        onTakePhoto: () => _pickImage(ImageSource.camera),
        onChoosePhoto: () => _pickImage(ImageSource.gallery),
        onChooseVideo: () => _pickVideo(ImageSource.gallery),
      );
    }

    return _buildPreviewComposer(vm);
  }
}
