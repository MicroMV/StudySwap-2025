import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/messaging_service.dart';
import '../services/presence_service.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShimmerWidget extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerWidget({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _selectedFilter = 'All';
  final Map<String, Map<String, dynamic>> _userCache = {};

  // Map to store presence subscriptions
  final Map<String, StreamSubscription<DocumentSnapshot>>
  _presenceSubscriptions = {};
  final Map<String, bool> _userOnlineStatus = {};
  final Map<String, DateTime?> _userLastSeen = {};

  // Dispose subscriptions when screen is closed
  @override
  void dispose() {
    for (var subscription in _presenceSubscriptions.values) {
      subscription.cancel();
    }
    _presenceSubscriptions.clear();
    super.dispose();
  }

  // Listen to user's presence
  void _listenToUserPresence(String userId) {
    if (_presenceSubscriptions.containsKey(userId)) return; // Already listening

    final subscription = PresenceService.presenceStream(userId).listen((
      snapshot,
    ) {
      if (!mounted || !snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final presence = data['presence'] as Map<String, dynamic>?;
      if (presence == null) return;

      setState(() {
        _userOnlineStatus[userId] = presence['online'] == true;
        final lastSeenTimestamp = presence['lastSeen'];
        if (lastSeenTimestamp is Timestamp) {
          _userLastSeen[userId] = lastSeenTimestamp.toDate();
        }
      });
    });

    _presenceSubscriptions[userId] = subscription;
  }

  // Build presence badge with larger green dot
  Widget _buildPresenceBadge(String userId) {
    final isOnline = _userOnlineStatus[userId] ?? false;
    final lastSeen = _userLastSeen[userId];

    // If online, show green dot (LARGER SIZE)
    if (isOnline) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      );
    }

    // If offline, show grey time badge
    if (lastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(lastSeen);
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          timeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // No presence data = grey dot
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget _buildShimmerContainer({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[700]
            : Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: const Center(child: Text('Please log in to view messages')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserSearchScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // Filter tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: Row(
              children: [
                _buildFilterTab('All', _selectedFilter == 'All'),
                const SizedBox(width: 16),
                _buildFilterTab('Unread', _selectedFilter == 'Unread'),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: MessagingService.getUserConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 3,
                    itemBuilder: (context, index) =>
                        _buildShimmerConversationCard(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[400]),
                        const SizedBox(height: 16),
                        Text('Error loading conversations: ${snapshot.error}'),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final conversations = snapshot.data ?? [];
                final filteredConversations = _filterConversations(
                  conversations,
                );

                if (filteredConversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedFilter == 'Unread'
                              ? Icons.mark_email_read_outlined
                              : Icons.chat_bubble_outline,
                          size: 80,
                          color: Theme.of(
                            context,
                          ).iconTheme.color?.withOpacity(0.4),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _selectedFilter == 'Unread'
                              ? 'No unread messages'
                              : 'No conversations yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedFilter == 'All')
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const UserSearchScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('Find Users to Chat'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A90E2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredConversations.length,
                  itemBuilder: (context, index) {
                    final conversation = filteredConversations[index];
                    return _buildConversationCard(
                      context,
                      conversation,
                      user.uid,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterConversations(
    List<Map<String, dynamic>> conversations,
  ) {
    final currentUserId = MessagingService.currentUserId;
    if (currentUserId == null) return [];

    List<Map<String, dynamic>> conversationsWithMessages = conversations.where((
      conv,
    ) {
      final lastMessage = conv['lastMessage'] as String? ?? '';
      return lastMessage.isNotEmpty && lastMessage.trim().isNotEmpty;
    }).toList();

    switch (_selectedFilter) {
      case 'Unread':
        return conversationsWithMessages.where((conv) {
          final unreadCounts = conv['unreadCounts'] as Map<String, dynamic>?;
          final userUnreadCount = unreadCounts?[currentUserId] ?? 0;
          return userUnreadCount > 0;
        }).toList();
      default:
        return conversationsWithMessages;
    }
  }

  Widget _buildFilterTab(String title, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  //  Conversation card without double shimmer
  Widget _buildConversationCard(
    BuildContext context,
    Map<String, dynamic> conversation,
    String currentUserId,
  ) {
    final participants = List<String>.from(conversation['participants'] ?? []);
    final otherParticipantId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    //  Start listening to this user's presence
    if (otherParticipantId.isNotEmpty) {
      _listenToUserPresence(otherParticipantId);
    }

    Map<String, dynamic>? userInfo = conversation['otherUserInfo'];

    return FutureBuilder<Map<String, dynamic>?>(
      future: userInfo != null
          ? Future.value(userInfo)
          : _getUserInfo(otherParticipantId),
      initialData: userInfo,
      builder: (context, snapshot) {
        final userData = snapshot.data ?? {};

        //  Only show shimmer if NO initial data AND still waiting
        final isLoading =
            userInfo == null &&
            snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null;

        //  If loading with NO data at all, don't render card yet
        if (isLoading) {
          return const SizedBox.shrink(); // Don't show anything while loading
        }

        final userName =
            userData['displayName'] ?? userData['email'] ?? 'Unknown User';
        final rawSchool = userData['school'] ?? '';
        final userSchool = (rawSchool == 'University' || rawSchool.isEmpty)
            ? ''
            : rawSchool;
        final avatar = userName.isNotEmpty && userName != 'Unknown User'
            ? userName[0].toUpperCase()
            : 'U';

        Color typeColor = _getTypeColor(conversation['itemType'] ?? '');
        final unreadCounts =
            conversation['unreadCounts'] as Map<String, dynamic>?;
        final userUnreadCount = unreadCounts?[currentUserId] ?? 0;
        final isUnread = userUnreadCount > 0;
        final lastMessageTime = conversation['lastMessageTime']?.toDate();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
              ),
            ],
          ),

          child: InkWell(
            onTap: () {
              _navigateToChat(
                context,
                conversation,
                otherParticipantId,
                userName,
                userSchool,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar with presence badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: typeColor,
                        backgroundImage: _getProfileImage(userData),
                        child: _getProfileImage(userData) == null
                            ? Text(
                                avatar,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      // Presence badge
                      if (otherParticipantId.isNotEmpty)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: _buildPresenceBadge(otherParticipantId),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Conversation Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                userName,
                                style: TextStyle(
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 16,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            // Time display
                            if (lastMessageTime != null)
                              Text(
                                _formatTime(lastMessageTime),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (userSchool.isNotEmpty)
                          Text(
                            userSchool,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        if (conversation['itemTitle'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (conversation['itemType'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    conversation['itemType']!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: typeColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  conversation['itemTitle']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          conversation['lastMessage'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: isUnread
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
                            fontWeight: isUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Chevron and unread count
                  Column(
                    children: [
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                      if (isUnread && userUnreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            userUnreadCount > 99
                                ? '99+'
                                : userUnreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToChat(
    BuildContext context,
    Map<String, dynamic> conversation,
    String otherParticipantId,
    String userName,
    String userSchool,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation['id'],
          otherUserName: userName,
          otherUserId: otherParticipantId,
          otherUserSchool: userSchool,
          itemTitle: conversation['itemTitle'],
          itemType: conversation['itemType'],
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildShimmerConversationCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: ShimmerWidget(
        child: Row(
          children: [
            // Avatar shimmer
            _buildShimmerContainer(
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(28),
            ),
            const SizedBox(width: 12),

            // Content shimmer
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildShimmerContainer(
                          width: double.infinity,
                          height: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildShimmerContainer(
                        width: 40,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildShimmerContainer(
                    width: 80,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  _buildShimmerContainer(
                    width: double.infinity,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            // Chevron shimmer
            _buildShimmerContainer(
              width: 16,
              height: 16,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getUserInfo(String userId) async {
    if (userId.isEmpty) return null;

    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    final userInfo = await MessagingService.getUserInfo(userId);
    if (userInfo != null) {
      _userCache[userId] = userInfo;
    }
    return userInfo;
  }

  ImageProvider? _getProfileImage(Map<String, dynamic> userData) {
    final base64Image = userData['profileImageBase64'];
    if (base64Image != null && base64Image is String) {
      try {
        return MemoryImage(base64Decode(base64Image));
      } catch (e) {
        print('Error decoding base64 image: $e');
        return null;
      }
    }
    return null;
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
        return Colors.grey;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
