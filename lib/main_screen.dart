import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'home_screen.dart';
import 'browse_screen.dart';
import 'post_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialTabIndex;

  const MainScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  int _unreadConversationsCount = 0;
  StreamSubscription<QuerySnapshot>? _conversationSubscription;

  final List<Widget> _screens = [
    const HomeScreen(),
    const BrowseScreen(),
    const PostScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _listenToUnreadMessages();
  }

  void _listenToUnreadMessages() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _conversationSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          Set<String> usersWithUnreadMessages = {};

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final lastMessageSenderId = data['lastMessageSenderId'] as String?;
            final unreadCounts =
                data['unreadCounts'] as Map<String, dynamic>? ?? {};
            final userUnreadCount = unreadCounts[user.uid] as int? ?? 0;

            if (userUnreadCount > 0 &&
                lastMessageSenderId != null &&
                lastMessageSenderId != user.uid) {
              usersWithUnreadMessages.add(lastMessageSenderId);
            }
          }

          setState(() {
            _unreadConversationsCount = usersWithUnreadMessages.length;
          });
        });
  }

  Widget _buildBadge(Widget child, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]!
                      : Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color:
              Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
              (Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.white),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.white,
          selectedItemColor: const Color(0xFF4A90E2),
          unselectedItemColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Browse',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Post',
            ),
            BottomNavigationBarItem(
              icon: _buildBadge(
                const Icon(Icons.message_outlined),
                _unreadConversationsCount,
              ),
              activeIcon: _buildBadge(
                const Icon(Icons.message),
                _unreadConversationsCount,
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
