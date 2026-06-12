import 'package:flutter/material.dart';

/// Global route observer for pausing/resuming in full-screen routes (e.g. story viewer).
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
