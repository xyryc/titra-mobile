import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/auth/data/auth_repository.dart';
import 'package:titra/features/auth/presentation/view_models/login_view_model.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.onForgotPressed,
    this.onCreateIdentityPressed,
  });

  final VoidCallback? onForgotPressed;
  final VoidCallback? onCreateIdentityPressed;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: _LoginView(
        onForgotPressed: onForgotPressed,
        onCreateIdentityPressed: onCreateIdentityPressed,
      ),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView({
    this.onForgotPressed,
    this.onCreateIdentityPressed,
  });

  final VoidCallback? onForgotPressed;
  final VoidCallback? onCreateIdentityPressed;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final theme = Theme.of(context);
    const muted = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top gradient strip
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header: [space] [lock + SECURE CHAT] [space]
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'SECURE CHAT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onBackgroundLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        // Hero: circular shield
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.outlineLight),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.security_rounded,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // "Enter the Secure Zone"
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onBackgroundLight,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                            children: [
                              const TextSpan(text: 'Enter the '),
                              TextSpan(
                                text: 'Secure Zone',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'End-to-End Encrypted Messaging. Your identity is protected.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Unique 10-Digit ID
                        _FieldLabel('Unique 10-Digit ID'),
                        const SizedBox(height: 8),
                        TextFormField(
                          onChanged: vm.setUserId,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                            _IdInputFormatter(),
                          ],
                          decoration: _inputDecoration(
                            hint: '000 000 0000',
                            prefixIcon: Icons.badge_outlined,
                            prefix: const Text(
                              '+0 ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        if (vm.userIdError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            vm.userIdError!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Password
                        _FieldLabel('Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          obscureText: !vm.passwordVisible,
                          onChanged: vm.setPassword,
                          decoration: _inputDecoration(
                            hint: '••••••••••••',
                            prefixIcon: Icons.key_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                vm.passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: muted,
                              ),
                              onPressed: vm.togglePasswordVisible,
                            ),
                          ),
                        ),
                        if (vm.passwordError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            vm.passwordError!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: onForgotPressed ?? () {},
                            child: const Text(
                              'Forgot ID or Password?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // UNLOCK CHAT button
                        _GradientButton(
                          label: 'UNLOCK CHAT',
                          icon: Icons.lock_open_rounded,
                          loading: vm.isLoading,
                          onPressed: () => vm.submit(() async {
                            if (!context.mounted) return;
                            final auth = context.read<AuthRepository>();
                            await auth.login(
                              accountId: vm.userId,
                              password: vm.password,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom: divider, Create New ID, footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.outlineLight)),
                  ),
                  child: Column(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          if (onCreateIdentityPressed != null) {
                            onCreateIdentityPressed!();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.onBackgroundLight,
                          side: const BorderSide(color: AppColors.outlineLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Create New ID', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded, size: 16, color: muted),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Your privacy is our priority. No phone numbers required.',
                              style: theme.textTheme.bodySmall?.copyWith(color: muted, fontSize: 12),
                              textAlign: TextAlign.center,
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
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
    Widget? prefix,
  }) {
    const muted = Color(0xFF64748B);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.7)),
      prefixIcon: Icon(prefixIcon, size: 22, color: muted),
      prefix: prefix,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.onBackgroundLight,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      shadowColor: AppColors.primary.withValues(alpha: 0.35),
      elevation: 4,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: loading ? null : AppColors.gradient,
            color: loading ? AppColors.outlineLight : null,
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
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
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

/// Formats 10 digits as XXX XXX XXXX.
class _IdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 10) return oldValue;
    String formatted = text;
    if (text.length > 6) {
      formatted = '${text.substring(0, 3)} ${text.substring(3, 6)} ${text.substring(6)}';
    } else if (text.length > 3) {
      formatted = '${text.substring(0, 3)} ${text.substring(3)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
