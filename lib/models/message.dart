import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video }

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String? itemId;
  final String? itemTitle;
  final MessageType type;
  final String? mediaUrl;
  final String? thumbnailUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.isRead,
    this.itemId,
    this.itemTitle,
    this.type = MessageType.text,
    this.mediaUrl,
    this.thumbnailUrl,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    MessageType messageType = MessageType.text;
    if (data['type'] != null) {
      switch (data['type']) {
        case 'image':
          messageType = MessageType.image;
          break;
        case 'video':
          messageType = MessageType.video;
          break;
        default:
          messageType = MessageType.text;
      }
    }

    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      itemId: data['itemId'],
      itemTitle: data['itemTitle'],
      type: messageType,
      mediaUrl: data['mediaUrl'],
      thumbnailUrl: data['thumbnailUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'itemId': itemId,
      'itemTitle': itemTitle,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

class Conversation {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;
  final int unreadCount;
  final String? itemId;
  final String? itemTitle;
  final String? itemType;

  Conversation({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.unreadCount,
    this.itemId,
    this.itemTitle,
    this.itemType,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime:
          (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCount: data['unreadCount'] ?? 0,
      itemId: data['itemId'],
      itemTitle: data['itemTitle'],
      itemType: data['itemType'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'itemId': itemId,
      'itemTitle': itemTitle,
      'itemType': itemType,
    };
  }
}

class ConversationWithUser {
  final Conversation conversation;
  final String otherUserName;
  final String otherUserId;

  ConversationWithUser({
    required this.conversation,
    required this.otherUserName,
    required this.otherUserId,
  });
}

// Helper function for timestamp formatting
String formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return '';

  final DateTime dateTime = timestamp.toDate();
  final DateTime now = DateTime.now();
  final Duration difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inDays == 0) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}

// Helper function to get initials from name
String getInitials(String name) {
  if (name.isEmpty) return '?';
  final words = name.trim().split(' ');
  if (words.length == 1) {
    return words[0][0].toUpperCase();
  } else {
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
