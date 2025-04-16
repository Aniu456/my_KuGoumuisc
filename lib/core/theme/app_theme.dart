import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  /// 定义应用的亮色主题
  static final ThemeData lightTheme = ThemeData(
    /// 使用 Material 3 设计规范
    useMaterial3: true,

    /// 设置亮度为亮色
    brightness: Brightness.light,

    /// 使用种子颜色创建颜色方案
    colorScheme: ColorScheme.fromSeed(
      /// 种子颜色为深紫色
      seedColor: Colors.deepPurple,

      /// 颜色方案的亮度为亮色
      brightness: Brightness.light,
    ),

    /// 添加特定组件的样式
    appBarTheme: const AppBarTheme(
      /// 导航栏阴影高度为 0，去除阴影
      elevation: 0,

      /// 导航栏标题居中显示
      centerTitle: true,
    ),

    /// 定义 Elevated Button 的主题
    elevatedButtonTheme: ElevatedButtonThemeData(
      /// 设置 Elevated Button 的样式
      style: ElevatedButton.styleFrom(
        /// 设置按钮内边距
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),

        /// 设置按钮形状为圆角矩形
        shape: RoundedRectangleBorder(
          /// 设置圆角半径为 8
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    /// 定义 Card 组件的主题
    cardTheme: CardTheme(
      /// 设置内容超出裁剪时的行为为抗锯齿
      clipBehavior: Clip.antiAlias,

      /// 设置 Card 的形状为圆角矩形
      shape: RoundedRectangleBorder(
        /// 设置圆角半径为 12
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  /// 定义应用的暗色主题
  static final ThemeData darkTheme = ThemeData(
    /// 使用 Material 3 设计规范
    useMaterial3: true,

    /// 设置亮度为暗色
    brightness: Brightness.dark,

    /// 使用种子颜色创建颜色方案
    colorScheme: ColorScheme.fromSeed(
      /// 种子颜色为深紫色
      seedColor: const Color.fromARGB(255, 41, 164, 195),

      /// 颜色方案的亮度为暗色
      brightness: Brightness.dark,
    ),

    /// 添加特定组件的样式
    appBarTheme: const AppBarTheme(
      /// 导航栏阴影高度为 0，去除阴影
      elevation: 0,

      /// 导航栏标题居中显示
      centerTitle: true,
    ),

    /// 定义 Elevated Button 的主题
    elevatedButtonTheme: ElevatedButtonThemeData(
      /// 设置 Elevated Button 的样式
      style: ElevatedButton.styleFrom(
        /// 设置按钮内边距
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),

        /// 设置按钮形状为圆角矩形
        shape: RoundedRectangleBorder(
          /// 设置圆角半径为 8
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    /// 定义 Card 组件的主题
    cardTheme: CardTheme(
      /// 设置内容超出裁剪时的行为为抗锯齿
      clipBehavior: Clip.antiAlias,

      /// 设置 Card 的形状为圆角矩形
      shape: RoundedRectangleBorder(
        /// 设置圆角半径为 12
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
