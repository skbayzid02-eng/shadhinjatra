import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shadhinjatradriver/services/auth_service.dart';

class DriverBackgroundService with WidgetsBindingObserver {
  DriverBackgroundService._internal();
  static final DriverBackgroundService instance = DriverBackgroundService._internal();

  bool _isInitialized = false;
  bool _isRunning = false;
  bool _isOnline = false;
  bool _isInBackground = false;
  bool _isScreenLocked = false;
  bool _isConnectionLost = false;
  bool _isGpsEnabled = true;
  bool _isLocationPermissionGranted = true;

  Position? _lastPosition;
  Timer? _heartbeatTimer;
  StreamSubscription<Position>? _positionSubscription;

  final Set<int> _alertedRideIds = {};

  // Listeners / Callbacks for UI components
  final List<VoidCallback> _listeners = [];
  Function(Map<String, dynamic>)? onNewRideAlert;
  Function(bool isLost)? onConnectionStatusChanged;
  Function(bool isOnline)? onOnlineStatusChanged;

  // Getters
  bool get isRunning => _isRunning;
  bool get isOnline => _isOnline;
  bool get isInBackground => _isInBackground;
  bool get isScreenLocked => _isScreenLocked;
  bool get isConnectionLost => _isConnectionLost;
  bool get isGpsEnabled => _isGpsEnabled;
  bool get isLocationPermissionGranted => _isLocationPermissionGranted;
  Position? get lastPosition => _lastPosition;

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error in background service listener: $e');
      }
    }
  }

  /// Initialize lifecycle observer and setup base listeners
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    debugPrint('DriverBackgroundService initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _isInBackground = true;
      _isScreenLocked = (state == AppLifecycleState.paused);
      debugPrint('Driver App went to BACKGROUND / Screen Locked. State: $state');
      if (_isOnline) {
        _sendHeartbeatImmediate();
      }
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      _isScreenLocked = false;
      debugPrint('Driver App RESUMED to FOREGROUND');
      if (_isOnline) {
        _sendHeartbeatImmediate();
      }
    }
    _notifyListeners();
  }

  /// Start background tracking service with Android Foreground Service & WakeLock
  Future<bool> startTracking({required bool isOnline}) async {
    initialize();
    _isOnline = isOnline;

    // 1. Verify Location Permissions
    final permOk = await checkPermissionsAndGps();
    if (!permOk) {
      _notifyListeners();
      return false;
    }

    _isRunning = true;
    _alertedRideIds.clear();

    // 2. Start Foreground Location Stream with active language
    final lang = await AuthService.getLanguage();
    await _startLocationStream(languageCode: lang);

    // 3. Start Periodic Background Heartbeat (every 12 seconds)
    _startHeartbeatTimer();

    // 4. Initial immediate ping
    await _sendHeartbeatImmediate();

    _notifyListeners();
    return true;
  }

  /// Stop background tracking service
  Future<void> stopTracking({String reason = 'manual_offline'}) async {
    _isRunning = false;
    _isOnline = false;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    try {
      await AuthService.setDriverOfflineGracefully(reason: reason);
    } catch (_) {}

    _notifyListeners();
  }

  /// Verify GPS and Location Permissions
  Future<bool> checkPermissionsAndGps() async {
    try {
      _isGpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isGpsEnabled) {
        debugPrint('GPS / Location Service is disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      _isLocationPermissionGranted = (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse);

      return _isLocationPermissionGranted;
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  /// Start Geolocator position stream with Android Foreground Notification & WakeLock
  /// Dynamically pulls title & text for the currently selected language (12 supported languages)
  Future<void> _startLocationStream({String? languageCode}) async {
    await _positionSubscription?.cancel();

    try {
      final lang = languageCode ?? await AuthService.getLanguage();
      final title = _DriverNotificationStrings.get(lang, 'title');
      final text = _DriverNotificationStrings.get(lang, 'text');

      // Android Settings configured for background survival with localized notification
      LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 10),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: title,
            notificationText: text,
            enableWakeLock: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        );
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _lastPosition = position;
          _isGpsEnabled = true;
          _isLocationPermissionGranted = true;
          _notifyListeners();
        },
        onError: (err) {
          debugPrint('Background location stream error: $err');
          _isLocationPermissionGranted = false;
          _notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Failed to start position stream: $e');
    }
  }

  /// Dynamically update Foreground Notification title & text when driver changes language
  Future<void> updateNotificationLanguage(String languageCode) async {
    if (!_isRunning) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _startLocationStream(languageCode: languageCode);
      }
    } catch (e) {
      debugPrint('Error updating notification language: $e');
    }
  }

  /// Setup Periodic Heartbeat
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (_isRunning && _isOnline) {
        _sendHeartbeatImmediate();
      }
    });
  }

  /// Immediate Heartbeat Dispatcher
  Future<void> _sendHeartbeatImmediate() async {
    if (!_isRunning) return;

    // Check GPS
    final isGpsOk = await Geolocator.isLocationServiceEnabled();
    _isGpsEnabled = isGpsOk;

    try {
      final res = await AuthService.sendBackgroundHeartbeat(
        lat: _lastPosition?.latitude,
        lng: _lastPosition?.longitude,
        heading: _lastPosition?.heading,
        speed: _lastPosition?.speed,
        accuracy: _lastPosition?.accuracy,
        isBackground: _isInBackground,
        isScreenLocked: _isScreenLocked,
        gpsEnabled: _isGpsEnabled,
        locationPermissionGranted: _isLocationPermissionGranted,
        hasInternet: true,
      );

      if (res['is_connection_error'] == true) {
        _setConnectionStatus(true);
        return;
      }

      _setConnectionStatus(false);

      if (res['success'] == true) {
        final serverIsOnline = res['is_online'] == true;
        if (!serverIsOnline && _isOnline) {
          _isOnline = false;
          onOnlineStatusChanged?.call(false);
        }

        // Check for new incoming ride alert
        if (res['new_ride_alert'] != null) {
          final alert = Map<String, dynamic>.from(res['new_ride_alert']);
          final rideId = (alert['ride_id'] as num?)?.toInt() ?? 0;
          if (rideId > 0 && !_alertedRideIds.contains(rideId)) {
            _alertedRideIds.add(rideId);
            _playRideAlertSoundAndVibration();
            onNewRideAlert?.call(alert);
          }
        }
      }
    } catch (e) {
      debugPrint('Background heartbeat exception: $e');
      _setConnectionStatus(true);
    }

    _notifyListeners();
  }

  void _setConnectionStatus(bool isLost) {
    if (_isConnectionLost != isLost) {
      _isConnectionLost = isLost;
      onConnectionStatusChanged?.call(isLost);
      _notifyListeners();
    }
  }

  /// Play audible alert and heavy vibration for new incoming ride request
  void _playRideAlertSoundAndVibration() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    // Repeat pulses for emergency attention
    Future.delayed(const Duration(milliseconds: 300), () {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    });

    Future.delayed(const Duration(milliseconds: 650), () {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _positionSubscription?.cancel();
    _listeners.clear();
    _isInitialized = false;
  }
}

/// 12 Supported Languages Translations for Background Foreground Notification & Alerts
class _DriverNotificationStrings {
  static const Map<String, Map<String, String>> translations = {
    'en': {
      'title': 'Shadhin Jatra Driver Live Tracking',
      'text': 'You are online - Background location active',
      'conn_lost': 'Internet connection lost: Reconnecting...',
      'new_ride_alert': 'New ride request available!',
    },
    'bn': {
      'title': 'স্বাধীনযাত্রা ড্রাইভার লাইভ ট্র্যাকিং',
      'text': 'আপনি অনলাইনে আছেন - ব্যাকগ্রাউন্ড লোকেশন সক্রিয়',
      'conn_lost': 'ইন্টারনেট সংযোগ বিচ্ছিন্ন: পুনরায় সংযোগ করা হচ্ছে...',
      'new_ride_alert': 'নতুন রাইডের অনুরোধ এসেছে!',
    },
    'ar': {
      'title': 'تتبع مباشر لسائق شادهين جاترا',
      'text': 'أنت متصل بالإنترنت - تتبع الموقع في الخلفية نشط',
      'conn_lost': 'انقطع الاتصال بالإنترنت: جارٍ إعادة الاتصال...',
      'new_ride_alert': 'طلب مشوار جديد متاح!',
    },
    'hi': {
      'title': 'स्वाधीन यात्रा ड्राइवर लाइव ट्रैकिंग',
      'text': 'आप ऑनलाइन हैं - बैकग्राउंड लोकेशन सक्रिय है',
      'conn_lost': 'इंटरनेट कनेक्शन कट गया: पुनः कनेक्ट हो रहा है...',
      'new_ride_alert': 'नई राइड का अनुरोध आया है!',
    },
    'es': {
      'title': 'Seguimiento en Vivo Conductor Shadhin Jatra',
      'text': 'Estás en línea - Ubicación en segundo plano activa',
      'conn_lost': 'Conexión a internet perdida: Reconectando...',
      'new_ride_alert': '¡Nueva solicitud de viaje disponible!',
    },
    'fr': {
      'title': 'Suivi en Direct Chauffeur Shadhin Jatra',
      'text': 'Vous êtes en ligne - Localisation en arrière-plan active',
      'conn_lost': 'Connexion Internet perdue: Reconnexion en cours...',
      'new_ride_alert': 'Nouvelle demande de course disponible !',
    },
    'zh': {
      'title': 'Shadhin Jatra 司机实时追踪',
      'text': '您已上线 - 后台定位已启用',
      'conn_lost': '网络连接断开：正在重新连接...',
      'new_ride_alert': '有新的行程请求！',
    },
    'pt': {
      'title': 'Rastreamento ao Vivo Motorista Shadhin Jatra',
      'text': 'Você está online - Localização em segundo plano ativa',
      'conn_lost': 'Conexão de internet perdida: Reconectando...',
      'new_ride_alert': 'Novo pedido de corrida disponível!',
    },
    'ru': {
      'title': 'Прямое отслеживание водителя Shadhin Jatra',
      'text': 'Вы в сети - Фоновая геолокация активна',
      'conn_lost': 'Потеряно подключение к Интернету: Повторное подключение...',
      'new_ride_alert': 'Доступен новый заказ поездки!',
    },
    'id': {
      'title': 'Pelacakan Langsung Pengemudi Shadhin Jatra',
      'text': 'Anda online - Lokasi latar belakang aktif',
      'conn_lost': 'Koneksi internet terputus: Menyambung ulang...',
      'new_ride_alert': 'Permintaan perjalanan baru tersedia!',
    },
    'tr': {
      'title': 'Shadhin Jatra Sürücü Canlı Takip',
      'text': 'Çevrimiçisiniz - Arka plan konumu aktif',
      'conn_lost': 'İnternet bağlantısı kesildi: Yeniden bağlanıyor...',
      'new_ride_alert': 'Yeni yolculuk talebi mevcut!',
    },
    'de': {
      'title': 'Shadhin Jatra Fahrer Live-Tracking',
      'text': 'Sie sind online - Hintergrund-Standort aktiv',
      'conn_lost': 'Internetverbindung verloren: Wiederverbindung...',
      'new_ride_alert': 'Neue Fahrtanfrage verfügbar!',
    },
  };

  static String get(String langCode, String key) {
    return translations[langCode]?[key] ?? translations['en']?[key] ?? '';
  }
}
