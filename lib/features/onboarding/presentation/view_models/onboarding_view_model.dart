import 'package:flutter/foundation.dart';

import '../../data/onboarding_data.dart';

class OnboardingViewModel extends ChangeNotifier {
  int _currentPage = 0;
  int get currentPage => _currentPage;
  int get pageCount => OnboardingData.pages.length;
  bool get isLastPage => _currentPage >= pageCount - 1;

  void setPage(int index) {
    if (index == _currentPage) return;
    _currentPage = index.clamp(0, pageCount - 1);
    notifyListeners();
  }

  void nextPage() {
    if (isLastPage) return;
    _currentPage++;
    notifyListeners();
  }
}
