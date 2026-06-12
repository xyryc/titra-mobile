import 'package:flutter/material.dart';
import 'package:titra/core/theme/app_colors.dart';

class CreateStoryPickerSheet extends StatelessWidget {
  const CreateStoryPickerSheet({
    super.key,
    required this.onClose,
    required this.onTakePhoto,
    required this.onChoosePhoto,
    required this.onChooseVideo,
  });

  final VoidCallback onClose;
  final VoidCallback onTakePhoto;
  final VoidCallback onChoosePhoto;
  final VoidCallback onChooseVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                  const Expanded(
                    child: Text(
                      'Add status',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),

              const Spacer(),

              _PickerButton(
                icon: Icons.camera_alt_rounded,
                text: 'Take photo',
                filled: true,
                onPressed: onTakePhoto,
              ),

              const SizedBox(height: 10),

              _PickerButton(
                icon: Icons.photo_library_rounded,
                text: 'Choose photo',
                filled: true,
                onPressed: onChoosePhoto,
              ),

              const SizedBox(height: 10),

              _PickerButton(
                icon: Icons.videocam_rounded,
                text: 'Choose video',
                filled: false,
                onPressed: onChooseVideo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.text,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 44),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
      ),
    );
  }
}