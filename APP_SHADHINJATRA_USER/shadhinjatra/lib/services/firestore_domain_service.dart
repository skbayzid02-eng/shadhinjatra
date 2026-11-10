import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreDomainService {
  static String? _cachedBaseUrl;
  static String? _cachedStorageUrl;
  static String? _cachedFallbackUrl;
  static bool _isInitialized = false;

  static const String _prefBaseUrlKey = 'firestore_resolved_base_url';
  static const String _prefStorageUrlKey = 'firestore_resolved_storage_url';
  static const String _prefFallbackUrlKey = 'firestore_resolved_fallback_url';

  /// Default fallback URL when Firestore is offline or not yet initialized
  static String get defaultBaseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return 'http://$host:8000/api';
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) return 'http://192.168.0.7:8000/api';
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return 'http://192.168.0.7:8000/api';
      }
    } catch (_) {}
    return 'http://192.168.0.7:8000/api';
  }

  static String get baseUrl => _cachedBaseUrl ?? defaultBaseUrl;
  static String? get fallbackUrl => _cachedFallbackUrl;
  static String get storageUrl =>
      _cachedStorageUrl ?? baseUrl.replaceAll('/api', '/storage');
  static String get host => baseUrl.replaceAll('/api', '');

  /// List of candidate base URLs to attempt in order of priority.
  static List<String> get candidateUrls {
    final list = <String>[];

    // For Web browsers, prioritize same-origin host dynamically
    if (kIsWeb) {
      final currentBrowserHost = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final browserApiUrl = 'http://$currentBrowserHost:8000/api';
      list.add(browserApiUrl);
    }
    
    // 1. Current resolved base URL
    final current = baseUrl.trim();
    if (current.isNotEmpty && !list.contains(current)) list.add(current);

    // 2. Firestore-configured fallback URL if available
    final fb = _cachedFallbackUrl?.trim();
    if (fb != null && fb.isNotEmpty && !list.contains(fb)) {
      list.add(fb);
    }

    // 3. Platform-specific fallback candidates
    final platformFallbacks = kIsWeb
        ? const [
            'http://localhost:8000/api',
            'http://127.0.0.1:8000/api',
            'http://192.168.0.7:8000/api',
            'http://shadhinjatra.test/api',
          ]
        : const [
            'http://192.168.0.7:8000/api',
            'http://10.0.2.2:8000/api',
            'http://shadhinjatra.test/api',
            'http://127.0.0.1:8000/api',
          ];

    for (final url in platformFallbacks) {
      if (!list.contains(url)) {
        list.add(url);
      }
    }

    return list;
  }

  /// Dynamically updates the active baseUrl when an endpoint responds successfully.
  static void updateWorkingBaseUrl(String workingUrl) {
    if (workingUrl.trim().isEmpty) return;
    String normalized = workingUrl.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.endsWith('/api')) {
      normalized = '$normalized/api';
    }

    if (_cachedBaseUrl == normalized) return;

    _cachedBaseUrl = normalized;
    _cachedStorageUrl = normalized.replaceAll('/api', '/storage');

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefBaseUrlKey, normalized);
      prefs.setString(_prefStorageUrlKey, _cachedStorageUrl!);
    }).catchError((e) {
      debugPrint('FirestoreDomainService: failed saving working baseUrl: $e');
    });

    debugPrint('FirestoreDomainService: Active API endpoint set to: $normalized');
  }

  /// Fetches domain and API host configuration from Firebase Firestore
  /// ONLY at app startup time. Never invoked per HTTP request.
  static Future<void> initDomainConfig() async {
    if (_isInitialized) return;

    // 1. Immediately read cached domain from SharedPreferences for fast startup
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedBaseUrl = prefs.getString(_prefBaseUrlKey);
      _cachedStorageUrl = prefs.getString(_prefStorageUrlKey);
      _cachedFallbackUrl = prefs.getString(_prefFallbackUrlKey);
    } catch (e) {
      debugPrint('FirestoreDomainService: local cache read error: $e');
    }

    // 2. Fetch live domain config from Firebase Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('endpoints')
          .get()
          .timeout(const Duration(seconds: 4));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        String? resolvedUrl;

        // Platform-specific domain overrides from Firestore (Android, iOS, Web, Desktop)
        if (kIsWeb && data['web_url'] != null) {
          resolvedUrl = data['web_url'].toString().trim();
        } else if (!kIsWeb) {
          try {
            if (Platform.isAndroid && data['android_url'] != null) {
              resolvedUrl = data['android_url'].toString().trim();
            } else if (Platform.isIOS && data['ios_url'] != null) {
              resolvedUrl = data['ios_url'].toString().trim();
            } else if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
                data['desktop_url'] != null) {
              resolvedUrl = data['desktop_url'].toString().trim();
            }
          } catch (_) {}
        }

        // Direct live domain configured in Firestore
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          final liveCandidate = data['base_url']?.toString().trim() ??
              data['api_url']?.toString().trim() ??
              data['domain']?.toString().trim();
          if (liveCandidate != null && liveCandidate.isNotEmpty) {
            if (kIsWeb && (liveCandidate.contains('192.168.') || liveCandidate.contains('10.0.'))) {
              // On web, only prefer LAN IP if the current browser window is also accessing via LAN IP
              if (Uri.base.host.contains('192.168.') || Uri.base.host.contains('10.0.')) {
                resolvedUrl = liveCandidate;
              }
            } else {
              resolvedUrl = liveCandidate;
            }
          }
        }

        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          // Normalize URL: remove trailing slash and ensure /api endpoint
          if (resolvedUrl.endsWith('/')) {
            resolvedUrl = resolvedUrl.substring(0, resolvedUrl.length - 1);
          }
          if (!resolvedUrl.endsWith('/api')) {
            resolvedUrl = '$resolvedUrl/api';
          }
          _cachedBaseUrl = resolvedUrl;

          // Storage URL
          String? sUrl = data['storage_url']?.toString().trim();
          if (sUrl != null && sUrl.isNotEmpty) {
            if (sUrl.endsWith('/')) sUrl = sUrl.substring(0, sUrl.length - 1);
            _cachedStorageUrl = sUrl;
          } else {
            _cachedStorageUrl = _cachedBaseUrl!.replaceAll('/api', '/storage');
          }

          // Fallback URL
          String? fbUrl = data['fallback_url']?.toString().trim();
          if (fbUrl != null && fbUrl.isNotEmpty) {
            if (fbUrl.endsWith('/')) fbUrl = fbUrl.substring(0, fbUrl.length - 1);
            if (!fbUrl.endsWith('/api')) fbUrl = '$fbUrl/api';
            _cachedFallbackUrl = fbUrl;
          }

          // 3. Persist locally in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefBaseUrlKey, _cachedBaseUrl!);
          if (_cachedStorageUrl != null) {
            await prefs.setString(_prefStorageUrlKey, _cachedStorageUrl!);
          }
          if (_cachedFallbackUrl != null) {
            await prefs.setString(_prefFallbackUrlKey, _cachedFallbackUrl!);
          }

          debugPrint('FirestoreDomainService: Resolved API baseUrl from Firestore: $_cachedBaseUrl');
        }
      }
    } catch (e) {
      debugPrint('FirestoreDomainService: Firestore fetch notice: $e (using baseUrl: $baseUrl)');
    } finally {
      _isInitialized = true;
    }
  }

  /// Automatically normalizes relative image paths or outdated dev URLs with the active Firestore domain.
  static String fixUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();

    // Preserve external CDN / cloud storage URLs directly
    if (trimmed.startsWith('https://') &&
        !trimmed.contains('localhost') &&
        !trimmed.contains('127.0.0.1') &&
        !trimmed.contains('10.0.2.2')) {
      return trimmed;
    }

    final currentHost = host;

    // Cleanly replace old/hardcoded development hosts with the active Firestore host
    String normalized = trimmed
        .replaceAll('http://localhost:8000', currentHost)
        .replaceAll('http://127.0.0.1:8000', currentHost)
        .replaceAll('http://10.0.2.2:8000', currentHost)
        .replaceAll('http://192.168.0.7:8000', currentHost)
        .replaceAll('http://shadhinjatra.test', currentHost);

    // If relative path
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      if (normalized.startsWith('/')) {
        normalized = normalized.substring(1);
      }
      if (normalized.startsWith('storage/')) {
        return '$currentHost/$normalized';
      }
      return '$storageUrl/$normalized';
    }

    return normalized;
  }
}

