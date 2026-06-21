import 'package:flutter/foundation.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, dynamic> _cache = {};

  /// Guarda um valor em cache para uma determinada chave
  void set(String key, dynamic value) {
    _cache[key] = value;
    debugPrint('[CACHE] Dados guardados para a chave: $key');
  }

  /// Obtém um valor da cache
  dynamic get(String key) {
    final value = _cache[key];
    if (value != null) {
      debugPrint('[CACHE] Cache hit para a chave: $key');
    }
    return value;
  }

  /// Verifica se existe dados para uma chave
  bool has(String key) {
    return _cache.containsKey(key);
  }

  /// Remove uma chave específica da cache
  void invalidate(String key) {
    _cache.remove(key);
    debugPrint('[CACHE] Invalida cache para a chave: $key');
  }

  /// Limpa toda a cache (ex: no logout)
  void clear() {
    _cache.clear();
    debugPrint('[CACHE] Cache completamente limpa');
  }
}

final cacheService = CacheService();
