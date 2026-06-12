import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/onboarding/data/onboarding_data.dart';
import 'package:titra/features/onboarding/presentation/view_models/onboarding_view_model.dart';
import 'package:titra/features/onboarding/presentation/widgets/onboarding_page_indicator.dart';

import 'onboarding_page_content.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingViewModel(),
      child: _OnboardingView(onComplete: onComplete),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView({this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip - top right
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 20),
                child: TextButton.icon(
                  onPressed: widget.onComplete,
                  label: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  icon: Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.grey.shade600),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: OnboardingData.pages.length,
                onPageChanged: (index) => vm.setPage(index),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return OnboardingPageContent(
                    page: OnboardingData.pages[index],
                    pageIndex: index,
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            OnboardingPageIndicator(
              pageCount: vm.pageCount,
              currentPage: vm.currentPage,
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _NextButton(
                isLastPage: vm.isLastPage,
                onNext: () {
                  if (vm.isLastPage) {
                    widget.onComplete?.call();
                  } else {
                    vm.nextPage();
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
            // Footer: END-TO-END ENCRYPTED or legal disclaimer on last page
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: vm.isLastPage
                  ? _LegalFooter()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          'END-TO-END ENCRYPTED',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final gray = Colors.grey.shade500;
    final linkStyle = TextStyle(fontSize: 12, color: gray, decoration: TextDecoration.underline);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text("By tapping 'Get Started', you agree to our ", style: TextStyle(fontSize: 12, color: gray)),
          GestureDetector(
            onTap: () { /* TODO: open Terms */ },
            child: Text('Terms', style: linkStyle),
          ),
          Text(' and ', style: TextStyle(fontSize: 12, color: gray)),
          GestureDetector(
            onTap: () { /* TODO: open Privacy Policy */ },
            child: Text('Privacy Policy', style: linkStyle),
          ),
          Text('.', style: TextStyle(fontSize: 12, color: gray)),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.isLastPage,
    required this.onNext,
  });

  final bool isLastPage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onNext,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isLastPage ? 'Get Started' : 'Next',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
