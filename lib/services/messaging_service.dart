import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message.dart';

class MessagingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUserId => _auth.currentUser?.uid;

  static String _generateConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'conv_${sortedIds[0]}_${sortedIds[1]}';
  }

  static Future<String> createOrGetConversation(
    String userId1,
    String userId2,
  ) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    final conversationId = _generateConversationId(userId1, userId2);

    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    final conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      final conversationData = {
        'participants': [userId1, userId2]..sort(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageSenderId': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': {userId1: 0, userId2: 0},
        'discussedItems': [],
        'itemHistory': [],
      };

      await conversationRef.set(conversationData);
    }

    return conversationId;
  }

  static Future<String> startConversationWithRequest({
    required String receiverId,
    required String itemId,
    required String itemTitle,
    required String itemType,
    required String requestMessage,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final conversationId = await createOrGetConversation(
        currentUserId!,
        receiverId,
      );

      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (conversationDoc.exists) {
        final conversationData = conversationDoc.data() as Map<String, dynamic>;
        final activeRequest =
            conversationData['activeRequest'] as Map<String, dynamic>?;

        if (activeRequest != null &&
            activeRequest['status'] == 'pending' &&
            activeRequest['requesterId'] == currentUserId &&
            activeRequest['sellerId'] == receiverId) {
          final existingItemTitle =
              activeRequest['itemTitle'] ?? 'another item';
          throw Exception(
            'You already have a pending request for "$existingItemTitle". Please wait for the seller to respond before sending another request.',
          );
        }
      }

      final now = DateTime.now();

      await _firestore.collection('conversations').doc(conversationId).update({
        'discussedItems': FieldValue.arrayUnion([itemId]),
        'itemHistory': FieldValue.arrayUnion([
          {
            'itemId': itemId,
            'itemTitle': itemTitle,
            'itemType': itemType,
            'action': 'requested',
            'timestamp': now.millisecondsSinceEpoch,
            'requesterId': currentUserId,
            'sellerId': receiverId,
          },
        ]),
        'activeRequest': {
          'status': 'pending',
          'requesterId': currentUserId,
          'sellerId': receiverId,
          'itemId': itemId,
          'itemTitle': itemTitle,
          'itemType': itemType,
          'requestedAt': FieldValue.serverTimestamp(),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await sendMessage(conversationId, requestMessage);

      return conversationId;
    } catch (e) {
      throw Exception('Failed to start conversation with request: $e');
    }
  }

  static Future<void> sendMessage(String conversationId, String text) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    if (text.trim().isEmpty) return;

    await _sendMessageInternal(
      conversationId: conversationId,
      text: text.trim(),
      type: MessageType.text,
    );
  }

  static Future<void> sendMediaMessage({
    required String conversationId,
    required XFile mediaFile,
    required MessageType type,
    String? caption,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      String mediaUrl;
      try {
        mediaUrl = await _uploadMediaFile(mediaFile, type);
      } catch (storageError) {
        print('Storage upload failed, using base64 fallback: $storageError');
        mediaUrl = await _convertToBase64(mediaFile, type);
      }

      String? thumbnailUrl;
      if (type == MessageType.video) {
        thumbnailUrl = mediaUrl;
      }

      await _sendMessageInternal(
        conversationId: conversationId,
        text: caption ?? '',
        type: type,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      throw Exception('Failed to send media message: $e');
    }
  }

  static Future<String> _convertToBase64(XFile file, MessageType type) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = type == MessageType.image ? 'image/jpeg' : 'video/mp4';
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      throw Exception('Failed to convert media to base64: $e');
    }
  }

  static Future<void> _sendMessageInternal({
    required String conversationId,
    required String text,
    required MessageType type,
    String? mediaUrl,
    String? thumbnailUrl,
  }) async {
    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (!conversationDoc.exists) throw Exception('Conversation not found');

      final conversationData = conversationDoc.data()!;
      final participants = List<String>.from(conversationData['participants']);
      final otherUserId = participants.firstWhere(
        (participant) => participant != currentUserId,
        orElse: () => '',
      );

      // Save message FIRST without batch
      final now = Timestamp.now();

      final messageData = {
        'senderId': currentUserId,
        'text': text,
        'timestamp': now,
        'isRead': false,
        'type': type.name,
      };

      if (mediaUrl != null) messageData['mediaUrl'] = mediaUrl;
      if (thumbnailUrl != null) messageData['thumbnailUrl'] = thumbnailUrl;

      //Save message directly (not in batch)
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData);

      //Update conversation separately
      final currentUnreadCounts = Map<String, dynamic>.from(
        conversationData['unreadCounts'] ?? {},
      );

      if (otherUserId.isNotEmpty) {
        currentUnreadCounts[otherUserId] =
            (currentUnreadCounts[otherUserId] ?? 0) + 1;
      }
      currentUnreadCounts[currentUserId!] = 0;

      String lastMessagePreview;
      switch (type) {
        case MessageType.image:
          lastMessagePreview = '📷 Photo';
          break;
        case MessageType.video:
          lastMessagePreview = '🎥 Video';
          break;
        default:
          lastMessagePreview = text;
      }

      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': lastMessagePreview,
        'lastMessageTime': now,
        'lastMessageSenderId': currentUserId,
        'unreadCounts': currentUnreadCounts,
      });

      print('✅ Message saved successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  static Future<String> _uploadMediaFile(XFile file, MessageType type) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final folderName = type == MessageType.image
          ? 'chat_images'
          : 'chat_videos';

      final storageRef = FirebaseStorage.instance.ref();
      final fileRef = storageRef.child('$folderName/$currentUserId/$fileName');
      final fileBytes = await file.readAsBytes();

      final metadata = SettableMetadata(
        contentType: type == MessageType.image ? 'image/jpeg' : 'video/mp4',
        customMetadata: {
          'uploadedBy': currentUserId!,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = fileRef.putData(fileBytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }

  static Stream<List<Map<String, dynamic>>> getUserConversations() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> conversationsWithUserData = [];

          for (var doc in snapshot.docs) {
            final conversationData = doc.data();
            conversationData['id'] = doc.id;

            final participants = List<String>.from(
              conversationData['participants'],
            );
            final otherUserId = participants.firstWhere(
              (participant) => participant != currentUserId,
              orElse: () => '',
            );

            if (otherUserId.isNotEmpty) {
              final userInfo = await getUserInfo(otherUserId);
              conversationData['otherUserInfo'] = userInfo;
            }

            conversationsWithUserData.add(conversationData);
          }
          return conversationsWithUserData;
        });
  }

  static Stream<List<Message>> getConversationMessages(String conversationId) {
    return FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // ✅ Oldest first
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
        });
  }

  // TRUE DELETION: Completely removes conversation and all messages from Firestore
  static Future<void> deleteConversation(String conversationId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final batch = _firestore.batch();

      //Delete all messages in the conversation
      final messagesCollection = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages');

      final messagesSnapshot = await messagesCollection.get();

      print('🗑️ Deleting ${messagesSnapshot.docs.length} messages...');

      for (var messageDoc in messagesSnapshot.docs) {
        batch.delete(messageDoc.reference);
      }

      // Delete the conversation document itself
      final conversationRef = _firestore
          .collection('conversations')
          .doc(conversationId);
      batch.delete(conversationRef);

      // Commit the batch delete
      await batch.commit();

      print('✅ Conversation $conversationId completely deleted from Firestore');
    } catch (e) {
      print('❌ Error deleting conversation: $e');
      throw Exception('Failed to delete conversation: $e');
    }
  }

  static Future<void> markMessagesAsRead(String conversationId) async {
    if (currentUserId == null) return;

    try {
      final batch = _firestore.batch();

      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: currentUserId)
          .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      final conversationRef = _firestore
          .collection('conversations')
          .doc(conversationId);
      final conversationDoc = await conversationRef.get();

      if (conversationDoc.exists) {
        final currentUnreadCounts = Map<String, dynamic>.from(
          conversationDoc.data()?['unreadCounts'] ?? {},
        );
        currentUnreadCounts[currentUserId!] = 0;
        batch.update(conversationRef, {'unreadCounts': currentUnreadCounts});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  static Future<int> getUnreadCount(String conversationId) async {
    if (currentUserId == null) return 0;

    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (conversationDoc.exists) {
        final unreadCounts =
            conversationDoc.data()?['unreadCounts'] as Map<String, dynamic>?;
        return unreadCounts?[currentUserId] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data() as Map<String, dynamic>;
      } else {
        return {
          'displayName': 'Unknown User',
          'email': 'unknown@example.com',
          'school': 'Unknown School',
        };
      }
    } catch (e) {
      return {
        'displayName': 'Unknown User',
        'email': 'unknown@example.com',
        'school': 'Unknown School',
      };
    }
  }

  static Future<void> ensureUserDocumentExists(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await _firestore.collection('users').doc(userId).set({
            'displayName': currentUser.displayName ?? 'User',
            'email': currentUser.email ?? 'unknown@example.com',
            'school': 'University',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error ensuring user document exists: $e');
    }
  }
}
