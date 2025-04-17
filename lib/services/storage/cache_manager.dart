import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 缓存管理器
/// 负责处理应用中的数据缓存，包括存储、检索、验证和刷新
class CacheManager {
  /// 默认缓存过期时间
  static const Duration defaultExpiration = Duration(minutes: 30);
  
  /// 最大重试次数
  static const int defaultMaxRetries = 3;
  
  /// SharedPreferences实例，用于本地数据存储
  final SharedPreferences _prefs;
  
  /// 构造函数
  /// @param _prefs SharedPreferences实例
  CacheManager(this._prefs);
  
  /// 获取有效的缓存数据
  /// @param key 缓存键名
  /// @param expiration 过期时间，默认为defaultExpiration
  /// @return 如果缓存有效，返回缓存的数据；否则返回null
  Map<String, dynamic>? getValidCache(String key, {Duration? expiration}) {
    try {
      final cachedString = _prefs.getString(key);
      if (cachedString != null) {
        final cached = json.decode(cachedString);
        final timestamp = cached['timestamp'] ?? 0;
        final expirationDuration = expiration ?? defaultExpiration;

        // 检查缓存是否过期
        if (DateTime.now().millisecondsSinceEpoch - timestamp <
            expirationDuration.inMilliseconds) {
          if (cached['data'] != null) {
            return cached['data']; // 直接返回原始响应数据
          }
        }
      }
    } catch (e) {
      print('读取缓存失败: $e');
    }
    return null;
  }
  
  /// 更新缓存
  /// @param key 缓存键名
  /// @param data 要缓存的数据，应包含'data'字段
  /// @return 更新缓存的Future
  Future<void> updateCache(String key, Map<String, dynamic> data) async {
    try {
      // 确保数据中包含时间戳
      if (!data.containsKey('timestamp')) {
        data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }

      final String jsonData = json.encode(data);
      await _prefs.setString(key, jsonData);
    } catch (e) {
      print('更新缓存失败: $e');
    }
  }
  
  /// 在后台刷新缓存
  /// @param key 缓存键名
  /// @param fetchData 获取新数据的函数
  /// @param maxRetries 最大重试次数，默认为defaultMaxRetries
  /// @return 刷新操作的Future
  Future<void> refreshInBackground(
      String key, 
      Future<dynamic> Function() fetchData, 
      {int maxRetries = defaultMaxRetries}) async {
    Future.delayed(Duration.zero, () async {
      int retryCount = 0;
      while (retryCount < maxRetries) {
        try {
          final result = await fetchData();
          if (result != null) {
            // 如果操作成功，退出循环
            print('后台刷新缓存成功: $key');
            break;
          }
          // 如果结果为null，增加重试次数
          retryCount++;
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) {
            print('后台刷新缓存失败 ($retryCount/$maxRetries): $e');
            break;
          }
          // 等待一段时间后重试，使用指数退避策略
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
    });
  }
  
  /// 检查缓存是否有效
  /// @param cache 缓存数据
  /// @param expiration 过期时间，默认为defaultExpiration
  /// @return 缓存是否有效
  bool isValid(Map<String, dynamic>? cache, {Duration? expiration}) {
    if (cache == null) return false;
    final timestamp = cache['timestamp'] ?? 0;
    final expirationDuration = expiration ?? defaultExpiration;
    return DateTime.now().millisecondsSinceEpoch - timestamp <
        expirationDuration.inMilliseconds;
  }
  
  /// 获取多个缓存的状态
  /// @param keys 要检查的缓存键名列表
  /// @return 包含每个缓存状态的Map
  Future<Map<String, dynamic>> getStatus(List<String> keys) async {
    final result = <String, dynamic>{};
    
    try {
      for (final key in keys) {
        final cacheStr = _prefs.getString(key);
        final cache = cacheStr != null ? json.decode(cacheStr) : null;
        
        result[key] = {
          'hasCache': cache != null,
          'timestamp': cache?['timestamp'],
          'isValid': isValid(cache),
        };
      }
    } catch (e) {
      print('获取缓存状态失败: $e');
    }
    
    return result;
  }
  
  /// 清除指定缓存
  /// @param key 要清除的缓存键名
  /// @return 清除操作的Future
  Future<void> clear(String key) async {
    await _prefs.remove(key);
  }
  
  /// 清除过期缓存
  /// @param keys 要检查的缓存键名列表
  /// @param expiration 过期时间，默认为defaultExpiration
  /// @return 清除操作的Future
  Future<void> clearExpired(List<String> keys, {Duration? expiration}) async {
    for (final key in keys) {
      final cacheStr = _prefs.getString(key);
      if (cacheStr != null) {
        try {
          final cache = json.decode(cacheStr);
          if (!isValid(cache, expiration: expiration)) {
            await clear(key);
          }
        } catch (e) {
          // 如果解析失败，也清除这个缓存
          await clear(key);
        }
      }
    }
  }
}
