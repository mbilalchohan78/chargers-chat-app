import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Initialize
  static Future<void> initialize() async {
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(settings);
    
    // Notification permission maango
    await _requestPermission();
    
    // FCM token lo
    await _getToken();
    
    // Message listeners lagao
    _setupMessageListeners();
  }
  
  // Permission maango
  static Future<void> _requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
    }
  }
  
  // FCM token lo (ye token bhejna hoga backend ko)
  static Future<void> _getToken() async {
    String? token = await _fcm.getToken();
    print('📱 FCM Token: $token');
    
    // TODO: Ye token apne backend ya Firestore mein save karo
    // FirebaseFirestore.instance.collection('users').doc(userId).update({
    //   'fcmToken': token,
    // });
  }
  
  // Message listeners setup
  static void _setupMessageListeners() {
    // Jab app foreground mein ho
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Message received in foreground: ${message.notification?.title}');
      _showLocalNotification(message);
    });
    
    // Jab app background mein ho but open ho
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 User tapped notification');
      _handleMessageTap(message);
    });
    
    // Jab app terminated ho aur notification tap kare
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('🚀 App opened from terminated state via notification');
        _handleMessageTap(message);
      }
    });
  }
  
  // Local notification dikhao
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      details,
    );
  }
  
  // Jab notification tap kare toh chat screen kholo
  static void _handleMessageTap(RemoteMessage message) {
    // TODO: Navigate to chat screen
    // Get the chat ID from message data and navigate
    print('Open chat: ${message.data}');
  }
}