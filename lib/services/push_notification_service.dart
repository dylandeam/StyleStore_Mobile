import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../config/routes.dart';
import 'api_service.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService.initializeFirebase();
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static final navigatorKey = GlobalKey<NavigatorState>();
  static const _channel = AndroidNotificationChannel(
    'stylestore_alerts',
    'Alertas de StyleStore',
    description: 'Compras, reservas, delivery, stock y novedades de tu tienda.',
    importance: Importance.high,
  );
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _firebaseReady = false;
  static bool _listenersReady = false;
  static bool _localReady = false;
  ApiService? _api;
  StorageService? _storage;

  static FirebaseOptions? _optionsFromEnvironment() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if ([apiKey, appId, senderId, projectId].any((value) => value.isEmpty)) {
      return null;
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: String.fromEnvironment(
        'FIREBASE_IOS_BUNDLE_ID',
        defaultValue: 'com.stylestore.stylestoreMobile',
      ),
    );
  }

  static Future<bool> initializeFirebase() async {
    if (_firebaseReady) return true;
    try {
      if (Firebase.apps.isEmpty) {
        final options = _optionsFromEnvironment();
        await Firebase.initializeApp(options: options);
      }
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      return true;
    } catch (error) {
      debugPrint('FCM no configurado todavía: $error');
      return false;
    }
  }

  Future<void> configure(ApiService api, StorageService storage) async {
    _api = api;
    _storage = storage;
    if (!_localReady) {
      try {
        const android = AndroidInitializationSettings('@mipmap/ic_launcher');
        const ios = DarwinInitializationSettings();
        await _localNotifications.initialize(
          settings: const InitializationSettings(android: android, iOS: ios),
          onDidReceiveNotificationResponse: (response) =>
              _openRoute(response.payload),
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
        _localReady = true;
      } catch (error) {
        // Desktop/widget tests do not register the native notification plugin.
        debugPrint('Notificaciones locales no disponibles: $error');
      }
    }

    if (!await initializeFirebase() || _listenersReady) return;
    _listenersReady = true;
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    FirebaseMessaging.instance.onRegistered.listen(_registerToken);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openMessage(initialMessage));
    }
  }

  Future<void> registerCurrentDevice() async {
    if (_api == null || _storage == null || !await initializeFirebase()) return;
    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;
    await FirebaseMessaging.instance.register();
  }

  Future<void> _registerToken(String token) async {
    final api = _api;
    final storage = _storage;
    if (api == null || storage == null || !await storage.hasToken()) return;
    var deviceId = await storage.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await storage.saveDeviceId(deviceId);
    }
    try {
      await api.post(
        ApiConfig.pushDevicesUrl,
        body: {
          'token': token,
          'platform': kIsWeb
              ? 'web'
              : Platform.isIOS
                  ? 'ios'
                  : 'android',
          'device_id': deviceId,
        },
      );
      await storage.savePushRegistration(token);
    } catch (error) {
      debugPrint('No se pudo registrar el token push: $error');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (_api == null || !await initializeFirebase()) return;
    try {
      final token = await _storage?.getPushRegistration();
      if (token != null && token.isNotEmpty) {
        await _api!.delete(ApiConfig.pushDevicesUrl, body: {'token': token});
      }
      await FirebaseMessaging.instance.unregister();
      await _storage?.clearPushRegistration();
    } catch (error) {
      debugPrint('No se pudo desregistrar el token push: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification?.title ?? 'StyleStore',
      body: notification?.body ?? message.data['message']?.toString(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'stylestore_alerts',
          'Alertas de StyleStore',
          channelDescription:
              'Compras, reservas, delivery, stock y novedades de tu tienda.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      payload: message.data['route']?.toString(),
    );
  }

  void _openMessage(RemoteMessage message) =>
      _openRoute(message.data['route']?.toString());

  void _openRoute(String? route) {
    if (route == null || route.isEmpty) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    if (route.contains('experiencia')) {
      navigator.pushNamed(AppRoutes.experience);
    } else if (route.contains('planes')) {
      navigator.pushNamed(AppRoutes.plans);
    } else if (route.contains('delivery')) {
      navigator.pushNamed(AppRoutes.catalog, arguments: 5);
    } else {
      navigator.pushNamed(AppRoutes.catalog);
    }
  }
}
