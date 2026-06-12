import 'package:flutter/material.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/profile/presentation/view/profile_content.dart';

/// Full-screen profile (e.g. when pushed from a deep link). For the main app, Profile is shown
/// as a tab via [ProfileContent] inside Home so the bottom nav stays visible.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      // appBar: AppBar(
      //   backgroundColor: AppColors.backgroundLight.withValues(alpha: 0.9),
      //   elevation: 0,
      //   scrolledUnderElevation: 0,
      //   leading: IconButton(
      //     icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      //     onPressed: () => Navigator.of(context).pop(),
      //     color: AppColors.primary,
      //   ),
      //   centerTitle: true,
      //   title: const Text(
      //     'Profile',
      //     style: TextStyle(
      //       color: AppColors.onBackgroundLight,
      //       fontSize: 18,
      //       fontWeight: FontWeight.bold,
      //     ),
      //   ),
      //   actions: [
      //     TextButton(
      //       onPressed: () {},
      //       child: const Text(
      //         'Edit',
      //         style: TextStyle(
      //           color: AppColors.primary,
      //           fontWeight: FontWeight.bold,
      //           fontSize: 16,
      //         ),
      //       ),
      //     ),
      //   ],
      // ),
      body: const SafeArea(
        child: ProfileContent(),
      ),
    );
  }
}
