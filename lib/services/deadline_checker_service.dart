import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeadlineCheckerService {
  static final _firestore = FirebaseFirestore.instance;

  // Call this when app starts
  static Future<void> checkDeadlinesOnStartup() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    print('═══════════════════════════════════════');
    print('🚀 DEADLINE CHECKER STARTED');
    print('═══════════════════════════════════════');

    if (currentUser == null) {
      print('❌ No user logged in');
      return;
    }

    print('✅ Current User ID: ${currentUser.uid}');

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayKey = '${today.year}-${today.month}-${today.day}';

    print('📅 Today: $todayKey');
    print('⏰ Checking deadlines from: $todayStart');
    print('⏰ Checking deadlines to: $todayEnd');

    try {
      // Get SharedPreferences to track sent notifications
      final prefs = await SharedPreferences.getInstance();
      final notifiedToday =
          prefs.getStringList('deadline_notified_$todayKey') ?? [];
      print('📝 Already notified today: ${notifiedToday.length} items');

      // LENDER: Where current user is PROVIDER (lent items)
      print('\n🔍 Querying LENDER transactions...');
      final lenderTransactions = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .where('type', isEqualTo: 'borrow')
          .where('role', isEqualTo: 'provider')
          .where('status', isEqualTo: 'accepted')
          .get();

      print('📊 Found ${lenderTransactions.size} lender transactions');

      for (var doc in lenderTransactions.docs) {
        final transaction = doc.data();
        print('\n📦 Transaction ID: ${doc.id}');
        print('   Item: ${transaction['itemTitle']}');
        print('   Status: ${transaction['status']}');

        final deadline = (transaction['deadline'] as Timestamp?)?.toDate();
        print('   Deadline: $deadline');

        final notifKey = 'lender_${doc.id}';

        // Skip if already notified today
        if (notifiedToday.contains(notifKey)) {
          print('   ⏭️ SKIPPED: Already notified today');
          continue;
        }

        if (deadline == null) {
          print('   ⚠️ SKIPPED: No deadline set');
          continue;
        }

        // Include deadlines at exactly midnight
        if (!deadline.isBefore(todayStart) && deadline.isBefore(todayEnd)) {
          print('   ✅ MATCH! Creating notification...');

          await _firestore.collection('notifications').add({
            'userId': currentUser.uid,
            'title': '⏰ Borrow Deadline Today',
            'body':
                'Your item "${transaction['itemTitle']}" should be returned by ${transaction['otherUserName'] ?? 'borrower'} today',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'data': {
              'type': 'deadline_reminder',
              'itemId': transaction['itemId'],
              'itemTitle': transaction['itemTitle'],
              'role': 'lender',
              'conversationId': transaction['conversationId'],
            },
          });

          notifiedToday.add(notifKey);
          print('   🎉 Notification created successfully!');
        } else {
          print('   ⏭️ SKIPPED: Deadline not today');
        }
      }

      // BORROWER: Where current user is REQUESTER (borrowed items)
      print('\n🔍 Querying BORROWER transactions...');
      final borrowerTransactions = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUser.uid)
          .where('type', isEqualTo: 'borrow')
          .where('role', isEqualTo: 'requester')
          .where('status', isEqualTo: 'accepted')
          .get();

      print('📊 Found ${borrowerTransactions.size} borrower transactions');

      for (var doc in borrowerTransactions.docs) {
        final transaction = doc.data();
        print('\n📦 Transaction ID: ${doc.id}');
        print('   Item: ${transaction['itemTitle']}');
        print('   Status: ${transaction['status']}');

        final deadline = (transaction['deadline'] as Timestamp?)?.toDate();
        print('   Deadline: $deadline');

        final notifKey = 'borrower_${doc.id}';

        if (notifiedToday.contains(notifKey)) {
          print('   ⏭️ SKIPPED: Already notified today');
          continue;
        }

        if (deadline == null) {
          print('   ⚠️ SKIPPED: No deadline set');
          continue;
        }

        // Include deadlines at exactly midnight
        if (!deadline.isBefore(todayStart) && deadline.isBefore(todayEnd)) {
          print('   ✅ MATCH! Creating notification...');

          await _firestore.collection('notifications').add({
            'userId': currentUser.uid,
            'title': '⏰ Return Reminder',
            'body':
                'Please return "${transaction['itemTitle']}" to ${transaction['otherUserName'] ?? 'owner'} today',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'data': {
              'type': 'deadline_reminder',
              'itemId': transaction['itemId'],
              'itemTitle': transaction['itemTitle'],
              'role': 'borrower',
              'conversationId': transaction['conversationId'],
            },
          });

          notifiedToday.add(notifKey);
          print('   🎉 Notification created successfully!');
        } else {
          print('   ⏭️ SKIPPED: Deadline not today');
        }
      }

      // Save the updated notification list for today
      await prefs.setStringList('deadline_notified_$todayKey', notifiedToday);
      print('\n💾 Saved ${notifiedToday.length} notified items');

      // Clean up old days
      await _cleanupOldNotificationTracking(prefs, todayKey);

      print('\n═══════════════════════════════════════');
      print('✅ DEADLINE CHECKER COMPLETE');
      print('═══════════════════════════════════════\n');
    } catch (e, stackTrace) {
      print('❌ ERROR checking deadlines: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Clean up notification tracking from previous days
  static Future<void> _cleanupOldNotificationTracking(
    SharedPreferences prefs,
    String todayKey,
  ) async {
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('deadline_notified_') &&
          key != 'deadline_notified_$todayKey') {
        await prefs.remove(key);
        print('🧹 Cleaned up old notification tracking: $key');
      }
    }
  }
}
