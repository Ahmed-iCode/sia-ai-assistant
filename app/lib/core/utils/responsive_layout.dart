import 'package:flutter/material.dart';

class ResponsiveLayout {
  ResponsiveLayout._();

  static const double mobileBreakpoint = 850.0;
  static const double tabletBreakpoint = 1100.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    required Widget desktop,
  }) {
    return isDesktop(context) ? desktop : mobile;
  }
}
