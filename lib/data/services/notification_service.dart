import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/routes.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../core/services/api_service.dart';
import '../../core/services/token_storage.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  if (message.notification != null) {
    print(
        '[NotificationService] background message received: ${message.notification?.title} - ${message.notification?.body}');
  }
}

class NotificationService {
  NotificationService._();
  static bool _initialized = false;

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'jobmatch_channel',
    'JobMatch Notificaciones',
    description: 'Notificaciones de JobMatch',
    importance: Importance.high,
  );

  static Future<bool> _isPushEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('jm_push_notif') ?? true;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('[NotificationService] Firebase.initializeApp error: $e');
    }

    await _requestPermission();
    await _configureLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onMessageReceived);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _messaging.onTokenRefresh.listen((token) {
      registerToken(token: token);
    });

    _initialized = true;
    if (await _isPushEnabled()) {
      await registerToken();
    } else {
      await unregisterToken();
    }
  }

  static Future<void> registerToken({String? token}) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (!await _isPushEnabled()) {
        print(
            '[NotificationService] Push notifications deshabilitadas, no se registra token.');
        return;
      }

      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        print('[NotificationService] No se obtuvo token FCM');
        return;
      }

      final tieneSesion = await TokenStorage.instance.tieneToken();
      if (!tieneSesion) {
        print(
            '[NotificationService] Usuario no autenticado, token FCM no registrado en backend');
        return;
      }

      await ApiService.instance.put(
        ApiConstants.updateFcmToken,
        {'fcm_token': fcmToken},
      );
      print('[NotificationService] Token FCM enviado al backend');
    } catch (e) {
      print('[NotificationService] registerToken error: $e');
    }
  }

  static Future<void> unregisterToken() async {
    try {
      final tieneSesion = await TokenStorage.instance.tieneToken();
      if (!tieneSesion) {
        print(
            '[NotificationService] No hay sesión activa para limpiar token FCM');
        return;
      }

      await ApiService.instance.put(
        ApiConstants.updateFcmToken,
        {'fcm_token': ''},
      );
      print('[NotificationService] Token FCM eliminado en el backend');
    } catch (e) {
      print('[NotificationService] unregisterToken error: $e');
    }
  }

  static Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      print('[NotificationService] requestPermission error: $e');
    }
  }

  static Future<void> _configureLocalNotifications() async {
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          print('[NotificationService] local notification tapped: ${response.payload}');
          final context = AppRouter.navigatorKey.currentContext;
          if (context == null) return;
          try {
            final data = response.payload != null
                ? jsonDecode(response.payload!) as Map<String, dynamic>
                : <String, dynamic>{};
            final tipo = data['tipo'] as String? ?? '';
            switch (tipo) {
              case 'match':
              case 'postulacion_estado':
                context.go(AppRoutes.studentApplications);
              case 'like_recibido':
                context.go(AppRoutes.companyCandidates);
              default:
                context.go(AppRoutes.notificaciones);
            }
          } catch (_) {
            context.go(AppRoutes.notificaciones);
          }
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    } catch (e) {
      print('[NotificationService] configureLocalNotifications error: $e');
    }
  }

  static void _onMessageReceived(RemoteMessage message) {
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _handleNotificationTap(message);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformDetails,
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );
    } catch (e) {
      print('[NotificationService] showLocalNotification error: $e');
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    print('[NotificationService] notification opened: ${message.data}');
    final tipo = message.data['tipo'] as String? ?? '';
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return;

    switch (tipo) {
      case 'match':
      case 'postulacion_estado':
        context.go(AppRoutes.studentApplications);
      case 'like_recibido':
        context.go(AppRoutes.companyCandidates);
      default:
        context.go(AppRoutes.notificaciones);
    }
  }
}
