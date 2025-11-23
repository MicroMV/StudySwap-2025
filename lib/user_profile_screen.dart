import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'write_review_screen.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'dart:convert';

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

Widget _buildShimmerContainer({
  required double width,
  required double height,
  BorderRadius? borderRadius,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: borderRadius ?? BorderRadius.circular(4),
    ),
  );
}

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({required this.userId, super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<Map<String, dynamic>> userDataFuture;
  late Future<Map<String, dynamic>> userStatsFuture;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    userDataFuture = fetchUserData();
    userStatsFuture = fetchUserStats();
  }

  Map<String, dynamic>? _convertToMap(Object? data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  ImageProvider? _getProfileImage(Map<String, dynamic>? userData) {
    if (userData == null) return null;

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

  Future<Map<String, dynamic>> fetchUserData() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();

      if (!doc.exists) {
        if (_isCurrentUser()) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            return {
              'displayName':
                  user.displayName ??
                  user.email?.split('@')[0] ??
                  'Current User',
              'email': user.email ?? '',
              'school': 'No School Listed',
            };
          }
        }
        return {
          'displayName': 'User Not Found',
          'email': '',
          'school': 'No School Listed',
          'error': 'User not found',
          'profileImageBase64': null,
        };
      }

      final data = doc.data();
      return {
        'displayName': data?['displayName'] ?? data?['name'] ?? 'Unknown User',
        'email': data?['email'] ?? '',
        'school': data?['school'] ?? 'No School Listed',
        'profileImageBase64': data?['profileImageBase64'],
      };
    } catch (e) {
      return {
        'displayName': 'Error loading user',
        'email': '',
        'school': '',
        'error': e.toString(),
      };
    }
  }

  Widget _buildShimmerProfile() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ShimmerWidget(
            child: Column(
              children: [
                ClipOval(
                  child: _buildShimmerContainer(
                    width: 100,
                    height: 100,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                const SizedBox(height: 16),
                _buildShimmerContainer(
                  width: 150,
                  height: 24,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                _buildShimmerContainer(
                  width: 120,
                  height: 16,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(height: 12),
                _buildShimmerContainer(
                  width: 180,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ShimmerWidget(
            child: Column(
              children: [
                _buildShimmerContainer(
                  width: 150,
                  height: 28,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                _buildShimmerContainer(
                  width: 100,
                  height: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ShimmerWidget(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildShimmerStatCard(), _buildShimmerStatCard()],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_buildShimmerStatCard(), _buildShimmerStatCard()],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShimmerWidget(
          child: _buildShimmerContainer(
            width: double.infinity,
            height: 50,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerWidget(
                child: _buildShimmerContainer(
                  width: 120,
                  height: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              _buildReviewsShimmer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerStatCard() {
    return Column(
      children: [
        _buildShimmerContainer(
          width: 28,
          height: 28,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        _buildShimmerContainer(
          width: 30,
          height: 24,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        _buildShimmerContainer(
          width: 50,
          height: 12,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildReviewsShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ShimmerWidget(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildShimmerContainer(
                      width: 90,
                      height: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const Spacer(),
                    _buildShimmerContainer(
                      width: 80,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildShimmerContainer(
                  width: double.infinity,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                _buildShimmerContainer(
                  width: 200,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                _buildShimmerContainer(
                  width: 60,
                  height: 11,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchUserStats() async {
    try {
      int postedCount = await _getPostedItemsCount(widget.userId);
      int soldCount = await _getSoldItemsCount(widget.userId);
      int borrowedCount = await _getBorrowedItemsCount(widget.userId);
      int swappedCount = await _getSwappedItemsCount(widget.userId);

      final ratingData = await _getUserRating(widget.userId);

      return {
        'posted': postedCount,
        'borrowed': borrowedCount,
        'sold': soldCount,
        'swapped': swappedCount,
        'rating': ratingData['rating'] ?? 0.0,
        'reviewCount': ratingData['reviewCount'] ?? 0,
      };
    } catch (e) {
      return {
        'posted': 0,
        'borrowed': 0,
        'sold': 0,
        'swapped': 0,
        'rating': 0.0,
        'reviewCount': 0,
      };
    }
  }

  Future<int> _getPostedItemsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.size;
    } catch (e) {
      print('Error getting posted count: $e');
      return 0;
    }
  }

  Future<int> _getSoldItemsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'Sell')
          .where('isSold', isEqualTo: true)
          .get();
      return snapshot.size;
    } catch (e) {
      print('Error getting sold count: $e');
      return 0;
    }
  }

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

  Future<int> _getSwappedItemsCount(String userId) async {
    try {
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
    try {
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
    } catch (e) {
      print('Error getting user rating: $e');
      return {'rating': 0.0, 'reviewCount': 0};
    }
  }

  Stream<Map<String, dynamic>> getUserRatingStream() {
    return _firestore
        .collection('reviews')
        .where('reviewedUserId', isEqualTo: widget.userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return {'rating': 0.0, 'reviews': 0};
          }

          double total = 0;
          int count = 0;

          for (final doc in snapshot.docs) {
            final rating = doc.get('rating');
            if (rating != null) {
              total += (rating is int)
                  ? rating.toDouble()
                  : double.tryParse(rating.toString()) ?? 0.0;
              count++;
            }
          }

          return {'rating': count > 0 ? total / count : 0.0, 'reviews': count};
        });
  }

  Widget _buildStarRating(double rating, {double size = 18.0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (rating >= index + 1) {
          return Icon(Icons.star, color: Colors.orange, size: size);
        } else if (rating > index && rating < index + 1) {
          return Icon(Icons.star_half, color: Colors.orange, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.orange, size: size);
        }
      }),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty || name == 'Unknown User') return 'U';
    final cleanName = name.trim();
    final words = cleanName.split(' ');

    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }
    return (words[0][0] + words[words.length - 1][0]).toUpperCase();
  }

  bool _isCurrentUser() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == widget.userId;
  }

  bool _isMyReview(String reviewerId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == reviewerId;
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditReviewDialog(String reviewId, Map<String, dynamic> reviewData) {
    final TextEditingController commentController = TextEditingController(
      text: reviewData['comment'] ?? '',
    );

    double rating = 1.0;
    final ratingData = reviewData['rating'];
    if (ratingData != null) {
      if (ratingData is int) {
        rating = ratingData.toDouble();
      } else if (ratingData is double) {
        rating = ratingData;
      } else {
        rating = double.tryParse(ratingData.toString()) ?? 1.0;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Review'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rating:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RatingBar(
                initialRating: rating,
                minRating: 0.5,
                maxRating: 5.0,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 32.0,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                ratingWidget: RatingWidget(
                  full: const Icon(Icons.star, color: Colors.orange),
                  half: const Icon(Icons.star_half, color: Colors.orange),
                  empty: const Icon(Icons.star_border, color: Colors.orange),
                ),
                onRatingUpdate: (newRating) {
                  setDialogState(() {
                    rating = newRating;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _firestore.collection('reviews').doc(reviewId).update({
                    'rating': rating,
                    'comment': commentController.text.trim(),
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Review updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating review: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String reviewId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text(
          'Are you sure you want to delete this review? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReview(reviewId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isCurrentUser() ? 'My Profile' : 'User Profile'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: Future.wait([userDataFuture, userStatsFuture]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
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

          final data = snapshot.data?[0] ?? {};
          final stats = snapshot.data?[1] ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.userId)
                          .snapshots(),
                      builder: (context, presenceSnapshot) {
                        final isOnline =
                            presenceSnapshot.hasData &&
                            presenceSnapshot.data?.data() != null &&
                            (presenceSnapshot.data!.data()
                                    as Map<
                                      String,
                                      dynamic
                                    >)['presence']?['online'] ==
                                true;

                        return Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF4A90E2),
                              backgroundImage: _getProfileImage(data),
                              child: _getProfileImage(data) == null
                                  ? Text(
                                      _getInitials(
                                        data['displayName'] ?? 'User',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline ? Colors.green : Colors.grey,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data['displayName'] ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (data['email']?.isNotEmpty == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          data['email'],
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school,
                          color: const Color(0xFF4A90E2),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            data['school'] ?? 'No School Listed',
                            style: const TextStyle(
                              color: Color(0xFF4A90E2),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<Map<String, dynamic>>(
                stream: getUserRatingStream(),
                builder: (context, ratingSnapshot) {
                  final ratingData =
                      ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildStarRating(
                          (ratingData['rating'] ?? 0.0).toDouble(),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (ratingData['rating'] ?? 0.0).toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${ratingData['reviews'] ?? 0} reviews)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statCard(
                          'Posted',
                          stats['posted'] ?? 0,
                          Icons.add_circle_outline,
                        ),
                        _statCard(
                          'Borrowed',
                          stats['borrowed'] ?? 0,
                          Icons.download_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statCard(
                          'Sold',
                          stats['sold'] ?? 0,
                          Icons.attach_money,
                        ),
                        _statCard(
                          'Swapped',
                          stats['swapped'] ?? 0,
                          Icons.swap_horiz,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!_isCurrentUser())
                FutureBuilder<bool>(
                  future: _hasCompletedTransaction(widget.userId),
                  builder: (context, snapshot) {
                    final hasTransaction = snapshot.data ?? false;

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: hasTransaction
                                ? const Color(0xFF4A90E2).withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: hasTransaction
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WriteReviewScreen(
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'You must complete a transaction with this user before writing a review',
                                    ),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              },
                        icon: Icon(
                          hasTransaction ? Icons.rate_review : Icons.lock,
                        ),
                        label: Text(
                          hasTransaction ? 'Write a Review' : 'Review Locked',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasTransaction
                              ? const Color(0xFF4A90E2)
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit Profile feature coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCurrentUser() ? 'My Reviews' : 'Recent Reviews',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildReviewsList(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(String title, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4A90E2), size: 28),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reviews')
          .where('reviewedUserId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildReviewsShimmer();
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Error loading reviews',
              style: TextStyle(color: Colors.red[700]),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.reviews_outlined,
                    size: 48,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCurrentUser()
                        ? 'No reviews yet'
                        : 'No reviews for this user yet',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, idx) {
            final doc = docs[idx];
            final reviewData = _convertToMap(doc.data()) ?? {};
            return buildReviewItem(doc.id, reviewData);
          },
        );
      },
    );
  }

  Future<bool> _hasCompletedTransaction(String targetUserId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return false;

      final userTransactions = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: currentUserId)
          .where('partnerId', isEqualTo: targetUserId)
          .limit(1)
          .get();

      if (userTransactions.docs.isNotEmpty) {
        return true;
      }

      final partnerTransactions = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: targetUserId)
          .where('partnerId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      return partnerTransactions.docs.isNotEmpty;
    } catch (e) {
      print('Error checking transaction history: $e');
      return false;
    }
  }

  Widget buildReviewItem(String reviewId, Map<String, dynamic> review) {
    final reviewerId = review['reviewerId']?.toString();
    final isMyReview = this._isMyReview(reviewerId ?? '');

    return FutureBuilder<DocumentSnapshot>(
      future: reviewerId != null && reviewerId.isNotEmpty
          ? _firestore.collection('users').doc(reviewerId).get()
          : null,
      builder: (context, snapshot) {
        String reviewerName = 'Anonymous';
        Map<String, dynamic>? reviewerData;

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data!.exists) {
          reviewerData = _convertToMap(snapshot.data!.data());
          reviewerName =
              reviewerData?['displayName']?.toString() ?? 'Anonymous';
        }

        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]!
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  isLoading
                      ? ShimmerWidget(
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF4A90E2),
                          backgroundImage: _getProfileImage(reviewerData),
                          child: _getProfileImage(reviewerData) == null
                              ? Text(
                                  _getInitials(reviewerName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviewerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _buildStarRating(
                          _getRatingAsDouble(review['rating']),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  if (isMyReview)
                    PopupMenuButton(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditReviewDialog(reviewId, review);
                        } else if (value == 'delete') {
                          _showDeleteConfirmation(reviewId);
                        }
                      },
                    ),
                ],
              ),
              if (isMyReview) ...[
                const SizedBox(height: 4),
                Text(
                  'Your review',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (review['comment'] != null &&
                  review['comment'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(review['comment'], style: const TextStyle(fontSize: 14)),
              ],
              if (review['timestamp'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatTimestamp(review['timestamp']),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  double _getRatingAsDouble(dynamic ratingData) {
    if (ratingData == null) return 0.0;
    if (ratingData is int) return ratingData.toDouble();
    if (ratingData is double) return ratingData;
    return double.tryParse(ratingData.toString()) ?? 0.0;
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown date';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }
}
