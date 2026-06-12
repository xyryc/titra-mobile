import 'package:flutter/material.dart';

class NavigationService extends ChangeNotifier {
  String? _currentRouteName;
  String? get currentRouteName => _currentRouteName;

  void updateRouteName(String? name) {
    if (_currentRouteName == name) return;
    _currentRouteName = name;
    // Use a microtask to avoid "setState() or markNeedsBuild() called during build"
    // because RouteObservers can be triggered during the build phase of the Navigator.
    Future.microtask(() {
      notifyListeners();
    });
  }
}

class AppRouteObserver extends RouteObserver<ModalRoute<void>> {
  AppRouteObserver(this.navigationService);
  final NavigationService navigationService;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    navigationService.updateRouteName(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    navigationService.updateRouteName(previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    navigationService.updateRouteName(newRoute?.settings.name);
  }
}
