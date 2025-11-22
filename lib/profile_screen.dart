import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'transaction_history_screen.dart';
import 'favorites_screen.dart';
import 'reviews_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'chatsupport.dart';
import 'privacy_policy.dart';
import 'setting_screen.dart';

class ShimmerWidget extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final BuildContext? context;

  const ShimmerWidget({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.context,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        widget.baseColor ?? (isDark ? Colors.grey[700]! : Colors.grey[300]!);
    final highlightColor =
        widget.highlightColor ??
        (isDark ? Colors.grey[600]! : Colors.grey[200]!);

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
              colors: [baseColor, highlightColor, baseColor],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final String userId;
  late Future<Map<String, dynamic>> userDataFuture;
  late Future<Map<String, dynamic>> userStatsFuture;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _profileImageBase64;
  bool _uploadingImage = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    userDataFuture = fetchUserData();
    userStatsFuture = fetchUserStats();
  }

  //  Shimmer helper method
  Widget _buildShimmerContainer({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }

  // Complete shimmer profile
  Widget _buildShimmerProfile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          //  Shimmer Profile Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color.fromARGB(255, 236, 239, 240),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(
                    255,
                    208,
                    212,
                    214,
                  ).withOpacity(0.4),
                  spreadRadius: 2,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ShimmerWidget(
              child: Column(
                children: [
                  // Avatar shimmer
                  ClipOval(
                    child: _buildShimmerContainer(
                      width: 100,
                      height: 100,
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Name shimmer
                  _buildShimmerContainer(
                    width: 150,
                    height: 24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),

                  // Email shimmer
                  _buildShimmerContainer(
                    width: 200,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),

                  // School badge shimmer
                  _buildShimmerContainer(
                    width: 180,
                    height: 32,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  const SizedBox(height: 20),

                  // Rating shimmer
                  _buildShimmerContainer(
                    width: 160,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Shimmer Stats Cards (2x2 Grid)
          Column(
            children: [
              // First Row
              Row(
                children: [
                  Expanded(child: _buildShimmerStatCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildShimmerStatCard()),
                ],
              ),
              const SizedBox(height: 12),
              // Second Row
              Row(
                children: [
                  Expanded(child: _buildShimmerStatCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildShimmerStatCard()),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          //  Shimmer Menu Items
          Column(
            children: List.generate(
              6,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildShimmerMenuCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shimmer stat card
  Widget _buildShimmerStatCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromARGB(255, 236, 239, 240),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 208, 212, 214).withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ShimmerWidget(
        child: Column(
          children: [
            _buildShimmerContainer(
              width: 24,
              height: 24,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            _buildShimmerContainer(
              width: 40,
              height: 24,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            _buildShimmerContainer(
              width: 60,
              height: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  // Shimmer menu card
  Widget _buildShimmerMenuCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromARGB(255, 236, 239, 240),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 208, 212, 214).withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ShimmerWidget(
        child: Row(
          children: [
            _buildShimmerContainer(
              width: 44,
              height: 44,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShimmerContainer(
                    width: double.infinity,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  _buildShimmerContainer(
                    width: 200,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            _buildShimmerContainer(
              width: 24,
              height: 24,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  // Fetch both displayName and school from Firestore
  Future<Map<String, dynamic>> fetchUserData() async {
    if (userId.isEmpty) {
      return {
        'displayName': 'No Name',
        'school': 'No School Listed',
        'profileImageBase64': null,
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return {
          'displayName': 'No Name',
          'school': 'No School Listed',
          'profileImageBase64': null,
        };
      }

      final data = doc.data();
      return {
        'displayName':
            data?['displayName'] ??
            data?['name'] ??
            data?['fullName'] ??
            'No Name',
        'school':
            data?['school'] ??
            data?['university'] ??
            data?['institution'] ??
            'No School Listed',
        'profileImageBase64': data?['profileImageBase64'], // ✅ Get base64 image
      };
    } catch (e) {
      return {
        'displayName': 'Error loading name',
        'school': 'Error loading school',
        'profileImageBase64': null,
      };
    }
  }

  Future<Map<String, dynamic>> fetchUserStats() async {
    if (userId.isEmpty) {
      return {};
    }

    // Items posted by user (all items they created)
    int postedCount = await _getPostedItemsCount(userId);

    // Items sold by user (items they posted that got sold)
    int soldCount = await _getSoldItemsCount(userId);

    // Items borrowed by user (items they got from others)
    int borrowedCount = await _getBorrowedItemsCount(userId);

    // Items swapped by user (items they got through swaps)
    int swappedCount = await _getSwappedItemsCount(userId);

    final ratingData = await _getUserRating(userId);

    return {
      'postedCount': postedCount,
      'borrowedCount': borrowedCount,
      'soldCount': soldCount,
      'swappedCount': swappedCount,
      'rating': ratingData['rating'] ?? 0.0,
      'reviewCount': ratingData['reviewCount'] ?? 0,
    };
  }

  // Count all items posted by user
  Future<int> _getPostedItemsCount(String userId) async {
    final snapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  // Count items sold by user (items they posted that got sold)
  Future<int> _getSoldItemsCount(String userId) async {
    final snapshot = await _firestore
        .collection('items')
        .where('userId', isEqualTo: userId)
        .where('action', isEqualTo: 'Sell')
        .where('isSold', isEqualTo: true)
        .get();
    return snapshot.size;
  }

  /// Count items borrowed by user (items they got from others that are completed)
  Future<int> _getBorrowedItemsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('items')
          .where('completedWith', isEqualTo: userId)
          .where('action', isEqualTo: 'Borrow')
          .where('borrowStatus', isEqualTo: 'completed')
          .get();

      print('Borrowed items for $userId: ${snapshot.size}');
      return snapshot.size;
    } catch (e) {
      print('Error getting borrowed count: $e');
      return 0;
    }
  }

  // Count items swapped by user (using transaction system for both given and received)
  Future<int> _getSwappedItemsCount(String userId) async {
    try {
      // Count both swap_given and swap_received transactions
      final givenSnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'swap_given')
          .get();

      final receivedSnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'swap_received')
          .get();

      final totalSwaps = givenSnapshot.size + receivedSnapshot.size;
      print(
        'Swapped items for $userId: $totalSwaps (given: ${givenSnapshot.size}, received: ${receivedSnapshot.size})',
      );
      return totalSwaps;
    } catch (e) {
      print('Error getting swapped count: $e');
      // Fallback to old method if transactions don't exist yet
      try {
        final snapshot = await _firestore
            .collection('items')
            .where('completedWith', isEqualTo: userId)
            .where('action', isEqualTo: 'Swap')
            .where('isSwapped', isEqualTo: true)
            .get();
        print('Swapped items (fallback) for $userId: ${snapshot.size}');
        return snapshot.size;
      } catch (e2) {
        print('Error with fallback swapped count: $e2');
        return 0;
      }
    }
  }

  Future<Map<String, dynamic>> _getUserRating(String userId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('reviewedUserId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isEmpty) {
      return {'rating': 0.0, 'reviewCount': 0};
    }

    double total = 0;
    for (final doc in snapshot.docs) {
      final rating = (doc.get('rating') ?? 0).toDouble();
      total += rating;
    }

    final avgRating = total / snapshot.docs.length;
    return {'rating': avgRating, 'reviewCount': snapshot.docs.length};
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Please log in to view profile')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.wait([userDataFuture, userStatsFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerProfile();
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading profile'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        userDataFuture = fetchUserData();
                        userStatsFuture = fetchUserStats();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final userData = snapshot.data?[0] ?? {};
          final statsData = snapshot.data?[1] ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]!
                          : const Color.fromARGB(255, 236, 239, 240),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.3)
                            : const Color.fromARGB(
                                255,
                                208,
                                212,
                                214,
                              ).withOpacity(0.4),
                        spreadRadius: 2,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          _uploadingImage
                              ? const CircleAvatar(
                                  radius: 50,
                                  child: CircularProgressIndicator(),
                                )
                              : CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.blue[400],
                                  backgroundImage: _getProfileImage(userData),
                                  child: _getProfileImage(userData) == null
                                      ? Text(
                                          (userData['displayName'] ??
                                                  user.email ??
                                                  'U')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 40,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: 220,
                        alignment: Alignment.center,
                        child: Text(
                          userData['displayName'] ?? 'No Name',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Email
                      Text(
                        user.email ?? 'No Email',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue.withOpacity(0.15)
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          userData['school'] ?? 'No School Listed',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Rating Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Dynamic star rating display
                          _buildStarRating(
                            (statsData['rating'] ?? 0.0).toDouble(),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(statsData['rating'] ?? 0.0).toStringAsFixed(1)} (${statsData['reviewCount'] ?? 0} reviews)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                //  Statistics Row with New Colors and Layout (2x2 Grid)
                Column(
                  children: [
                    // First Row
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '${statsData['postedCount'] ?? 0}',
                              'Items\nPosted',
                              Colors.purple[50]!,
                              Colors.purple[700]!,
                              Icons.inventory,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              '${statsData['borrowedCount'] ?? 0}',
                              'Items\nBorrowed',
                              Colors.green[50]!,
                              Colors.green[700]!,
                              Icons.download,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Second Row
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '${statsData['soldCount'] ?? 0}',
                              'Items\nSold',
                              Colors.yellow[50]!,
                              Colors.yellow[700]!,
                              Icons.sell,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              '${statsData['swappedCount'] ?? 0}',
                              'Items\nSwapped',
                              Colors.blue[50]!,
                              Colors.blue[700]!,
                              Icons.swap_horiz,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Menu Items Section
                Column(
                  children: [
                    // In your ProfileScreen build method:
                    _buildMenuCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'My Offers',
                      subtitle: 'Manage your available posted items',
                      onTap: () {
                        //  Navigate to MyOffersScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyOffersScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: Icons.history,
                      title: 'Transaction History',
                      subtitle: 'View your past transactions',
                      onTap: () {
                        //  Navigate to Transaction History screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TransactionHistoryScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildMenuCard(
                      icon: Icons.favorite_outline,
                      title: 'Favorites',
                      subtitle: 'Items you\'ve saved',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FavoritesScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: Icons.star_outline,
                      title: 'Reviews',
                      subtitle: 'Manage your reviews',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReviewsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      subtitle: 'Get help and contact support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudySwapChatScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy policy',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // Show confirmation dialog
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Log Out'),
                              content: const Text(
                                'Are you sure you want to log out?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );

                          // If user confirmed, proceed with logout
                          if (shouldLogout == true && mounted) {
                            try {
                              // Sign out from Firebase
                              await FirebaseAuth.instance.signOut();

                              // Navigate directly to login and clear all routes
                              if (mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/login',
                                  (route) => false,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error signing out: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  //  Dynamic star rating display method
  Widget _buildStarRating(double rating, {double size = 18.0}) {
    // Ensure rating is between 0 and 5
    rating = rating.clamp(0.0, 5.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (rating > index + 0.75) {
          // Full star (rating > 0.75, 1.75, 2.75, 3.75, 4.75)
          return Icon(Icons.star, color: Colors.orange, size: size);
        } else if (rating > index + 0.25) {
          // Half star (rating > 0.25, 1.25, 2.25, 3.25, 4.25)
          return Icon(Icons.star_half, color: Colors.orange, size: size);
        } else {
          // Empty star
          return Icon(Icons.star_border, color: Colors.orange, size: size);
        }
      }),
    );
  }

  Widget _buildStatCard(
    String count,
    String label,
    Color bgColor,
    Color iconColor,
    IconData icon,
  ) {
    // Change icons based on label
    IconData displayIcon = icon;
    if (label == 'Items\nSold') {
      displayIcon = Icons.attach_money;
    } else if (label == 'Items\nSwapped') {
      displayIcon = Icons.swap_horiz;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 30,
            child: Align(
              alignment: Alignment.topCenter,
              child: Icon(displayIcon, color: iconColor, size: 24),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: iconColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage(Map<String, dynamic> userData) {
    // Check local state first
    if (_profileImageBase64 != null) {
      try {
        return MemoryImage(base64Decode(_profileImageBase64!));
      } catch (e) {
        print('Error decoding local base64: $e');
        return null;
      }
    }

    // Check Firestore data
    final base64FromFirestore = userData['profileImageBase64'];
    if (base64FromFirestore != null && base64FromFirestore is String) {
      try {
        return MemoryImage(base64Decode(base64FromFirestore));
      } catch (e) {
        print('Error decoding Firestore base64: $e');
        return null;
      }
    }

    return null;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      // Show options dialog
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick image with smaller dimensions for base64
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 400, // Smaller to keep under 1MB Firestore limit
        maxHeight: 400,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      setState(() {
        _uploadingImage = true;
      });

      // Convert to base64
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Check size (Firestore has 1MB document limit)
      final sizeInKB = (base64Image.length * 0.75) / 1024; // Approximate size
      if (sizeInKB > 800) {
        // Keep under 800KB to be safe
        setState(() {
          _uploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image too large. Please choose a smaller photo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Save to Firestore
      await _firestore.collection('users').doc(userId).update({
        'profileImageBase64': base64Image,
      });

      // Update local state
      setState(() {
        _profileImageBase64 = base64Image;
        _uploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _uploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : const Color.fromARGB(255, 236, 239, 240),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : const Color.fromARGB(255, 208, 212, 214).withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
          size: 24,
        ),
        onTap: onTap,
      ),
    );
  }
}
