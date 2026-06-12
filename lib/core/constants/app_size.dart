import 'package:flutter/cupertino.dart';

class AppSize {

  static late MediaQueryData _mediaQuery;
  static late double width;
  static late double height;
  static late double statusBar;
  static late double bottomBar;
  static late double textScale;

  static void init(BuildContext context){
    _mediaQuery = MediaQuery.of(context);

    width = _mediaQuery.size.width;
    height  = _mediaQuery.size.height;

    statusBar = _mediaQuery.padding.top;
    bottomBar = _mediaQuery.padding.bottom;

    textScale = _mediaQuery.textScaler.scale(1.0);
  }
}