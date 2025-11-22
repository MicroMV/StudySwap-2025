import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // STEP 1: Check for active/pending transactions
      final activeTransactions = await _checkActiveTransactions(user.uid);

      if (activeTransactions.isNotEmpty) {
        _showActiveTransactionsDialog(activeTransactions);
        return;
      }

      // STEP 2: Show password confirmation dialog
      final password = await _showPasswordConfirmationDialog();
      if (password == null || password.isEmpty) return;

      // STEP 3: Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      // STEP 4: Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // STEP 5: Reject all incoming requests to user's items
      await _rejectIncomingRequests(user.uid);

      // STEP 6: Delete user data from Firestore
      await _deleteUserData(user.uid);

      // STEP 7: Delete Firebase Auth account
      await user.delete();

      // STEP 8: Navigate to login
      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.pop(context);

        String message = 'Failed to delete account';
        if (e.code == 'wrong-password') {
          message = 'Incorrect password';
        } else if (e.code == 'requires-recent-login') {
          message =
              'Please log out and log in again, then try deleting your account';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Check for active transactions that prevent deletion
  Future<List<Map<String, dynamic>>> _checkActiveTransactions(
    String userId,
  ) async {
    final activeTransactions = <Map<String, dynamic>>[];

    // Define COMPLETED statuses that should NOT block deletion
    final completedStatuses = [
      'completed',
      'accepted',
      'sold',
      'swapped',
      'rejected',
      'cancelled',
    ];

    // Check ALL transactions where this user is involved (as userId)
    final userTransactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in userTransactionsSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;

      // Block deletion ONLY if status is NOT in completed statuses
      if (status != null && !completedStatuses.contains(status)) {
        activeTransactions.add({
          'id': doc.id,
          'type': data['type'] ?? 'Unknown',
          'status': status,
          'itemTitle': data['itemTitle'] ?? 'Unknown Item',
          'role': 'requester',
        });
      }
    }

    // Check transactions where this user is the OTHER party (partnerId)
    final partnerTransactionsSnapshot = await _firestore
        .collection('transactions')
        .where('partnerId', isEqualTo: userId)
        .get();

    for (var doc in partnerTransactionsSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;

      // Block deletion ONLY if status is NOT in completed statuses
      if (status != null && !completedStatuses.contains(status)) {
        activeTransactions.add({
          'id': doc.id,
          'type': data['type'] ?? 'Unknown',
          'status': status,
          'itemTitle': data['itemTitle'] ?? 'Unknown Item',
          'role': 'provider',
        });
      }
    }

    // Check by otherUserId
    final otherUserTransactionsSnapshot = await _firestore
        .collection('transactions')
        .where('otherUserId', isEqualTo: userId)
        .get();

    for (var doc in otherUserTransactionsSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;

      // Block deletion ONLY if status is NOT in completed statuses
      if (status != null && !completedStatuses.contains(status)) {
        activeTransactions.add({
          'id': doc.id,
          'type': data['type'] ?? 'Unknown',
          'status': status,
          'itemTitle': data['itemTitle'] ?? 'Unknown Item',
          'role': 'other party',
        });
      }
    }

    // Check if user has items that are currently lent out or borrowed
    final itemsSnapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['lent', 'borrowed'])
        .get();

    for (var doc in itemsSnapshot.docs) {
      final data = doc.data();
      activeTransactions.add({
        'id': doc.id,
        'type': 'Item Status',
        'status': data['status'] ?? 'lent',
        'itemTitle': data['title'] ?? 'Unknown Item',
        'role': 'owner',
      });
    }

    return activeTransactions;
  }

  // Show dialog listing active transactions that prevent deletion
  void _showActiveTransactionsDialog(List<Map<String, dynamic>> transactions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You have active transactions that must be completed first.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please complete or reject these transactions before deleting your account.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show password confirmation dialog
  Future<String?> _showPasswordConfirmationDialog() async {
    final passwordController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is permanent and cannot be undone. All your data will be deleted.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Please enter your password to confirm:'),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your password'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, passwordController.text);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  // Reject all incoming requests to user's items
  Future<void> _rejectIncomingRequests(String userId) async {
    // Get all user's items
    final itemsSnapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();

    // For each item, find and reject pending transactions/requests
    for (var itemDoc in itemsSnapshot.docs) {
      final itemId = itemDoc.id;

      // Find all pending transactions for this item
      final transactionsSnapshot = await _firestore
          .collection('transactions')
          .where('itemId', isEqualTo: itemId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var transDoc in transactionsSnapshot.docs) {
        // Update transaction status to rejected
        batch.update(transDoc.reference, {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': 'Seller account deleted',
        });
      }
    }

    await batch.commit();
  }

  // Delete all user data from Firestore
  Future<void> _deleteUserData(String userId) async {
    final batch = _firestore.batch();

    // Delete user document
    batch.delete(_firestore.collection('users').doc(userId));

    // Delete user's items (only active ones, not lent)
    final itemsSnapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in itemsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's reviews given to others
    final reviewsSnapshot = await _firestore
        .collection('reviews')
        .where('reviewerId', isEqualTo: userId)
        .get();
    for (var doc in reviewsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete completed transactions only
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .get();
    for (var doc in transactionsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's conversations
    final conversationsSnapshot = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .get();
    for (var doc in conversationsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's favorites
    final favoritesSnapshot = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .get();
    for (var doc in favoritesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).iconTheme.color ?? Colors.black,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          const Text(
            'Appearance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Dark Mode Toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.2), width: 1),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              title: const Text(
                'Dark Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Toggle dark theme',
                style: TextStyle(fontSize: 14),
              ),
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Account Section
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Delete Account Option (your existing code)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              subtitle: const Text(
                'Permanently delete your account and data',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Colors.red,
                size: 24,
              ),
              onTap: _deleteAccount,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
