import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/utils/titra_id_utils.dart';
import 'package:titra/features/auth/data/auth_repository.dart';
import 'package:titra/features/auth/presentation/view_models/create_identity_view_model.dart';
import 'package:titra/features/auth/presentation/widgets/password_strength_indicator.dart';

class CreateIdentityScreen extends StatelessWidget {
  const CreateIdentityScreen({super.key, this.onLoginPressed});

  final VoidCallback? onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateIdentityViewModel(),
      child: _CreateIdentityView(onLoginPressed: onLoginPressed),
    );
  }
}

class _CreateIdentityView extends StatelessWidget {
  const _CreateIdentityView({this.onLoginPressed});

  final VoidCallback? onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CreateIdentityViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      // appBar: AppBar(
      //   backgroundColor: Colors.white,
      //   elevation: 0,
      //   scrolledUnderElevation: 0,
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back_ios_new_rounded),
      //     onPressed: () => Navigator.of(context).pop(),
      //     color: AppColors.onSurfaceLight,
      //   ),
      //   title: const Text(
      //     'Create Identity',
      //     style: TextStyle(
      //       color: AppColors.onSurfaceLight,
      //       fontSize: 18,
      //       fontWeight: FontWeight.bold,
      //     ),
      //   ),
      //   centerTitle: true,
      // ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Header
              const Text(
                'Secure Sign Up',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onBackgroundLight,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your privacy is our priority. Your ID is your only address.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              // Unique ID card
              _UniqueIdCard(
                uniqueId: vm.uniqueId,
                onRefresh: vm.refreshId,
                onCopy: () {
                  vm.copyId((text) => Clipboard.setData(ClipboardData(text: formatTitraIdWithPrefix(text))));
                  context.read<SnackbarService>().showSuccess('ID copied');
                },
              ),
              const SizedBox(height: 32),
              // Form
              _SectionLabel('DISPLAY NAME (OPTIONAL, MIN 2 CHARS)'),
              const SizedBox(height: 8),
              TextFormField(
                onChanged: (value) => vm.displayName = value,
                decoration: _inputDecoration(
                  hint: 'Enter your public name',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel('CREATE PASSWORD'),
              const SizedBox(height: 8),
              TextFormField(
                obscureText: !vm.passwordVisible,
                onChanged: vm.setPassword,
                decoration: _inputDecoration(
                  hint: 'Enter a strong password',
                  prefixIcon: Icons.lock_outline_rounded,
                  hasError: vm.passwordError != null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      vm.passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: vm.togglePasswordVisible,
                  ),
                ),
              ),
              if (vm.passwordError != null) ...[
                const SizedBox(height: 4),
                Text(vm.passwordError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              PasswordStrengthIndicator(
                level: vm.passwordStrength.$1,
                label: vm.passwordStrength.$2,
              ),
              const SizedBox(height: 20),
              _SectionLabel('CONFIRM PASSWORD'),
              const SizedBox(height: 8),
              TextFormField(
                obscureText: !vm.confirmPasswordVisible,
                onChanged: vm.setConfirmPassword,
                decoration: _inputDecoration(
                  hint: 'Re-enter password',
                  prefixIcon: Icons.lock_reset_rounded,
                  hasError: vm.confirmError != null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      vm.confirmPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: vm.toggleConfirmPasswordVisible,
                  ),
                ),
              ),
              if (vm.confirmError != null) ...[
                const SizedBox(height: 4),
                Text(vm.confirmError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 32),
              // End-to-End Encrypted chip
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.outlineLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'End-to-End Encrypted',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Initialize & Enter button (disabled until password + confirm match and valid)
              _GradientButton(
                label: 'Initialize & Enter',
                icon: Icons.arrow_forward_rounded,
                loading: vm.isLoading,
                enabled: vm.canSubmit,
                onPressed: vm.canSubmit
                    ? () => vm.submit(() async {
                          if (!context.mounted) return;
                          final accountId = vm.uniqueId.replaceAll(RegExp(r'[^0-9]'), '');
                          await context.read<AuthRepository>().register(
                                accountId: accountId,
                                profileName: vm.profileNameForRegister,
                                password: vm.password,
                              );
                        })
                    : null,
              ),
              const SizedBox(height: 24),
              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an ID? ',
                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
                  ),
                  GestureDetector(
                    onTap: onLoginPressed ?? () => Navigator.of(context).pop(),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool hasError = false,
  }) {
    final borderSide = BorderSide(
      color: hasError ? AppColors.error : AppColors.outlineLight,
      width: hasError ? 2 : 1,
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIcon: Icon(prefixIcon, size: 22, color: hasError ? AppColors.error : Colors.grey.shade500),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: borderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? AppColors.error : AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF475569),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _UniqueIdCard extends StatelessWidget {
  const _UniqueIdCard({
    required this.uniqueId,
    required this.onRefresh,
    required this.onCopy,
  });

  final String uniqueId;
  final VoidCallback onRefresh;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.vpn_key_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'UNIQUE IDENTIFIER',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineLight),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatTitraIdWithPrefix(uniqueId),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OutlinedActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'REFRESH',
                    onPressed: onRefresh,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OutlinedActionButton(
                    icon: Icons.copy_rounded,
                    label: 'COPY ID',
                    onPressed: onCopy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF475569),
        side: const BorderSide(color: AppColors.outlineLight),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.loading,
    this.enabled = true,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || loading;
    return Material(
      borderRadius: BorderRadius.circular(12),
      shadowColor: isDisabled ? Colors.transparent : AppColors.primary.withValues(alpha: 0.3),
      elevation: isDisabled ? 0 : 4,
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isDisabled ? null : AppColors.gradient,
            color: isDisabled ? AppColors.outlineLight : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isDisabled ? Colors.grey.shade600 : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: isDisabled ? Colors.grey.shade600 : Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
