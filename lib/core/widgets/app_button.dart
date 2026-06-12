import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Global reusable primary button. Uses gradient background by default.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    super.key,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
    this.useGradient = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;
  final ButtonStyle? style;
  /// When true, button uses [AppColors.gradient]. Set false for flat primary color.
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    if (useGradient && style == null) {
      return Material(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              gradient: onPressed != null && !loading
                  ? AppColors.gradient
                  : LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.6),
                        AppColors.secondary.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CupertinoActivityIndicator(color: Colors.white),
                    )
                  : (icon != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconTheme.merge(
                              data: const IconThemeData(color: Colors.white),
                              child: icon!,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        )),
              ),
            ),
          ),
        ),
      );
    }

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon!,
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                )
              : Text(label)),
    );
  }
}
