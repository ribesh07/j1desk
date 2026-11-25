import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'api.dart';
import 'env.dart';

/// Runs when a push arrives while the app is in the background / killed.
/// The system tray already shows `notification` messages, so nothing else is needed here.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging (push notifications).
///
/// How it works:
/// 1. Firebase is initialised with the client config from `.env` (no google-services.json needed).
/// 2. The device's FCM token is sent to the server: POST /api/devices { token, platform }.
/// 3. When a ticket changes (status update, assignment, comment, …) the server sends the push
///    to every user involved / the whole team, using the FCM HTTP v1 API (firebase-admin).
///    The service-account key stays on the server, never inside the app.
/// 4. In the foreground we show the message with flutter_local_notifications;
///    tapping any notification opens the ticket.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _token;

  /// Called with the ticket key (e.g. "ERP-001") when a notification is tapped.
  void Function(String ticketKey)? onOpenTicket;

  /// Called when any push arrives in the foreground (used to refresh the unread badge).
  VoidCallback? onMessage;

  static const _channel = AndroidNotificationChannel(
    'tickets',
    'Ticket updates',
    description: 'Assignments, status changes, comments and reminders',
    importance: Importance.high,
  );

  /// Names of the Firebase keys missing from `.env` for this platform (names only, never values).
  List<String> get _missingEnvKeys {
    final keys = <String, String>{
      'FIREBASE_PROJECT_ID': Env.firebaseProjectId,
      'FIREBASE_MESSAGING_SENDER_ID': Env.firebaseSenderId,
      if (Platform.isIOS) ...{
        'FIREBASE_IOS_APP_ID': Env.firebaseIosAppId,
        'FIREBASE_IOS_API_KEY': Env.firebaseIosApiKey,
      } else ...{
        'FIREBASE_ANDROID_APP_ID': Env.firebaseAndroidAppId,
        'FIREBASE_ANDROID_API_KEY': Env.firebaseAndroidApiKey,
      },
    };
    return [for (final e in keys.entries) if (e.value.isEmpty) e.key];
  }

  /// Push works on Android / iOS: from `.env`, or from firebase_options.dart as a fallback.
  bool get isConfigured => Platform.isAndroid || Platform.isIOS;

  bool get isReady => _ready;

  /// Firebase options: `.env` values when they are all set, otherwise the
  /// FlutterFire-generated `firebase_options.dart` (same Firebase project).
  FirebaseOptions get _options {
    final missing = _missingEnvKeys;
    if (missing.isNotEmpty) {
      debugPrint('[push] .env is missing ${missing.join(', ')} → using firebase_options.dart');
      return DefaultFirebaseOptions.currentPlatform;
    }
    debugPrint('[push] using Firebase config from .env');
    return FirebaseOptions(
      apiKey: Platform.isIOS ? Env.firebaseIosApiKey : Env.firebaseAndroidApiKey,
      appId: Platform.isIOS ? Env.firebaseIosAppId : Env.firebaseAndroidAppId,
      messagingSenderId: Env.firebaseSenderId,
      projectId: Env.firebaseProjectId,
      storageBucket: Env.firebaseStorageBucket.isEmpty ? null : Env.firebaseStorageBucket,
      iosBundleId: Platform.isIOS ? 'org.j1soft.tickets' : null,
    );
  }

  /// Call once from main(). Does nothing on unsupported platforms.
  Future<void> init() async {
    if (!isConfigured) {
      debugPrint('[push] push notifications are only available on Android / iOS');
      return;
    }
    try {
      await Firebase.initializeApp(options: _options);
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      // Local notifications: used to show pushes while the app is open.
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => _openFromData(_decode(r.payload)),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Foreground message → show it ourselves
      FirebaseMessaging.onMessage.listen(_showForeground);
      // Tap on a notification while the app was in the background
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _openFromData(m.data));
      // Keep the server in sync when FCM rotates the token.
      // We use FCM registration tokens (same as the web app); the server sends to them with
      // the HTTP v1 API. The newer FID register() API is not used yet, hence the ignores.
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        _sendToken(t);
      });
      _ready = true;
      debugPrint('[push] ready');
    } catch (e) {
      debugPrint('[push] init failed: $e');
    }
  }

  /// Opens the ticket if the app was launched by tapping a notification. Call after login.
  Future<void> handleLaunchMessage() async {
    if (!_ready) return;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _openFromData(initial.data);
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) _openFromData(_decode(launch!.notificationResponse?.payload));
  }

  /// Asks for permission, gets the FCM token and registers it for the signed-in user.
  Future<void> registerDevice() async {
    if (!_ready) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS) await FirebaseMessaging.instance.getAPNSToken();
      // ignore: deprecated_member_use
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await _sendToken(_token!);
      debugPrint('[push] permission: ${settings.authorizationStatus.name}, token ${_token == null ? 'missing' : 'registered'}');
    } catch (e) {
      debugPrint('[push] register failed: $e');
    }
  }

  /// Removes this device from the user's account (on logout).
  Future<void> unregisterDevice() async {
    if (!_ready || _token == null) return;
    try {
      await Api.removeDevice(_token!);
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }

  Future<void> _sendToken(String token) async {
    try {
      await Api.registerDevice(token, Platform.isIOS ? 'IOS' : 'ANDROID');
    } catch (e) {
      debugPrint('[push] could not register token: $e');
    }
  }

  void _showForeground(RemoteMessage m) {
    onMessage?.call();
    final title = m.notification?.title ?? m.data['title'];
    if (title == null) return;
    _local.show(
      id: m.hashCode & 0x7fffffff,
      title: title,
      body: m.notification?.body ?? m.data['body'],
      payload: jsonEncode(m.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF238636), // same accent as the FCM notifications
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Map<String, dynamic> _decode(String? payload) {
    if (payload == null || payload.isEmpty) return {};
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Push data contains `ticketKey` (and `link` like /tickets/ERP-001).
  void _openFromData(Map<String, dynamic> data) {
    final key = data['ticketKey']?.toString() ??
        RegExp(r'/tickets/([A-Z0-9]+-\d+)').firstMatch(data['link']?.toString() ?? '')?.group(1);
    if (key != null) onOpenTicket?.call(key);
  }
}
