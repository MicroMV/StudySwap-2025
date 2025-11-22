import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'main_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 1,
        actions: [
          PopupMenuButton(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).iconTheme.color,
            ),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await NotificationService.clearAllNotifications();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  const Text('Error loading notifications'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.4),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You\'ll see notifications here when someone\ninteracts with your items or sends requests',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationItem(context, notification);
            },
          );
        },
      ),
    );
  }

  // Get other user info from conversation
  Future<Map<String, String>> _getOtherUserInfo(String conversationId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('No current user');

      // Get conversation data
      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) throw Exception('Conversation not found');

      final data = conversationDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);

      // Find the other user ID
      final otherUserId = participants.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) throw Exception('Other user not found');

      // Get other user's info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();

      final userData = userDoc.data() ?? <String, dynamic>{};

      return {
        'userId': otherUserId,
        'userName': userData['displayName'] ?? userData['name'] ?? 'User',
        'userSchool':
            userData['school'] ?? userData['university'] ?? 'University',
      };
    } catch (e) {
      print('❌ Error getting other user info: $e');
      return {'userId': '', 'userName': 'User', 'userSchool': 'University'};
    }
  }

  Widget _buildNotificationItem(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    final isRead = notification['isRead'] ?? false;
    final title = notification['title'] ?? 'Notification';
    final body = notification['body'] ?? '';
    final timestamp = notification['timestamp']?.toDate() as DateTime?;
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final type = data['type'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead
            ? Theme.of(context).cardColor
            : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead
              ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2))
              : Colors.blue.withOpacity(0.3),
        ),
      ),

      child: InkWell(
        onTap: () => _handleNotificationTap(context, notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon based on notification type
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getNotificationColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  _getNotificationIcon(type),
                  color: _getNotificationColor(type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],

                    // Show item info if available
                    if (data['itemTitle'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.withOpacity(
                                  0.2,
                                ) // Lighter in dark mode
                              : Colors.grey.withOpacity(
                                  0.1,
                                ), // Darker in light mode
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                data['itemTitle'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Show "Tap to view conversation" hint
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 12,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to view conversation',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> notification,
  ) async {
    // Mark as read immediately when tapped
    if (!(notification['isRead'] ?? false)) {
      await NotificationService.markNotificationAsRead(notification['id']);
    }

    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final conversationId = data['conversationId'] as String?;

    try {
      // If we have a conversation ID, navigate directly to that chat
      if (conversationId != null && conversationId.isNotEmpty) {
        await _navigateToSpecificChat(context, conversationId, data);
      } else {
        // Fallback: navigate to messages screen
        _navigateToMessages(context);
      }
    } catch (e) {
      print('❌ Error navigating from notification: $e');
      // Fallback: navigate to messages screen
      _navigateToMessages(context);
    }
  }

  // Navigate directly to specific chat
  Future<void> _navigateToSpecificChat(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get other user info from conversation
      final userInfo = await _getOtherUserInfo(conversationId);

      // Close loading
      Navigator.of(context).pop();

      if (userInfo['userId']?.isEmpty == true) {
        // Fallback if we can't find user info
        _navigateToMessages(context);
        return;
      }

      // Navigate directly to chat screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            otherUserId: userInfo['userId']!,
            otherUserName: userInfo['userName']!,
            otherUserSchool: userInfo['userSchool']!,
            itemTitle: data['itemTitle'],
            itemType: data['itemType'],
          ),
        ),
      );
    } catch (e) {
      // Close loading if still showing
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('❌ Error navigating to specific chat: $e');
      _navigateToMessages(context);
    }
  }

  // Navigate to messages screen (Main screen with messages tab)
  void _navigateToMessages(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainScreen(initialTabIndex: 3),
      ),
      (route) => false,
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'borrow_request':
        return Icons.library_books;
      case 'sell_request':
        return Icons.shopping_cart;
      case 'swap_request':
        return Icons.swap_horiz;
      case 'request_accepted':
        return Icons.check_circle;
      case 'request_rejected':
        return Icons.cancel;
      case 'deadline_reminder':
        return Icons.schedule;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'borrow_request':
        return Colors.blue;
      case 'sell_request':
        return Colors.orange;
      case 'swap_request':
        return const Color(0xFF4A90E2);
      case 'request_accepted':
        return Colors.green;
      case 'request_rejected':
        return Colors.red;
      case 'deadline_reminder':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }
}
