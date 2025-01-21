import 'package:flutter/material.dart';

class Responsive {
  // 屏幕尺寸断点
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;
  static const double desktopBreakpoint = 1440;

  // 基准尺寸
  static const double baseWidth = 375.0;
  static const double baseHeight = 812.0;

  // 设备类型判断
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  // 屏幕尺寸获取
  static Size getScreenSize(BuildContext context) =>
      MediaQuery.of(context).size;

  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // 获取动态尺寸（基于宽度）
  static double getDynamicWidth(BuildContext context, double value) {
    double screenWidth = getScreenWidth(context);
    return value * (screenWidth / baseWidth);
  }

  // 获取动态尺寸（基于高度）
  static double getDynamicHeight(BuildContext context, double value) {
    double screenHeight = getScreenHeight(context);
    return value * (screenHeight / baseHeight);
  }

  // 获取动态尺寸（保持宽高比）
  static double getDynamicSize(BuildContext context, double value) {
    double screenWidth = getScreenWidth(context);
    double screenHeight = getScreenHeight(context);
    double scale = (screenWidth / baseWidth + screenHeight / baseHeight) / 2;
    return value * scale;
  }

  // 获取响应式内边距
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.all(getDynamicSize(context, 16.0));
    } else if (isTablet(context)) {
      return EdgeInsets.all(getDynamicSize(context, 24.0));
    } else if (isDesktop(context)) {
      return EdgeInsets.all(getDynamicSize(context, 32.0));
    } else {
      return EdgeInsets.all(getDynamicSize(context, 40.0));
    }
  }

  // 获取响应式水平内边距
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.symmetric(horizontal: getDynamicSize(context, 16.0));
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(horizontal: getDynamicSize(context, 48.0));
    } else if (isDesktop(context)) {
      return EdgeInsets.symmetric(horizontal: getDynamicSize(context, 64.0));
    } else {
      return EdgeInsets.symmetric(horizontal: getDynamicSize(context, 96.0));
    }
  }

  // 获取响应式网格列数
  static int getResponsiveGridCount(BuildContext context) {
    if (isMobile(context)) {
      return 2;
    } else if (isTablet(context)) {
      return 4;
    } else if (isDesktop(context)) {
      return 6;
    } else {
      return 8;
    }
  }

  // 获取响应式字体大小
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    if (isMobile(context)) {
      return baseSize;
    } else if (isTablet(context)) {
      return baseSize * 1.1;
    } else if (isDesktop(context)) {
      return baseSize * 1.2;
    } else {
      return baseSize * 1.3;
    }
  }

  // 获取响应式图标大小
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    if (isMobile(context)) {
      return baseSize;
    } else if (isTablet(context)) {
      return baseSize * 1.2;
    } else if (isDesktop(context)) {
      return baseSize * 1.4;
    } else {
      return baseSize * 1.6;
    }
  }

  // 获取响应式圆角
  static double getResponsiveRadius(BuildContext context, double baseRadius) {
    if (isMobile(context)) {
      return baseRadius;
    } else if (isTablet(context)) {
      return baseRadius * 1.2;
    } else {
      return baseRadius * 1.5;
    }
  }

  // 响应式布局构建器
  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
    Widget? largeDesktop,
  }) {
    if (isLargeDesktop(context) && largeDesktop != null) {
      return largeDesktop;
    }
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  // 获取设备方向
  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;
}
