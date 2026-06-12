import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/utils/titra_id_utils.dart';
import 'package:titra/features/auth/data/auth_repository.dart';
import 'package:titra/features/profile/presentation/view_models/profile_view_model.dart';

/// Scrollable profile body: avatar, name, ID, Personal Info, Privacy & Security, encryption note, Log Out.
class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileViewModel>().refreshProfile(silent: true);
    });
  }

  Future<void> _pickAndUploadPhoto() async {
    final vm = context.read<ProfileViewModel>();
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (xfile == null || !mounted) return;
    try {
      await vm.uploadPhoto(xfile.path);
      if (mounted) context.read<SnackbarService>().showSuccess('Profile photo updated');
    } catch (_) {
      if (mounted) context.read<SnackbarService>().showError('Could not upload photo');
    }
  }

  void _showStatusBottomSheet(BuildContext context) {
    final vm = context.read<ProfileViewModel>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onBackgroundLight,
                  ),
                ),
              ),
              ...presetStatuses.map((s) => ListTile(
                    title: Text(s),
                    selected: vm.status == s,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      vm.setStatus(s);
                      Navigator.pop(ctx);
                    },
                  )),
              ListTile(
                leading: Icon(Icons.edit_rounded, size: 22, color: AppColors.primary),
                title: const Text('Custom'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomStatusDialog(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }


  void _showCustomStatusDialog(BuildContext context) {
    final vm = context.read<ProfileViewModel>();
    showDialog<void>(
      context: context,
      builder: (ctx) => _CustomStatusDialog(
        initialValue: presetStatuses.contains(vm.status) ? '' : vm.status,
        onSave: vm.setStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final session = context.watch<SessionController>();
    final user = session.user;
    final displayName = user?.profileName ?? 'User';
    final accountDigits = user?.accountId ?? '';
    final imageUrl = user?.profileImageUrl;

    return RefreshIndicator(
      onRefresh: () => vm.refreshProfile(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(
              context,
              vm: vm,
              displayName: displayName,
              accountDigits: accountDigits,
              profileImageUrl: imageUrl,
            ),
            _buildPersonalInfoSection(context, vm),
            _buildPrivacySecuritySection(context),
            _buildEncryptionNote(context),
            _buildLogOutButton(context),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Icon(Icons.logout,size: 32,)
              ),
              SizedBox(height: 12),
              Text(
                "Log Out",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.backgroundDark,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "Are you sure you want to log out of this account?",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF494949),
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Prompt_regular',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.backgroundDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: ()  {
                        context.read<AuthRepository>().logout();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(
                        'Log Out',
                        style: TextStyle(
                          fontFamily: 'Prompt_regular',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.outlineLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildProfileHeader(
    BuildContext context, {
    required ProfileViewModel vm,
    required String displayName,
    required String accountDigits,
    required String? profileImageUrl,
  }) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          GestureDetector(
            onTap: vm.photoUploading ? null : _pickAndUploadPhoto,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (profileImageUrl != null && profileImageUrl.isNotEmpty)
                          Image.network(
                            profileImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _avatarInitialFallback(initial),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          _avatarInitialFallback(initial),
                        if (vm.profileLoading || vm.photoUploading)
                          Container(
                            color: Colors.black38,
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    vm.photoUploading ? Icons.hourglass_top_rounded : Icons.edit_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onBackgroundLight,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: AppColors.primary.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(100),
            shadowColor: AppColors.black,
            child: InkWell(
              onTap: () {
                if (accountDigits.length == 10) {
                  Clipboard.setData(ClipboardData(text: formatTitraIdWithPrefix(accountDigits)));
                  context.read<SnackbarService>().showSuccess('ID copied to clipboard');
                }
              },
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      accountDigits.length == 10
                          ? 'ID: ${formatTitraIdWithPrefix(accountDigits)}'
                          : 'ID: —',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_rounded, size: 18, color: AppColors.black),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap ID to copy',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onBackgroundLight.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarInitialFallback(String initial) {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context, ProfileViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'PERSONAL INFO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.onBackgroundLight.withValues(alpha: 0.6),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.sentiment_satisfied_rounded,
                  iconBgColor: AppColors.primary.withValues(alpha: 0.12),
                  iconColor: AppColors.primary,
                  title: 'Status',
                  subtitle: vm.status,
                  onTap: () => _showStatusBottomSheet(context),
                ),
                Divider(height: 1, indent: 72, color: AppColors.outlineLight.withValues(alpha: 0.5)),
                _ProfileTile(
                  icon: Icons.call_rounded,
                  iconBgColor: Colors.green.shade50,
                  iconColor: Colors.green.shade700,
                  title: 'Phone Number',
                  subtitle: '+1 555-0123',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'VERIFIED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPrivacySecuritySection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'PRIVACY & SECURITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.onBackgroundLight.withValues(alpha: 0.6),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.security_rounded,
                  iconBgColor: Colors.purple.shade50,
                  iconColor: Colors.purple.shade700,
                  title: 'Account Security',
                  subtitle: '2FA Enabled • Keys Updated',
                  onTap: () {},
                ),
                Divider(height: 1, indent: 72, color: AppColors.outlineLight.withValues(alpha: 0.5)),
                _ProfileTile(
                  icon: Icons.lock_rounded,
                  iconBgColor: Colors.orange.shade50,
                  iconColor: Colors.orange.shade700,
                  title: 'Privacy Settings',
                  subtitle: 'Last seen, Read receipts',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildEncryptionNote(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.lock_open_rounded, size: 24, color: AppColors.primary.withValues(alpha: 0.9)),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.onBackgroundLight.withValues(alpha: 0.65),
              ),
              children: [
                const TextSpan(text: 'Your personal messages are '),
                TextSpan(
                  text: 'end-to-end encrypted',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(
                    text: '. No one outside of this chat, not even us, can read or listen to them.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLogOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogoutDialog(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(50),

            ),
            alignment: Alignment.center,
            child: const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomStatusDialog extends StatefulWidget {
  const _CustomStatusDialog({required this.initialValue, required this.onSave});

  final String initialValue;
  final ValueChanged<String> onSave;

  @override
  State<_CustomStatusDialog> createState() => _CustomStatusDialogState();
}

class _CustomStatusDialogState extends State<_CustomStatusDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom status'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter your status',
          border: OutlineInputBorder(),
        ),
        maxLength: 100,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            widget.onSave(value.trim());
            Navigator.pop(context);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) {
              widget.onSave(value);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBackgroundLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onBackgroundLight.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 24),
          ],
        ),
      ),
    );
  }
}
