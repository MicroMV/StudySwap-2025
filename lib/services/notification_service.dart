import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firebase service account credentials
  static final Map<String, dynamic> _serviceAccountJson = {
    "type": "service_account",
    "project_id": "studyswap-e65a6",
    "private_key_id": "d4c1732280788a6b12a268d8bc7c0c4037786841",
    "private_key":
        "-----BEGIN PRIVATE KEY-----\nMIIEuwIBADANBgkqhkiG9w0BAQEFAASCBKUwggShAgEAAoIBAQCo0FY8ix0ZufwB\nPk/GDStklwAbbUjUKVq+vK1QLhqD9UHsgJO7ncP4++iN2uvLisr8Fhz+Dm2VFE6V\nWNXcm67Hcw5GVVsKCru/hBPT9PjNXQjmSi6ttPcirI8tPWXAImjgMn+LXjLAgpLv\nVS2vHrtV0QmuBNaD0pL3D22vEVjSLwlw0C5dq8q54pmXhvMapXN0CIhDiOkGgMwU\njp880by4aaj4TgLAwp/tRInpfwuWgwCxfywvUpatD7X9gkzqLZo9CJ+qipxQC/JB\nuv+oh4CzFLlOLI5GPa/JYubseN6eWT5G2OfIbH+EgZKqG4YDntteFOFsImvJgdCE\nKJlilxaxAgMBAAECggEACrti7hqodRMdLZ2O4AAElRKh8bxs+7rsz1Eqof0qV58D\nC8RhT/U/yQ+HuWP0Z1ZZoPTNb0vOxOJbfBRflTSrA/hBLTC+NslXpf1hLtGFMzYR\ny6Ul6kplxzUp7YX4luJBIVaog91PU+yBJ5i2TKqjHXmqeD8LvanoiK8ZCZ8MUuFK\nwkKSDVhAEZxS9vQemmfKiwJUT0CKcci+K0oDkfsdW7pcCNIDswEagmRLSs2CjBOw\n6tIrBIVPzuyY/BWs0RfMtyOB+n9CCNG/7Nv5dUuhf8I2o1WerDN5PUUgeKAu8sV3\nwOTo7luSayuAXFd3dV7sPF6aqbYb7t5uX7gksn1imQKBgQDrDI6/WEjSFgKzuPVh\nLhEMUHHNGmLqkPElj3WDw9chc1sOn+rv/nhtxl2tjZ6cryKIoxTiPJo+mr49CXfk\nx/f6Iu8N0WBDr9EtYXsVZBmKBC58Iw6Y5g23PnJXrLL6sbCDdu9WZNACZoTioKti\nbXoOP6pK34A1ukx2suZIBu4GGQKBgQC33GW6Yz9K9Az2czJ9OTrzacv35q673z3T\nLC9CSlLbrE0Bqwy0VVCrdWqpsS5kaCg5iTbM/0nLDsiGwmYx/BdsBC5oUcAtGmzB\nGxa4YYiHIVOKEhndRRTaxAOpXtbGeO0dn4HcVa+wPznE4kE/Cf8hHE5t4nJp+y+X\nRJDfLb24WQKBgHTy6pOJ+bGOAgoqHO0dXp4h6H2Eg3LyawmlN3M4HfIm00eTifGf\nS4xTBokzzZdoDGavvdRTEuvTUpRMAbtzQ47Rkt/tLViAQjOyLOuXwp1JN1fMmZa5\n4FksWPgGlYbmokzHAI6b2mNXXwbjqmJu1iwAwVo/mishZqoomSt9RzEBAn83TRNL\n/I4M/Vroxb1p7MzOagPvjHMCDyOJYMDWL4S8jhabaddoZkDdUXPDloddq/ZtV9gj\n0KVhbhDid5ZFco2Y76kFt5EV/9y2OG+dBbkK6/s0jD07UIv1QP/Y8a2oBLdNMazd\nmOg/GsVFcsgtLdSPIPR2GKZROjwWQ4lPl3J5AoGBAIaqfiEm7nCtElFV6mlvvwFe\nAADGNhv8r3CHmo3yBEDDQbdtYll7I1Yzt5vL5VYGBvQKQA9hTnCN3RluNsF/R4x+\nBxMkmtA4mGPKpSk2s51DCz3djXWWvOdkU6gJX0otSwmpsH5d8DFjv6gOYXvDFCfg\najPIPi8/h+u2rttUbPFx\n-----END PRIVATE KEY-----\n",
    "client_email":
        "firebase-adminsdk-fbsvc@studyswap-e65a6.iam.gserviceaccount.com",
    "client_id": "116358576334711540543",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url":
        "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40studyswap-e65a6.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com",
  };

  static Future<void> initializeLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'studyswap_channel',
      'StudySwap Notifications',
      channelDescription: 'Reminders and alerts for StudySwap',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, details);
  }

  static Future<void> initialize() async {
    print('🚀 Initializing NotificationService...');

    try {
      await _requestPermissions();
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      print('✅ NotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotificationService: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permissions');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️ User granted provisional notification permissions');
    } else {
      print('❌ User declined or has not accepted notification permissions');
    }
  }

  static Future<void> updateFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping FCM token update');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token updated: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      print('❌ Error updating FCM token: $e');
    }
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('📱 Background message: ${message.messageId}');
    print('📱 Background message data: ${message.data}');
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Foreground message: ${message.messageId}');
    print('📱 Title: ${message.notification?.title}');
    print('📱 Body: ${message.notification?.body}');
  }

  static void _handleNotificationTap(RemoteMessage message) {
    print('📱 Notification tapped: ${message.data}');
    final type = message.data['type'];
    switch (type) {
      case 'borrow_request':
      case 'request_accepted':
      case 'request_rejected':
        print('📱 Navigate to messages for type: $type');
        break;
      case 'deadline_reminder':
        print('📱 Navigate to borrowed items for deadline reminder');
        break;
      default:
        print('📱 Unknown notification type: $type');
    }
  }

  // Get OAuth2 access token for FCM V1 API
  static Future<String> _getAccessToken() async {
    try {
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(
        _serviceAccountJson,
      );
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      final authClient = await auth.clientViaServiceAccount(
        accountCredentials,
        scopes,
      );
      final accessToken = authClient.credentials.accessToken.data;
      authClient.close();

      return accessToken;
    } catch (e) {
      print('❌ Error getting access token: $e');
      rethrow;
    }
  }

  // Send FCM V1 push notification
  static Future<void> _sendFCMPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ No FCM token found for user $userId');
        return;
      }

      print('📤 Sending FCM V1 push to user: $userId');

      final accessToken = await _getAccessToken();

      final response = await http.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/studyswap-e65a6/messages:send',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': title, 'body': body},
            'data':
                data?.map((key, value) => MapEntry(key, value.toString())) ??
                {},
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'studyswap_channel',
                'sound': 'default',
              },
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM V1 push sent successfully to $userId');
        print('📱 Response: ${response.body}');
      } else {
        print('❌ Failed to send FCM V1: ${response.statusCode}');
        print('❌ Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending FCM V1 push: $e');
    }
  }

  static Future<void> sendBorrowRequestNotification({
    required String receiverUserId,
    required String itemTitle,
    required String requesterName,
    String? conversationId,
  }) async {
    await sendNotificationToUser(
      userId: receiverUserId,
      title: 'New Borrow Request',
      body: '$requesterName wants to borrow "$itemTitle"',
      data: {
        'type': 'borrow_request',
        'itemTitle': itemTitle,
        'requesterName': requesterName,
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> sendRequestAcceptedNotification({
    required String receiverUserId,
    required String itemTitle,
    required String accepterName,
    required String itemType,
    required String conversationId,
    DateTime? deadline,
    double? amount,
  }) async {
    try {
      String notificationBody =
          '$accepterName accepted your $itemType request for $itemTitle';

      if (amount != null) {
        notificationBody += ' for ₱${amount.toStringAsFixed(2)}';
      }

      if (deadline != null) {
        final deadlineStr = DateFormat('MMM d, yyyy').format(deadline);
        notificationBody += '. Return by $deadlineStr';
      }

      await _firestore.collection('notifications').add({
        'userId': receiverUserId,
        'title': 'Request Accepted!',
        'body': notificationBody,
        'type': 'request_accepted',
        'data': {
          'type': 'request_accepted',
          'itemTitle': itemTitle,
          'itemType': itemType,
          'conversationId': conversationId,
          'accepterName': accepterName,
          if (amount != null) 'amount': amount,
          if (deadline != null) 'deadline': deadline.toIso8601String(),
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await _sendFCMPushNotification(
        userId: receiverUserId,
        title: 'Request Accepted!',
        body: notificationBody,
        data: {
          'type': 'request_accepted',
          'itemTitle': itemTitle,
          'itemType': itemType,
          'conversationId': conversationId,
        },
      );

      print('✅ Acceptance notification saved for user $receiverUserId');
    } catch (e) {
      print('❌ Error sending acceptance notification: $e');
    }
  }

  static Future<void> sendRequestRejectedNotification({
    required String receiverUserId,
    required String itemTitle,
    required String rejecterName,
    required String itemType,
    String? conversationId,
  }) async {
    await sendNotificationToUser(
      userId: receiverUserId,
      title: 'Request Declined',
      body:
          '$rejecterName declined your ${itemType.toLowerCase()} request for "$itemTitle"',
      data: {
        'type': 'request_rejected',
        'itemTitle': itemTitle,
        'itemType': itemType,
        'rejecterName': rejecterName,
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> sendDeadlineReminderNotification({
    required String receiverUserId,
    required String itemTitle,
    required DateTime deadline,
    required int daysLeft,
  }) async {
    String title;
    String body;

    if (daysLeft <= 0) {
      title = 'Return Overdue! ⚠️';
      body =
          '"$itemTitle" was due for return. Please return it as soon as possible.';
    } else if (daysLeft == 1) {
      title = 'Return Due Tomorrow! ⏰';
      body = '"$itemTitle" is due for return tomorrow.';
    } else {
      title = 'Return Reminder';
      body = '"$itemTitle" is due for return in $daysLeft days.';
    }

    await sendNotificationToUser(
      userId: receiverUserId,
      title: title,
      body: body,
      data: {
        'type': 'deadline_reminder',
        'itemTitle': itemTitle,
        'deadline': deadline.millisecondsSinceEpoch.toString(),
        'daysLeft': daysLeft.toString(),
      },
    );
  }

  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Notification saved to Firestore for user $userId - $title');

      await _sendFCMPushNotification(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  static Future<void> scheduleDeadlineReminders({
    required String borrowerUserId,
    required String itemTitle,
    required DateTime deadline,
  }) async {
    try {
      final now = DateTime.now();
      final reminderDates = [
        deadline.subtract(const Duration(days: 3)),
        deadline.subtract(const Duration(days: 1)),
        deadline,
      ];

      for (final reminderDate in reminderDates) {
        if (reminderDate.isAfter(now)) {
          final daysLeft = deadline.difference(reminderDate).inDays;

          await _firestore.collection('scheduled_reminders').add({
            'userId': borrowerUserId,
            'itemTitle': itemTitle,
            'deadline': Timestamp.fromDate(deadline),
            'reminderDate': Timestamp.fromDate(reminderDate),
            'daysLeft': daysLeft,
            'sent': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      print(
        '✅ Scheduled ${reminderDates.length} deadline reminders for "$itemTitle"',
      );
    } catch (e) {
      print('❌ Error scheduling deadline reminders: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> getUserNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ Notification marked as read: $notificationId');
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  static Stream<int> getUnreadNotificationCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Future<void> sendSellRequestNotification({
    required String receiverUserId,
    required String itemTitle,
    required String requesterName,
    String? conversationId,
  }) async {
    await sendNotificationToUser(
      userId: receiverUserId,
      title: 'New Buy Request',
      body: '$requesterName wants to buy "$itemTitle"',
      data: {
        'type': 'sell_request',
        'itemTitle': itemTitle,
        'requesterName': requesterName,
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> sendSwapRequestNotification({
    required String receiverUserId,
    required String itemTitle,
    required String requesterName,
    String? conversationId,
  }) async {
    await sendNotificationToUser(
      userId: receiverUserId,
      title: 'New Swap Request',
      body: '$requesterName wants to trade for "$itemTitle"',
      data: {
        'type': 'swap_request',
        'itemTitle': itemTitle,
        'requesterName': requesterName,
        'conversationId': conversationId,
      },
    );
  }

  static Future<void> clearAllNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }
}
