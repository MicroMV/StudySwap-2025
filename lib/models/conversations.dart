import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCounts;
  final String? itemId;
  final String? itemTitle;
  final String? itemType;
  final DateTime? createdAt;

  Conversation({
    required this.id,
    required this.participants,
    required this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    required this.unreadCounts,
    this.itemId,
    this.itemTitle,
    this.itemType,
    this.createdAt,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle both old and new unread count formats
    Map<String, int> unreadCounts = {};
    if (data['unreadCounts'] != null) {
      final counts = data['unreadCounts'] as Map<String, dynamic>;
      counts.forEach((key, value) {
        unreadCounts[key] = (value as num).toInt();
      });
    } else if (data['unreadCount'] != null) {
      // Fallback for old format - distribute to all participants
      final participants = List<String>.from(data['participants']);
      final count = (data['unreadCount'] as num).toInt();
      for (String participant in participants) {
        unreadCounts[participant] = count;
      }
    }

    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastMessageTime']?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCounts: unreadCounts,
      itemId: data['itemId'],
      itemTitle: data['itemTitle'],
      itemType: data['itemType'],
      createdAt: data['createdAt']?.toDate(),
    );
  }

  // Get unread count for specific user
  int getUnreadCountForUser(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  // Get the other participant (not the current user)
  String? getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
      (participant) => participant != currentUserId,
      orElse: () => '',
    );
  }

  // Check if conversation has unread messages for user
  bool hasUnreadMessages(String userId) {
    return getUnreadCountForUser(userId) > 0;
  }
}
