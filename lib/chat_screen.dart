import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../models/message.dart';
import '../services/messaging_service.dart';
import 'user_profile_screen.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import 'dart:async';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserSchool;
  final String? itemTitle;
  final String? itemType;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserSchool,
    this.itemTitle,
    this.itemType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

bool _isAtBottom = true;

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasLoadedMessages = false;
  bool _hasMarkedAsRead = false;
  late AnimationController _fadeController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasUserInteracted = false;

  String _userDisplayName = '';
  String _userSchool = '';
  bool _userDataLoaded = false;

  XFile? _selectedMedia;
  String? _selectedMediaType;
  bool _otherUserOnline = false;
  DateTime? _otherUserLastSeen;
  StreamSubscription<DocumentSnapshot>? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Set user data immediately with provided values
    _userDisplayName = widget.otherUserName;
    _userSchool = widget.otherUserSchool.isNotEmpty
        ? widget.otherUserSchool
        : 'Loading...';
    _userDataLoaded = true;
    //Track if user is at bottom
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        // When reverse: true, position near 0 means at bottom
        _isAtBottom = _scrollController.position.pixels < 100;
      }
    });

    // Listen to other user's presence
    _listenToPresence();

    // Fetch updated user data in background
    _fetchUserData();
    // Call MessagingService directly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MessagingService.markMessagesAsRead(widget.conversationId);
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (userDoc.exists && mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          // Update display name if we got better data
          final newDisplayName =
              userData['displayName'] ??
              userData['name'] ??
              widget.otherUserName;
          if (newDisplayName != widget.otherUserName) {
            _userDisplayName = newDisplayName;
          }

          // Update school immediately, don't wait for fetch
          final newSchool =
              userData['school'] ??
              userData['university'] ??
              userData['institution'] ??
              widget.otherUserSchool;
          if (newSchool.isNotEmpty && newSchool != 'Unknown School') {
            _userSchool = newSchool;
          } else if (widget.otherUserSchool.isNotEmpty) {
            _userSchool = widget.otherUserSchool;
          } else {
            _userSchool = 'School not specified';
          }
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      // If fetch fails, keep the original values we set in initState
    }
  }

  void _listenToPresence() {
    _presenceSubscription = PresenceService.presenceStream(widget.otherUserId)
        .listen((snapshot) {
          if (!mounted || !snapshot.exists) return;

          final data = snapshot.data();
          if (data == null) return;

          final presence = data['presence'] as Map<String, dynamic>?;
          if (presence == null) return;

          setState(() {
            _otherUserOnline = presence['online'] == true;
            final lastSeenTimestamp = presence['lastSeen'];
            if (lastSeenTimestamp is Timestamp) {
              _otherUserLastSeen = lastSeenTimestamp.toDate();
            }
          });
        });
  }

  // More specific transaction status update
  Future<void> _updateTransactionStatus(
    String conversationId,
    String newStatus,
  ) async {
    try {
      // Get the active request details first
      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        print('❌ Conversation not found for transaction update');
        return;
      }

      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final activeRequest =
          conversationData['activeRequest'] as Map<String, dynamic>?;

      if (activeRequest == null) {
        print('❌ No active request found for transaction update');
        return;
      }

      final requesterId = activeRequest['requesterId'] as String?;
      final sellerId = activeRequest['sellerId'] as String?;
      final itemId = activeRequest['itemId'] as String?;

      if (requesterId == null || sellerId == null || itemId == null) {
        print('❌ Missing required data for transaction update');
        return;
      }

      // Update only the specific transactions for this exact request
      final transactionsQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('conversationId', isEqualTo: conversationId)
          .where('itemId', isEqualTo: itemId)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in transactionsQuery.docs) {
        final transactionData = doc.data();
        final userId = transactionData['userId'] as String?;

        // Only update transactions involving the exact users from this request
        if (userId == requesterId || userId == sellerId) {
          batch.update(doc.reference, {
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('✅ Updating transaction for user: $userId');
        }
      }

      await batch.commit();
      print(
        '✅ Transaction status updated to $newStatus for conversation $conversationId',
      );
    } catch (e) {
      print('❌ Error updating transaction status: $e');
    }
  }

  Future<DateTime?> _showDeadlinePicker() async {
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Return Deadline'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('When should the borrower return this item?'),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Custom Date:'),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().add(
                                    const Duration(days: 1),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedDate = picked;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                DateFormat('MMM d, yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The borrower will receive reminders before the deadline.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Set Deadline'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Accept request with auto-reject for other pending requests
  Future<void> _acceptRequest() async {
    try {
      // Get current user's name
      String currentUserName = '';
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId != null) {
        try {
          final currentUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
          currentUserName =
              currentUserDoc.data()?['displayName'] ??
              currentUserDoc.data()?['name'] ??
              'Unknown User';
        } catch (e) {
          currentUserName = 'Unknown User';
        }
      }

      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();

      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }

      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final activeRequest =
          conversationData['activeRequest'] as Map<String, dynamic>?;

      if (activeRequest == null) {
        throw Exception('No active request found');
      }

      final itemId = activeRequest['itemId'] as String?;
      final itemType = activeRequest['itemType'] as String?;
      final requesterId = activeRequest['requesterId'] as String?;
      final sellerId = activeRequest['sellerId'] as String?;

      if (itemId == null || itemType == null || requesterId == null) {
        throw Exception('Request information not found');
      }

      DateTime? deadline;

      // For borrow requests, ask seller to set deadline
      if (itemType.toLowerCase() == 'borrow') {
        deadline = await _showDeadlinePicker();
        if (deadline == null) {
          return; // User cancelled deadline selection
        }
      }

      // Mark request as accepted
      Map<String, dynamic> updateData = {
        'activeRequest.status': 'accepted',
        'activeRequest.acceptedAt': FieldValue.serverTimestamp(),
      };

      if (deadline != null) {
        updateData['activeRequest.deadline'] = Timestamp.fromDate(deadline);
      }

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update(updateData);

      // Update item status
      String newStatus;
      Map<String, dynamic> itemUpdateData = {
        'isActive': false,
        'completedAt': FieldValue.serverTimestamp(),
        'completedWith': requesterId,
      };

      switch (itemType.toLowerCase()) {
        case 'borrow':
          newStatus = 'borrowed';
          itemUpdateData['status'] = newStatus;
          itemUpdateData['isBorrowed'] = true;
          if (deadline != null) {
            itemUpdateData['borrowDeadline'] = Timestamp.fromDate(deadline);
            itemUpdateData['borrowStatus'] = 'active';
          }
          break;
        case 'sell':
          newStatus = 'sold';
          itemUpdateData['status'] = newStatus;
          itemUpdateData['isSold'] = true;
          break;
        case 'swap':
          newStatus = 'swapped';
          itemUpdateData['status'] = newStatus;
          itemUpdateData['isSwapped'] = true;
          break;
        default:
          newStatus = 'unavailable';
          itemUpdateData['status'] = newStatus;
      }

      await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .update(itemUpdateData);
      // Auto-reject with transaction status update
      try {
        final pendingRequestsQuery = await FirebaseFirestore.instance
            .collection('conversations')
            .where('activeRequest.itemId', isEqualTo: itemId)
            .where('activeRequest.status', isEqualTo: 'pending')
            .get();

        final batch = FirebaseFirestore.instance.batch();

        for (var doc in pendingRequestsQuery.docs) {
          // Skip the current conversation (the one being accepted)
          if (doc.id == widget.conversationId) continue;

          // Auto-reject conversation
          batch.update(doc.reference, {
            'activeRequest.status': 'rejected',
            'activeRequest.rejectedAt': FieldValue.serverTimestamp(),
            'activeRequest.autoRejected': true,
          });

          // Also update the corresponding transactions to rejected
          final rejectedConversationData = doc.data();
          final rejectedRequest =
              rejectedConversationData['activeRequest']
                  as Map<String, dynamic>?;

          if (rejectedRequest != null) {
            final rejectedConversationId = doc.id;

            // Find and update all transactions for this rejected conversation
            final transactionsToReject = await FirebaseFirestore.instance
                .collection('transactions')
                .where('conversationId', isEqualTo: rejectedConversationId)
                .where('itemId', isEqualTo: itemId)
                .where('status', isEqualTo: 'pending')
                .get();

            for (var txnDoc in transactionsToReject.docs) {
              batch.update(txnDoc.reference, {
                'status': 'rejected',
                'rejectedAt': FieldValue.serverTimestamp(),
                'autoRejected': true,
              });
            }
          }
        }

        await batch.commit();
        print(
          '✅ Auto-rejected ${pendingRequestsQuery.docs.length - 1} conversations and their transactions',
        );
      } catch (e) {
        print('❌ Error auto-rejecting other requests: $e');
      }

      // Create transactions
      if (itemType.toLowerCase() == 'borrow') {
        await FirebaseFirestore.instance.collection('transactions').add({
          'userId': requesterId,
          'role': 'requester',
          'type': 'borrow',
          'itemId': itemId,
          'itemTitle': activeRequest['itemTitle'] ?? 'Unknown Item',
          'otherUserId': sellerId,
          'otherUserName': currentUserName,
          'partnerId': sellerId,
          'conversationId': widget.conversationId,
          'status': 'accepted',
          'createdAt': FieldValue.serverTimestamp(),
          if (deadline != null) 'deadline': Timestamp.fromDate(deadline),
        });

        await FirebaseFirestore.instance.collection('transactions').add({
          'userId': sellerId,
          'role': 'provider',
          'type': 'borrow',
          'itemId': itemId,
          'itemTitle': activeRequest['itemTitle'] ?? 'Unknown Item',
          'otherUserId': requesterId,
          'otherUserName': activeRequest['requesterName'] ?? _userDisplayName,
          'partnerId': requesterId,
          'conversationId': widget.conversationId,
          'status': 'accepted',
          'createdAt': FieldValue.serverTimestamp(),
          if (deadline != null) 'deadline': Timestamp.fromDate(deadline),
        });
      } else if (itemType.toLowerCase() == 'sell') {
        String requesterName = activeRequest['requesterName'] ?? '';
        if (requesterName.isEmpty) {
          try {
            final requesterDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(requesterId)
                .get();
            requesterName =
                requesterDoc.data()?['displayName'] ??
                requesterDoc.data()?['name'] ??
                'Unknown User';
          } catch (e) {
            requesterName = 'Unknown User';
          }
        }

        await FirebaseFirestore.instance.collection('transactions').add({
          'userId': requesterId,
          'role': 'requester',
          'type': 'sell',
          'itemId': itemId,
          'itemTitle': activeRequest['itemTitle'] ?? 'Unknown Item',
          'otherUserId': sellerId,
          'otherUserName': currentUserName,
          'partnerId': sellerId,
          'conversationId': widget.conversationId,
          'status': 'accepted',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('transactions').add({
          'userId': sellerId,
          'role': 'provider',
          'type': 'sell',
          'itemId': itemId,
          'itemTitle': activeRequest['itemTitle'] ?? 'Unknown Item',
          'otherUserId': requesterId,
          'otherUserName': requesterName,
          'partnerId': requesterId,
          'conversationId': widget.conversationId,
          'status': 'accepted',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (itemType.toLowerCase() == 'swap') {
        if (sellerId != null && requesterId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('transactions').add({
            'userId': sellerId,
            'type': 'swap_given',
            'itemId': itemId,
            'itemTitle': activeRequest['itemTitle'] ?? 'Unknown Item',
            'partnerId': requesterId,
            'timestamp': FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance.collection('transactions').add({
            'userId': requesterId,
            'type': 'swap_received',
            'itemId': itemId,
            'itemTitle': activeRequest['itemTitle'] ?? 'Unknown Item',
            'partnerId': sellerId,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      // Send acceptance message
      String acceptanceMessage =
          '✅ I accepted your request! The ${itemType.toLowerCase()} is confirmed.';

      if (deadline != null && itemType.toLowerCase() == 'borrow') {
        final deadlineStr = DateFormat('MMM d, yyyy').format(deadline);
        acceptanceMessage += '\n\n📅 Please return it by: $deadlineStr';

        await NotificationService.scheduleDeadlineReminders(
          borrowerUserId: requesterId,
          itemTitle: activeRequest['itemTitle'] ?? 'Unknown Item',
          deadline: deadline,
        );
      }

      await MessagingService.sendMessage(
        widget.conversationId,
        acceptanceMessage,
      );
      await _updateTransactionStatus(widget.conversationId, 'accepted');

      await NotificationService.sendRequestAcceptedNotification(
        receiverUserId: requesterId,
        itemTitle: activeRequest['itemTitle'] ?? 'Unknown Item',
        accepterName: currentUserName,
        itemType: itemType,
        deadline: deadline,
        conversationId: widget.conversationId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.celebration, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Request accepted! Item marked as $newStatus.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Only clear activeRequest for sell/swap (NOT borrow)
      if (itemType.toLowerCase() != 'borrow') {
        // For sell/swap, clear activeRequest after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          final now = DateTime.now();
          Map<String, dynamic> historyItem = {
            'itemId': itemId,
            'itemTitle': activeRequest['itemTitle'],
            'itemType': itemType,
            'action': 'completed',
            'status': 'accepted',
            'timestamp': now.millisecondsSinceEpoch,
            'requesterId': requesterId,
            'sellerId': activeRequest['sellerId'],
          };

          FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId)
              .update({
                'activeRequest': FieldValue.delete(),
                'itemHistory': FieldValue.arrayUnion([historyItem]),
                'lastUpdated': FieldValue.serverTimestamp(),
              })
              .catchError((e) => print('Error clearing activeRequest: $e'));
        });
      }
      //  For borrow, keep activeRequest - it will be cleared when lender confirms return
    } catch (e) {
      print('Error accepting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build request banner with auto-reject message
  Widget _buildRequestBanner(Map<String, dynamic> conversationData) {
    final activeRequest =
        conversationData['activeRequest'] as Map<String, dynamic>?;

    if (activeRequest == null) {
      return const SizedBox.shrink();
    }

    final requestStatus = activeRequest['status'] ?? 'none';
    if (requestStatus == 'none') {
      return const SizedBox.shrink();
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSeller = currentUserId == activeRequest['sellerId'];
    final itemTitle = activeRequest['itemTitle'] ?? 'this item';
    final itemType = activeRequest['itemType'] ?? 'item';
    final requesterName = isSeller ? _userDisplayName : 'You';
    final deadline = activeRequest['deadline'] as Timestamp?;
    final autoRejected = activeRequest['autoRejected'] == true;

    Color backgroundColor;
    Color textColor;
    String message;
    List<Widget> actions = [];

    switch (requestStatus) {
      case 'pending':
        backgroundColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.orange.withOpacity(0.2)
            : Colors.orange[50]!;
        textColor = Colors.orange[800]!;
        if (isSeller) {
          message = _generateRequestMessage(itemType, requesterName, itemTitle);
          actions = [
            TextButton(
              onPressed: _rejectRequest,
              child: Text('Reject', style: TextStyle(color: Colors.red[600])),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _acceptRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                itemType.toLowerCase() == 'borrow'
                    ? 'Set Deadline & Accept'
                    : 'Accept',
              ),
            ),
          ];
        } else {
          String actionVerb;
          switch (itemType.toLowerCase()) {
            case 'borrow':
              actionVerb = 'borrow';
              break;
            case 'sell':
              actionVerb = 'buy';
              break;
            case 'swap':
              actionVerb = 'trade';
              break;
            default:
              actionVerb = 'get';
          }
          message =
              'Request sent to $_userDisplayName to $actionVerb "$itemTitle". Waiting for response...';
        }
        break;

      case 'rejected':
        backgroundColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.red.withOpacity(0.2)
            : Colors.red[50]!;
        textColor = Colors.red[800]!;

        // Show different message for auto-rejected requests
        if (autoRejected && !isSeller) {
          message =
              'This item is no longer available. It was accepted by another user.';
        } else {
          message = isSeller
              ? 'You rejected the request for "$itemTitle"'
              : '$_userDisplayName rejected your request for "$itemTitle"';
        }
        break;

      case 'accepted':
        backgroundColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.green.withOpacity(0.2)
            : Colors.green[50]!;
        textColor = Colors.green[800]!;
        message = isSeller
            ? 'You accepted the request for "$itemTitle"'
            : '$_userDisplayName accepted your request for "$itemTitle"';
        break;

      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: textColor.withOpacity(0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                requestStatus == 'pending'
                    ? Icons.schedule
                    : requestStatus == 'rejected'
                    ? Icons.cancel
                    : Icons.check_circle,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          // Show deadline if available
          if (deadline != null &&
              itemType.toLowerCase() == 'borrow' &&
              requestStatus == 'accepted') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.purple, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Return by: ${DateFormat('MMM d, yyyy').format(deadline.toDate())}',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ],
      ),
    );
  }

  Future<void> _rejectRequest() async {
    try {
      // Get current user's name
      String currentUserName = 'Unknown User';
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        try {
          final currentUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();
          currentUserName =
              currentUserDoc.data()?['displayName'] ??
              currentUserDoc.data()?['name'] ??
              'Unknown User';
        } catch (e) {
          print('Error getting current user name: $e');
          currentUserName = 'Unknown User';
        }
      }

      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();

      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }

      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final activeRequest =
          conversationData['activeRequest'] as Map<String, dynamic>?;

      if (activeRequest == null) {
        throw Exception('No active request found');
      }

      final itemTitle = activeRequest['itemTitle'] as String?;
      final requesterId = activeRequest['requesterId'] as String?;
      final itemType = activeRequest['itemType'] as String?;

      // Mark request as rejected
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
            'activeRequest.status': 'rejected',
            'activeRequest.rejectedAt': FieldValue.serverTimestamp(),
          });
      await _updateTransactionStatus(widget.conversationId, 'rejected');
      // Send rejection message
      final rejectionMessage = '❌ I declined your request for "$itemTitle".';
      await MessagingService.sendMessage(
        widget.conversationId,
        rejectionMessage,
      );

      //  Pass conversation ID to notification
      if (requesterId != null && itemTitle != null && itemType != null) {
        await NotificationService.sendRequestRejectedNotification(
          receiverUserId: requesterId,
          itemTitle: itemTitle,
          rejecterName: currentUserName,
          itemType: itemType,
          conversationId: widget.conversationId,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cancel, color: Colors.white),
              SizedBox(width: 8),
              Text('Request rejected.'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error rejecting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateRequestMessage(
    String action,
    String userName,
    String itemTitle,
  ) {
    switch (action.toLowerCase()) {
      case 'borrow':
        return '$userName wants to borrow "$itemTitle"';
      case 'sell':
        return '$userName wants to buy "$itemTitle"';
      case 'swap':
        return '$userName wants to trade "$itemTitle"';
      default:
        return '$userName is interested in "$itemTitle"';
    }
  }

  Widget _buildPresenceBadge() {
    // If online, show simple green dot
    if (_otherUserOnline) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }

    // If offline (any amount of time), show grey time badge
    if (_otherUserLastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(_otherUserLastSeen!);

      String timeText;

      if (difference.inMinutes < 1) {
        timeText = '1m';
      } else if (difference.inMinutes < 60) {
        timeText = '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        timeText = '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        timeText = '${difference.inDays}d';
      } else {
        timeText = '${(difference.inDays / 7).floor()}w';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          timeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // No presence data = grey dot
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  Future<ImageProvider?> _getProfileImage() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data();
      final base64Image = userData?['profileImageBase64'];

      if (base64Image != null && base64Image is String) {
        return MemoryImage(base64Decode(base64Image));
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Color typeColor = _getTypeColor(widget.itemType ?? '');

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            final actualUserId = _getActualOtherUserId();
            if (actualUserId.isEmpty || actualUserId == "otherUserUID") {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to load user profile'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(userId: actualUserId),
              ),
            );
          },
          child: SizedBox(
            // Constrain the entire title area
            width: MediaQuery.of(context).size.width * 0.6,
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FutureBuilder<ImageProvider?>(
                      future: _getProfileImage(),
                      builder: (context, snapshot) {
                        return CircleAvatar(
                          radius: 18,
                          backgroundColor: typeColor.withOpacity(0.2),
                          backgroundImage: snapshot.data,
                          child: snapshot.data == null
                              ? Text(
                                  _userDisplayName.isNotEmpty
                                      ? _userDisplayName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),

                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: _buildPresenceBadge(),
                    ),
                  ],
                ),

                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _userDisplayName.isNotEmpty
                            ? _userDisplayName
                            : 'Loading...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        _userDataLoaded
                            ? (_userSchool.isNotEmpty
                                  ? _userSchool
                                  : 'School not specified')
                            : 'Loading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Tap to view profile',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[600],
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 1,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).iconTheme.color,
            ),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmationDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Delete Conversation',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('conversations')
                .doc(widget.conversationId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }

              final conversationData =
                  snapshot.data!.data() as Map<String, dynamic>;
              final activeRequest =
                  conversationData['activeRequest'] as Map<String, dynamic>?;

              if (activeRequest == null) return const SizedBox.shrink();

              final requestStatus = activeRequest['status'] ?? 'none';
              final itemType =
                  (activeRequest['itemType'] as String?)?.toLowerCase() ?? '';

              // Show borrow status banner for accepted borrow items
              if (requestStatus == 'accepted' && itemType == 'borrow') {
                return buildBorrowStatusBanner(conversationData);
              }

              // Show regular request banner for pending/other statuses
              return _buildRequestBanner(conversationData);
            },
          ),

          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: MessagingService.getConversationMessages(
                widget.conversationId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_hasLoadedMessages) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (!_hasLoadedMessages && messages.isNotEmpty) {
                  _hasLoadedMessages = true;
                  _fadeController.forward();
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Smart auto-scroll: only if user is at bottom
                if (_isAtBottom) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients && mounted) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }

                return GestureDetector(
                  onTap: () {
                    if (!_hasUserInteracted) {
                      _hasUserInteracted = true;
                      _markConversationAsRead();
                    }
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final reversedIndex = messages.length - 1 - index;
                      final message = messages[reversedIndex];
                      final isMe =
                          message.senderId ==
                          FirebaseAuth.instance.currentUser?.uid;
                      final showDate = _shouldShowDate(messages, reversedIndex);

                      return Column(
                        children: [
                          if (showDate)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                _formatDate(message.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          _buildMessageBubble(message, isMe),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Media preview area
          if (_selectedMedia != null) _buildMediaPreview(),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.6)
                      : Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.photo_library, color: typeColor, size: 24),
                    onPressed: _handleMediaSelection,
                    tooltip: 'Send a photo',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: _selectedMedia != null
                          ? 'Add a caption...'
                          : 'Type a message...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      counterText: '',
                    ),
                    maxLines: 5,
                    minLines: 1,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                  ),
                ),

                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: typeColor,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _presenceSubscription?.cancel();
    super.dispose();
  }

  String _getActualOtherUserId() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return widget.otherUserId;

    final conversationParts = widget.conversationId.split('_');
    if (conversationParts.length >= 3) {
      final userId1 = conversationParts[1];
      final userId2 = conversationParts[2];
      return userId1 == currentUserId ? userId2 : userId1;
    }
    return widget.otherUserId;
  }

  Future<void> _markConversationAsRead() async {
    if (_hasMarkedAsRead) return;
    try {
      await MessagingService.markMessagesAsRead(widget.conversationId);
      _hasMarkedAsRead = true;
      print(
        '✅ Messages marked as read for conversation: ${widget.conversationId}',
      );
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'borrow':
        return Colors.green;
      case 'sell':
        return Colors.orange;
      case 'swap':
        return const Color(0xFF4A90E2);
      default:
        return const Color(0xFF4A90E2);
    }
  }

  Future<void> _handleMediaSelection() async {
    try {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Send Media',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(context, {
                    'source': ImageSource.camera,
                    'type': 'image',
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('Choose Photo'),
                  onTap: () => Navigator.pop(context, {
                    'source': ImageSource.gallery,
                    'type': 'image',
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.red),
                  title: const Text('Record Video'),
                  onTap: () => Navigator.pop(context, {
                    'source': ImageSource.camera,
                    'type': 'video',
                  }),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.video_library,
                    color: Colors.purple,
                  ),
                  title: const Text('Choose Video'),
                  onTap: () => Navigator.pop(context, {
                    'source': ImageSource.gallery,
                    'type': 'video',
                  }),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );

      if (result != null) {
        final source = result['source'] as ImageSource;
        final type = result['type'] as String;

        XFile? mediaFile;
        if (type == 'image') {
          mediaFile = await _imagePicker.pickImage(
            source: source,
            imageQuality: 70,
            maxWidth: 1024,
            maxHeight: 1024,
          );
        } else {
          mediaFile = await _imagePicker.pickVideo(
            source: source,
            maxDuration: const Duration(minutes: 5),
          );
        }

        if (mediaFile != null) {
          setState(() {
            _selectedMedia = mediaFile;
            _selectedMediaType = type;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting media: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    if (animate) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _showDeleteConfirmationDialog() async {
    // Check if there's a pending transaction
    try {
      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();

      if (conversationDoc.exists) {
        final conversationData = conversationDoc.data() as Map<String, dynamic>;
        final activeRequest =
            conversationData['activeRequest'] as Map<String, dynamic>?;

        if (activeRequest != null) {
          final status = activeRequest['status'] ?? 'none';
          final itemType = activeRequest['itemType'] ?? '';

          // Block deletion if status is pending
          if (status == 'pending') {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cannot delete conversation with pending request.',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }

          // For BORROW items - check if borrowStatus is completed
          if (itemType.toLowerCase() == 'borrow' && status == 'accepted') {
            // Check item's borrowStatus
            final itemId = activeRequest['itemId'];
            if (itemId != null) {
              final itemDoc = await FirebaseFirestore.instance
                  .collection('items')
                  .doc(itemId)
                  .get();

              if (itemDoc.exists) {
                final itemData = itemDoc.data() as Map<String, dynamic>;
                final borrowStatus = (itemData['borrowStatus'] ?? '')
                    .toString()
                    .toLowerCase();

                if (borrowStatus != 'completed') {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cannot delete active borrow. Wait until item is returned.',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 4),
                    ),
                  );
                  return;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking conversation status: $e');
    }

    // Show confirmation dialog if all checks pass
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Conversation'),
          content: const Text(
            'Are you sure you want to delete this conversation? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteConversation();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteConversation() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Deleting conversation...'),
              ],
            ),
          );
        },
      );

      // Delete the conversation
      await MessagingService.deleteConversation(widget.conversationId);

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Conversation deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Go back to messages screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error deleting conversation: $e');

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to delete conversation: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget buildBorrowStatusBanner(Map<String, dynamic> conversationData) {
    final activeRequest =
        conversationData['activeRequest'] as Map<String, dynamic>?;
    if (activeRequest == null) return const SizedBox.shrink();

    final requestStatus = activeRequest['status'] ?? 'none';
    final itemType =
        (activeRequest['itemType'] as String?)?.toLowerCase() ?? '';

    // Only show for accepted borrow requests
    if (requestStatus != 'accepted' || itemType != 'borrow') {
      return const SizedBox.shrink();
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSeller = currentUserId == activeRequest['sellerId'];
    final deadline = activeRequest['deadline'] as Timestamp?;

    // Check confirmation status
    final lenderConfirmed = activeRequest['lenderConfirmedReturn'] == true;

    // Hide banner completely if lender confirmed (transaction completed)
    if (lenderConfirmed) {
      return const SizedBox.shrink();
    }

    if (deadline == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(bottom: BorderSide(color: Colors.green.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSeller
                      ? 'Item Borrowed by ${widget.otherUserName}'
                      : 'You Borrowed This Item',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Colors.purple, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Return by ${DateFormat('MMM d, yyyy').format(deadline.toDate())}',
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Show confirmation button - ONLY for lender before confirmation
          if (isSeller) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showMarkAsReturnedDialog(
                  conversationId: widget.conversationId,
                  itemTitle: activeRequest['itemTitle'] ?? 'item',
                  isSeller: isSeller,
                  alreadyConfirmed: lenderConfirmed,
                ),
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text('Confirm Return Received'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> markBorrowAsCompleted(
    String conversationId,
    String itemTitle,
    bool isSeller,
  ) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get conversation data
      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }

      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final activeRequest =
          conversationData['activeRequest'] as Map<String, dynamic>?;

      if (activeRequest == null) {
        throw Exception('No active request found');
      }

      final itemId = activeRequest['itemId'] as String?;
      if (itemId == null) {
        throw Exception('Item ID not found');
      }

      // Only lender can confirm
      if (!isSeller) {
        throw Exception('Only the lender can confirm return');
      }

      // STEP 1: Set lender confirmation flag FIRST
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
            'activeRequest.lenderConfirmedReturn': true,
            'activeRequest.confirmedAt': FieldValue.serverTimestamp(),
          });

      print('✅ Lender confirmation flag set');

      // STEP 2: Start batch for other updates
      final batch = FirebaseFirestore.instance.batch();

      // Update transactions to completed
      final transactionsQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('conversationId', isEqualTo: conversationId)
          .where('itemId', isEqualTo: itemId)
          .where('type', isEqualTo: 'borrow')
          .where('status', isEqualTo: 'accepted')
          .get();

      print('📦 Found ${transactionsQuery.docs.length} transactions to update');

      for (var doc in transactionsQuery.docs) {
        print('   Updating transaction ${doc.id} to completed');
        batch.update(doc.reference, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update item status back to available
      print('📦 Updating item $itemId');
      batch.update(FirebaseFirestore.instance.collection('items').doc(itemId), {
        'isBorrowed': false,
        'borrowStatus': 'completed',
        'status': 'available',
        'isActive': true,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();
      print('✅ Batch committed successfully!');

      // Send system message
      await MessagingService.sendMessage(
        conversationId,
        '✅ Lender confirmed! $itemTitle has been marked as returned. Transaction completed!',
      );

      // STEP 3: Wait a moment for UI to reflect confirmation
      await Future.delayed(const Duration(milliseconds: 800));

      // STEP 4: NOW clear activeRequest and move to history
      final historyItem = {
        'itemId': itemId,
        'itemTitle': itemTitle,
        'itemType': 'borrow',
        'action': 'returned',
        'status': 'completed',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'requesterId': activeRequest['requesterId'],
        'sellerId': activeRequest['sellerId'],
        'deadline': activeRequest['deadline']?.millisecondsSinceEpoch,
        'completedBy': 'lender',
        'lenderConfirmed': true,
      };

      print('🗑️ Clearing activeRequest and adding to history');
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
            'activeRequest': FieldValue.delete(),
            'itemHistory': FieldValue.arrayUnion([historyItem]),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.celebration, color: Colors.white),
                SizedBox(width: 8),
                Text('Transaction completed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      print('❌ Error marking as completed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void showMarkAsReturnedDialog({
    required String conversationId,
    required String itemTitle,
    required bool isSeller,
    required bool alreadyConfirmed,
  }) {
    if (alreadyConfirmed) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('Already Confirmed'),
              ],
            ),
            content: Text(
              'You have already confirmed the return of $itemTitle.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.green),
              SizedBox(width: 8),
              Text('Confirm Return'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm that $itemTitle has been returned by the borrower?',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This will complete the transaction immediately.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                markBorrowAsCompleted(conversationId, itemTitle, isSeller);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Return'),
            ),
          ],
        );
      },
    );
  }

  void showFinalConfirmationDialog(
    String conversationId,
    String itemTitle,
    bool isSeller,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Final Confirmation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you absolutely sure?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'This action confirms that "$itemTitle" has been returned.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                markBorrowAsCompleted(conversationId, itemTitle, isSeller);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, I\'m Sure'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaPreview() {
    if (_selectedMedia == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.grey[50],
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]!
                : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _selectedMediaType == 'image'
                  ? Image.file(
                      File(_selectedMedia!.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error, color: Colors.red),
                    )
                  : Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.black,
                      child: const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMediaType == 'image'
                      ? 'Photo selected'
                      : 'Video selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  _selectedMedia!.name,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMedia = null;
                _selectedMediaType = null;
              });
            },
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Remove media',
          ),
        ],
      ),
    );
  }

  bool _shouldShowDate(List<Message> messages, int index) {
    if (index == 0) return true;

    final currentDate = messages[index].timestamp;
    final previousDate = messages[index - 1].timestamp;

    return currentDate.year != previousDate.year ||
        currentDate.month != previousDate.month ||
        currentDate.day != previousDate.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for OTHER person's messages
          if (!isMe) ...[
            FutureBuilder<Map<String, dynamic>?>(
              future: MessagingService.getUserInfo(message.senderId),
              builder: (context, snapshot) {
                final userData = snapshot.data ?? {};
                final userName = userData['displayName'] ?? 'User';
                final base64Image = userData['profileImageBase64'];

                return CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF4A90E2),
                  backgroundImage: base64Image != null
                      ? MemoryImage(base64Decode(base64Image))
                      : null,
                  child: base64Image == null
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 8),
          ],

          // Constrain message bubble width
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child:
                  message.type == MessageType.image && message.mediaUrl != null
                  ? Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  backgroundColor: Colors.black,
                                  appBar: AppBar(
                                    backgroundColor: Colors.black,
                                    iconTheme: const IconThemeData(
                                      color: Colors.white,
                                    ),

                                    actions: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.download,
                                          color: Colors.white,
                                        ),
                                        onPressed: () async {
                                          try {
                                            PermissionStatus status;
                                            if (await Permission
                                                .photos
                                                .isGranted) {
                                              status = PermissionStatus.granted;
                                            } else {
                                              status = await Permission.photos
                                                  .request();
                                            }

                                            if (status.isDenied ||
                                                status.isPermanentlyDenied) {
                                              status = await Permission.storage
                                                  .request();
                                            }

                                            if (!status.isGranted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'Storage permission required',
                                                  ),
                                                  action: SnackBarAction(
                                                    label: 'Settings',
                                                    onPressed: openAppSettings,
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            Uint8List bytes;
                                            if (message.mediaUrl!.startsWith(
                                              'data:',
                                            )) {
                                              bytes = base64Decode(
                                                message.mediaUrl!.split(',')[1],
                                              );
                                            } else {
                                              final response = await http.get(
                                                Uri.parse(message.mediaUrl!),
                                              );
                                              bytes = response.bodyBytes;
                                            }

                                            await Gal.putImageBytes(bytes);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  '✓ Saved to gallery',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed: $e'),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  body: Center(
                                    child: PhotoView(
                                      imageProvider:
                                          message.mediaUrl!.startsWith('data:')
                                          ? MemoryImage(
                                              base64Decode(
                                                message.mediaUrl!.split(',')[1],
                                              ),
                                            )
                                          : CachedNetworkImageProvider(
                                                  message.mediaUrl!,
                                                )
                                                as ImageProvider,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: message.mediaUrl!.startsWith('data:')
                                ? Image.memory(
                                    base64Decode(
                                      message.mediaUrl!.split(',')[1],
                                    ),
                                    width: 200,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: message.mediaUrl!,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 200,
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                          ),
                        ),
                        // Caption if exists
                        if (message.text.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(
                                      0xFF4A90E2,
                                    ) // Keep blue for sent messages
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[700]
                                        : Colors.grey[300]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        // Timestamp below image
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 4,
                            left: 4,
                            right: 4,
                          ),
                          child: Text(
                            DateFormat('h:mm a').format(message.timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF4A90E2)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isMe
                              ? const Radius.circular(16)
                              : const Radius.circular(4),
                          bottomRight: isMe
                              ? const Radius.circular(4)
                              : const Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.text,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('h:mm a').format(message.timestamp),
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.grey[600],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    // Mark as read when user sends a message
    if (!_hasUserInteracted) {
      _hasUserInteracted = true;
      _markConversationAsRead();
    }

    if (_selectedMedia != null && _selectedMediaType != null) {
      //  Clear UI immediately - no loading state
      final mediaToSend = _selectedMedia;
      final mediaTypeToSend = _selectedMediaType;
      final captionToSend = text.isNotEmpty ? text : null;

      setState(() {
        _messageController.clear();
        _selectedMedia = null;
        _selectedMediaType = null;
      });

      // Send in background without blocking UI
      MessagingService.sendMediaMessage(
            conversationId: widget.conversationId,
            mediaFile: mediaToSend!,
            type: mediaTypeToSend == 'image'
                ? MessageType.image
                : MessageType.video,
            caption: captionToSend,
          )
          .then((_) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
          })
          .catchError((e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send media: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });

      return;
    }

    if (text.isEmpty) return;

    // Clear text field immediately
    _messageController.clear();

    // Send in background without showing loading
    MessagingService.sendMessage(widget.conversationId, text)
        .then((_) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        })
        .catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send message: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
  }
}
