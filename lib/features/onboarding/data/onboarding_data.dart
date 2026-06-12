import 'onboarding_page_model.dart';

/// Static onboarding slides. Add or edit slides here.
class OnboardingData {
  OnboardingData._();

  static const List<OnboardingPageModel> pages = [
    OnboardingPageModel(
      title: 'Your Privacy,\nOur Priority',
      body:
          'Experience true freedom with end-to-end encryption. Your texts, voice, and video calls are visible only to you.',
    ),
    OnboardingPageModel(
      title: 'Choose Your Unique ID',
      body:
          'Forget phone numbers. Connect with total anonymity using a unique 10-digit identity key. Your data, your rules.',
    ),
    OnboardingPageModel(
      title: 'High Quality Calls & Media',
      body:
          'Experience crystal-clear voice and video calls without lag. Share high-res photos and videos instantly with end-to-end encryption.',
    ),
  ];
}
