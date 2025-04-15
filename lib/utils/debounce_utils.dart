import 'dart:async';
import 'package:flutter/foundation.dart';

/// 防抖和节流工具类
class DebounceTool {
  /// 存储防抖计时器的映射表
  static final Map<String, Timer> _debounceTimers = {};

  /// 存储节流状态的映射表
  static final Map<String, bool> _throttleFlags = {};

  /// 防抖函数
  ///
  /// [id]: 防抖操作的唯一标识
  /// [callback]: 需要执行的回调函数
  /// [milliseconds]: 延迟执行的毫秒数
  static void debounce(String id, VoidCallback callback,
      {int milliseconds = 500}) {
    // 取消该ID的现有计时器
    _debounceTimers[id]?.cancel();

    // 创建新的计时器
    _debounceTimers[id] = Timer(Duration(milliseconds: milliseconds), () {
      callback();
      _debounceTimers.remove(id);
    });
  }

  /// 节流函数
  ///
  /// [id]: 节流操作的唯一标识
  /// [callback]: 需要执行的回调函数
  /// [milliseconds]: 节流时间间隔（毫秒）
  static void throttle(String id, VoidCallback callback,
      {int milliseconds = 500}) {
    // 如果该ID正在节流中，则不执行
    if (_throttleFlags[id] == true) {
      return;
    }

    // 设置节流标志为true
    _throttleFlags[id] = true;

    // 执行回调
    callback();

    // 创建定时器，在指定时间后重置节流标志
    Timer(Duration(milliseconds: milliseconds), () {
      _throttleFlags[id] = false;
    });
  }

  /// 清除指定ID的防抖计时器
  static void clearDebounce(String id) {
    _debounceTimers[id]?.cancel();
    _debounceTimers.remove(id);
  }

  /// 清除所有防抖计时器
  static void clearAllDebounce() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }

  /// 清除指定ID的节流状态
  static void clearThrottle(String id) {
    _throttleFlags.remove(id);
  }

  /// 清除所有节流状态
  static void clearAllThrottle() {
    _throttleFlags.clear();
  }
}
