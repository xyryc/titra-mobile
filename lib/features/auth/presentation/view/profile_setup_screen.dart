import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/utils/titra_id_utils.dart';
import 'package:titra/features/auth/data/auth_repository.dart';

/// Shown once after successful registration; confirms Titra ID and display name before home.
class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileSetupView();
  }
}

class _ProfileSetupView extends StatefulWidget {
  const _ProfileSetupView();

  @override
  State<_ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<_ProfileSetupView> {
  late final TextEditingController _nameController;
  final ImagePicker _picker = ImagePicker();
  String? _pickedImagePath;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionController>().user;
    _nameController = TextEditingController(text: user?.profileName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (x == null || !mounted) return;
    setState(() => _pickedImagePath = x.path);
  }

  Future<void> _complete() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (_pickedImagePath != null) {
        try {
          await context.read<AuthRepository>().uploadProfilePhotoFromPath(_pickedImagePath!);
        } catch (_) {
          // Photo is optional; do not block onboarding if the server errors (e.g. 502).
          if (mounted) {
            context.read<SnackbarService>().showError(
              'Could not upload photo right now. You can add one later in settings.',
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
      if (!mounted) return;
      await context.read<SessionController>().completeProfileSetup();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    final accountId = user?.accountId ?? '';
    final theme = Theme.of(context);
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (user?.profileName ?? 'User');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'Almost there',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onBackgroundLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confirm your Titra ID and how others see you. You can change your display name later when the server supports it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'YOUR TITRA ID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.onBackgroundLight.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: formatTitraIdWithPrefix(accountId)),
                    );
                    if (!context.mounted) return;
                    context.read<SnackbarService>().showSuccess(
                          'Titra ID copied to clipboard',
                          duration: const Duration(seconds: 2),
                        );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatTitraIdWithPrefix(accountId),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const Icon(Icons.copy_rounded, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to copy. Share this ID so friends can find you.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onBackgroundLight.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'DISPLAY NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.onBackgroundLight.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Name shown to others',
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'PROFILE PHOTO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.onBackgroundLight.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundImage: _pickedImagePath != null
                        ? FileImage(File(_pickedImagePath!))
                        : null,
                    child: _pickedImagePath == null
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _pickPhoto,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                          label: const Text('Add photo (optional)'),
                        ),
                        if (_pickedImagePath != null)
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _pickedImagePath = null),
                            child: const Text('Remove photo'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _complete,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CupertinoActivityIndicator(color: Colors.white,),
                        )
                      : const Text(
                          'Complete setup',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
