import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'chat_screen.dart';
import 'user_profile_screen.dart';
import '../models/offer_item.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import 'package:intl/intl.dart';
import '../services/messaging_service.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/presence_service.dart';
import 'dart:async';

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

String formatTime12Hour(DateTime dateTime) {
  final DateFormat formatter = DateFormat('hh:mm a');
  return formatter.format(dateTime);
}

String formatDateTime12Hour(DateTime dateTime) {
  final DateFormat formatter = DateFormat('MMM d, yyyy hh:mm a');
  return formatter.format(dateTime);
}

class ItemDetailScreen extends StatefulWidget {
  final OfferItem initialOffer;

  const ItemDetailScreen({super.key, required this.initialOffer});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late OfferItem offer;
  bool _isLoading = false;
  bool _isFavorite = false;
  bool _isFavoriteLoading = false;
  // Presence tracking
  StreamSubscription<DocumentSnapshot>? _presenceSubscription;
  bool _isOwnerOnline = false;

  @override
  void initState() {
    super.initState();
    offer = widget.initialOffer;
    _checkFavoriteStatus();
    _listenToOwnerPresence();
  }

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    super.dispose();
  }

  // Check if item is in user's favorites
  Future<void> _checkFavoriteStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _isOwner()) return;

    try {
      final favoriteDoc = await FirebaseFirestore.instance
          .collection('favorites')
          .doc('${currentUser.uid}_${offer.id}')
          .get();

      if (mounted) {
        setState(() {
          _isFavorite = favoriteDoc.exists;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  // Listen to owner's presence status
  void _listenToOwnerPresence() {
    // Don't track presence for own items
    if (_isOwner()) return;

    _presenceSubscription = PresenceService.presenceStream(offer.userId).listen(
      (snapshot) {
        if (!mounted || !snapshot.exists) return;

        final data = snapshot.data();
        if (data == null) return;

        final presence = data['presence'] as Map<String, dynamic>?;
        if (presence == null) return;

        setState(() {
          _isOwnerOnline = presence['online'] == true;
          final lastSeenTimestamp = presence['lastSeen'];
          if (lastSeenTimestamp is Timestamp) {}
        });
      },
    );
  }

  // Toggle favorite status
  Future<void> _toggleFavorite() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _isOwner()) return;

    setState(() {
      _isFavoriteLoading = true;
    });

    try {
      final favoriteId = '${currentUser.uid}_${offer.id}';
      final favoriteRef = FirebaseFirestore.instance
          .collection('favorites')
          .doc(favoriteId);

      if (_isFavorite) {
        // Remove from favorites
        await favoriteRef.delete();
        setState(() {
          _isFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.heart_broken, color: Colors.white),
                SizedBox(width: 8),
                Text('Removed from favorites'),
              ],
            ),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Add to favorites
        await favoriteRef.set({
          'userId': currentUser.uid,
          'itemId': offer.id,
          'itemTitle': offer.title,
          'itemAction': offer.action,
          'itemCategory': offer.category,
          'itemPrice': offer.price,
          'itemCondition': offer.condition,
          'itemDistance': offer.distance,
          'itemDescription': offer.description,
          'itemImages': offer.images,
          'itemUserEmail': offer.userEmail,
          'itemStatus': offer.status,
          'itemUserId': offer.userId,
          'itemUserName': offer.userName,
          'itemCreatedAt': offer.createdAt,
          'itemIsActive': offer.isActive,
          'addedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isFavorite = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.favorite, color: Colors.white),
                SizedBox(width: 8),
                Text('Added to favorites'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() {
        _isFavoriteLoading = false;
      });
    }
  }

  // Method to refresh offer data from database
  Future<void> _refreshOfferData() async {
    try {
      final updatedOffers = await DatabaseService.getOffers().first;
      final updatedOffer = updatedOffers.firstWhere(
        (o) => o.id == offer.id,
        orElse: () => offer,
      );
      if (mounted) {
        setState(() {
          offer = updatedOffer;
        });
      }
    } catch (e) {
      print('Error refreshing offer data: $e');
    }
  }

  // Helper method to safely convert Object? to Map
  Map<String, dynamic>? _convertToMap(Object? data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map<String, Object?>) return Map<String, dynamic>.from(data);
    return null;
  }

  //  Helper method to safely get rating as double
  double _getRatingAsDouble(dynamic ratingData) {
    if (ratingData == null) return 0.0;
    if (ratingData is int) return ratingData.toDouble();
    if (ratingData is double) return ratingData;
    return double.tryParse(ratingData.toString()) ?? 0.0;
  }

  // Star rating display widget
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

  // Format timestamp
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

  //  Build seller reviews section
  Widget _buildSellerReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Recent Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        UserProfileScreen(userId: offer.userId),
                  ),
                );
              },
              child: Text(
                'View all',
                style: TextStyle(
                  color: _getActionColor(offer.action),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reviews')
              .where('reviewedUserId', isEqualTo: offer.userId)
              .orderBy('timestamp', descending: true)
              .limit(3)
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    const Text('Error loading reviews'),
                  ],
                ),
              );
            }

            final reviews = snapshot.data?.docs ?? [];

            if (reviews.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.star_border, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No reviews yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Be the first to review ${offer.userName}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: reviews.take(2).map((doc) {
                final review = doc.data() as Map<String, dynamic>;
                return _buildReviewCard(review);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  //  Build individual review card
  Widget _buildReviewCard(Map<String, dynamic> review) {
    final reviewerId = review['reviewerId']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: FutureBuilder<DocumentSnapshot>(
        future: reviewerId.isNotEmpty
            ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(reviewerId)
                  .get()
            : null,
        builder: (context, snapshot) {
          // Use the helper method
          final userData = _convertToMap(snapshot.data?.data());
          final reviewerName = userData?['displayName'] ?? 'Anonymous';
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  isLoading
                      ? ShimmerWidget(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: _getActionColor(offer.action),
                          backgroundImage: _getProfileImage(userData ?? {}),
                          child: _getProfileImage(userData ?? {}) == null
                              ? Text(
                                  reviewerName.isNotEmpty
                                      ? reviewerName[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                        ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isLoading
                            ? ShimmerWidget(
                                child: Container(
                                  width: 100,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              )
                            : Text(
                                reviewerName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        const SizedBox(height: 2),

                        _buildStarRating(
                          _getRatingAsDouble(review['rating']),
                          size: 14,
                        ),
                      ],
                    ),
                  ),

                  Text(
                    _formatTimestamp(review['timestamp']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),

              if (review['comment']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  review['comment'].toString(),
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  //Build reviews shimmer
  Widget _buildReviewsShimmer() {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ShimmerWidget(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 80,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build presence badge
  Widget _buildPresenceBadge() {
    if (_isOwner()) return const SizedBox.shrink();

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _isOwnerOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    Color typeColor = _getActionColor(offer.action);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          offer.title,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
          //Smart favorite button - only show for non-owners
          if (!_isOwner())
            IconButton(
              icon: _isFavoriteLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    )
                  : Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : Colors.grey,
                    ),
              onPressed: _isFavoriteLoading ? null : _toggleFavorite,
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Link Copied')));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshOfferData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Image Section
                    Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(
                          offer.category,
                        ).withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: offer.images.isNotEmpty
                          ? Stack(
                              children: [
                                PageView.builder(
                                  itemCount: offer.images.length,
                                  itemBuilder: (context, index) => _buildImage(
                                    context,
                                    offer.images[index],
                                    offer.category,
                                    index,
                                  ),
                                ),
                                // Image indicator dots
                                if (offer.images.length > 1)
                                  Positioned(
                                    bottom: 16,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        offer.images.length,
                                        (index) => Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Unavailable overlay for owner
                                if (!offer.isActive && _isOwner())
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(24),
                                          bottomRight: Radius.circular(24),
                                        ),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.visibility_off,
                                              color: Colors.white,
                                              size: 48,
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'UNAVAILABLE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'This item is hidden from other users',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Center(
                              child: Icon(
                                _getCategoryIcon(offer.category),
                                size: 120,
                                color: _getCategoryColor(offer.category),
                              ),
                            ),
                    ),

                    // Content Section
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and Type
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  offer.title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  offer.action,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Price Section
                          if (offer.price != null &&
                              offer.price!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Text(
                                  'Price: ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  offer.price!,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: offer.action == 'Sell'
                                        ? Colors.green
                                        : typeColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            Text(
                              offer.action == 'Borrow'
                                  ? 'Available for Free Borrowing'
                                  : offer.action == 'Swap'
                                  ? 'Available for Trade'
                                  : 'Contact for Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Details Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  'Condition',
                                  offer.condition,
                                  _getConditionColor(offer.condition),
                                  Icons.star_rate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  'Category',
                                  offer.category,
                                  _getCategoryColor(offer.category),
                                  _getCategoryIcon(offer.category),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInfoCard(
                            'Distance',
                            offer.distance,
                            Colors.blue,
                            Icons.location_on,
                            isFullWidth: true,
                          ),
                          const SizedBox(height: 24),

                          // Description
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor, // Changed
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              offer.description.isNotEmpty
                                  ? offer.description
                                  : 'No description provided.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                height: 1.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Owner Information
                          const Text(
                            'Posted by',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              if (!_isOwner()) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        UserProfileScreen(userId: offer.userId),
                                  ),
                                );
                              }
                            },

                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),

                              child: Row(
                                children: [
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(offer.userId)
                                        .get(),
                                    builder: (context, snapshot) {
                                      final userData = _convertToMap(
                                        snapshot.data?.data(),
                                      );
                                      final isLoading =
                                          snapshot.connectionState ==
                                          ConnectionState.waiting;

                                      return isLoading
                                          ? ShimmerWidget(
                                              child: Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            )
                                          : Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                CircleAvatar(
                                                  radius: 25,
                                                  backgroundColor: typeColor,
                                                  backgroundImage:
                                                      _getProfileImage(
                                                        userData ?? {},
                                                      ),
                                                  child:
                                                      _getProfileImage(
                                                            userData ?? {},
                                                          ) ==
                                                          null
                                                      ? Text(
                                                          (offer
                                                                  .userName
                                                                  .isNotEmpty)
                                                              ? offer
                                                                    .userName[0]
                                                                    .toUpperCase()
                                                              : 'U',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 18,
                                                              ),
                                                        )
                                                      : null,
                                                ),

                                                if (!_isOwner())
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child:
                                                        _buildPresenceBadge(),
                                                  ),
                                              ],
                                            );
                                    },
                                  ),

                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                offer.userName.isNotEmpty
                                                    ? offer.userName
                                                    : 'Anonymous User',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (!_isOwner()) ...[
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey[400],
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Posted: ${offer.createdAt != null ? formatDateTime12Hour(offer.createdAt!) : "Recently"}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),

                                        if (!_isOwner())
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              _isOwnerOnline
                                                  ? 'Active now'
                                                  : 'Offline',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _isOwnerOnline
                                                    ? Colors.green
                                                    : Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        if (!_isOwner())
                                          Text(
                                            'Tap to view profile',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // User Reviews Section (only show for non-owners)
                          if (!_isOwner()) ...[
                            const SizedBox(height: 24),
                            _buildSellerReviewsSection(),
                          ],

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomActions(context, typeColor),
    );
  }

  bool _isOwner() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid == offer.userId;
  }

  Widget _buildImage(
    BuildContext context,
    String imageUrl,
    String category,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _showImageGallery(context, offer.images, index),
      child: Hero(
        tag: 'image_${offer.id}_$index',
        child: Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: _buildImageWidget(imageUrl, category),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl, String category) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 300,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildErrorWidget(category),
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return _buildErrorWidget(category);
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: 300,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(category),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: 300,
          color: _getCategoryColor(category).withOpacity(0.1),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 3,
                  color: _getCategoryColor(category),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading image...',
                  style: TextStyle(
                    color: _getCategoryColor(category),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String category) {
    return Container(
      width: double.infinity,
      height: 300,
      color: _getCategoryColor(category).withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(category),
              size: 80,
              color: _getCategoryColor(category).withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Image not available',
              style: TextStyle(
                color: _getCategoryColor(category).withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageGallery(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageGalleryScreen(
          images: images,
          initialIndex: initialIndex,
          title: offer.title,
          offerId: offer.id,
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, Color typeColor) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == offer.userId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),

      child: isOwner
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'This is your item',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToMyOffers(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: typeColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.my_library_books,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Go to My Offers',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    _openChatWithSeller(context, offer.action.toLowerCase()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getContactIcon(offer.action),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getContactText(offer.action),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _navigateToMyOffers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyOffersScreen()),
    );
  }

  // Transaction record creation method
  Future<void> _createTransactionRecord({
    required String itemId,
    required String itemTitle,
    required String itemType,
    required String requesterId,
    required String requesterName,
    required String sellerId,
    required String sellerName,
    required String conversationId,
    double? price,
    DateTime? deadline,
  }) async {
    try {
      // Create transaction record for requester
      final requesterTransactionId = FirebaseFirestore.instance
          .collection('transactions')
          .doc()
          .id;
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(requesterTransactionId)
          .set({
            'transactionId': requesterTransactionId,
            'userId': requesterId,
            'type': itemType.toLowerCase(),
            'status': 'pending',
            'role': 'requester',
            'itemId': itemId,
            'itemTitle': itemTitle,
            'itemType': itemType,
            'otherUserId': sellerId,
            'otherUserName': sellerName,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'conversationId': conversationId,
            if (price != null) 'amount': price,
            if (deadline != null) 'deadline': Timestamp.fromDate(deadline),
          });

      // Create transaction record for provider (seller/lender)
      final providerTransactionId = FirebaseFirestore.instance
          .collection('transactions')
          .doc()
          .id;
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(providerTransactionId)
          .set({
            'transactionId': providerTransactionId,
            'userId': sellerId,
            'type': itemType.toLowerCase(),
            'status': 'pending',
            'role': 'provider',
            'itemId': itemId,
            'itemTitle': itemTitle,
            'itemType': itemType,
            'otherUserId': requesterId,
            'otherUserName': requesterName,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'conversationId': conversationId,
            if (price != null) 'amount': price,
            if (deadline != null) 'deadline': Timestamp.fromDate(deadline),
          });

      print('✅ Transaction records created for both users');
    } catch (e) {
      print('❌ Error creating transaction records: $e');
    }
  }

  // Open chat and create transaction record
  Future<void> _openChatWithSeller(
    BuildContext context,
    String intentType,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    if (!offer.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is no longer available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await _showRequestConfirmationDialog(context);
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final requestMessage =
          '${_getRequestMessage(offer.action)} "${offer.title}"';
      final conversationId =
          await MessagingService.startConversationWithRequest(
            receiverId: offer.userId,
            itemId: offer.id,
            itemTitle: offer.title,
            itemType: offer.action,
            requestMessage: requestMessage,
          );

      final requesterName =
          currentUser.displayName ??
          currentUser.email?.split('@')[0] ??
          'Someone';

      // Create transaction record AFTER conversation is created
      await _createTransactionRecord(
        itemId: offer.id,
        itemTitle: offer.title,
        itemType: offer.action,
        requesterId: currentUser.uid,
        requesterName: requesterName,
        sellerId: offer.userId,
        sellerName: offer.userName,
        conversationId: conversationId,
        price: double.tryParse(offer.price ?? ''),
      );

      // Send notifications
      switch (offer.action.toLowerCase()) {
        case 'borrow':
          await NotificationService.sendBorrowRequestNotification(
            receiverUserId: offer.userId,
            itemTitle: offer.title,
            requesterName: requesterName,
            conversationId: conversationId,
          );
          break;
        case 'sell':
          await NotificationService.sendSellRequestNotification(
            receiverUserId: offer.userId,
            itemTitle: offer.title,
            requesterName: requesterName,
            conversationId: conversationId,
          );
          break;
        case 'swap':
          await NotificationService.sendSwapRequestNotification(
            receiverUserId: offer.userId,
            itemTitle: offer.title,
            requesterName: requesterName,
            conversationId: conversationId,
          );
          break;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${offer.action} request sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            otherUserName: offer.userName,
            otherUserId: offer.userId,
            otherUserSchool: 'University',
            itemTitle: offer.title,
            itemType: offer.action,
          ),
        ),
      );
    } catch (e) {
      print('Conversation creation error: $e');
      String errorMessage = 'Failed to send request. Please try again.';
      if (e.toString().contains('pending request')) {
        errorMessage = e.toString().replaceFirst(
          'Exception: Failed to start conversation with request: ',
          '',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getRequestMessage(String action) {
    switch (action.toLowerCase()) {
      case 'borrow':
        return 'Hi! I would like to borrow';
      case 'sell':
        return 'Hi! I would like to buy';
      case 'swap':
        return 'Hi! I would like to trade for';
      default:
        return 'Hi! I am interested in';
    }
  }

  // Show confirmation dialog before sending request
  Future<bool> _showRequestConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  _getContactIcon(offer.action),
                  color: _getActionColor(offer.action),
                ),
                const SizedBox(width: 8),
                Text('${offer.action} Request'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    children: [
                      TextSpan(
                        text:
                            'Send a ${offer.action.toLowerCase()} request for ',
                      ),
                      TextSpan(
                        text: '"${offer.title}"',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' to ${offer.userName}?'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getActionColor(offer.action).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getActionColor(offer.action).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: _getActionColor(offer.action),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The owner will be notified and can accept or decline your request.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getActionColor(
                              offer.action,
                            ).withOpacity(0.8),
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
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getActionColor(offer.action),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Request'),
              ),
            ],
          ),
        ) ??
        false;
  }

  IconData _getContactIcon(String action) {
    switch (action) {
      case 'Borrow':
        return Icons.chat_bubble;
      case 'Sell':
        return Icons.chat_bubble;
      case 'Swap':
        return Icons.chat_bubble;
      default:
        return Icons.chat_bubble;
    }
  }

  String _getContactText(String action) {
    switch (action) {
      case 'Borrow':
        return 'Contact to Borrow';
      case 'Sell':
        return 'Contact to Buy';
      case 'Swap':
        return 'Contact to Swap';
      default:
        return 'Contact Seller';
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'Borrow':
        return Colors.green;
      case 'Sell':
        return Colors.orange;
      case 'Swap':
        return const Color(0xFF4A90E2);
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'School Uniforms':
        return const Color(0xFF4A90E2);
      case 'Bags':
        return const Color(0xFF20B2AA);
      case 'Shoes':
        return Colors.purple;
      case 'Pens':
        return Colors.orange;
      case 'Art Materials':
        return Colors.pink;
      case 'Papers':
        return Colors.green;
      case 'Others':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'School Uniforms':
        return Icons.checkroom;
      case 'Bags':
        return Icons.backpack;
      case 'Shoes':
        return Icons.roller_skating;
      case 'Pens':
        return Icons.edit;
      case 'Art Materials':
        return Icons.palette;
      case 'Papers':
        return Icons.description;
      case 'Others':
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'New':
        return Colors.green;
      case 'Like New':
        return Colors.lightGreen;
      case 'Good':
        return Colors.orange;
      case 'Fair':
        return Colors.deepOrange;
      case 'Used':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Image Gallery Screen
class ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;
  final String offerId;

  const ImageGalleryScreen({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.title,
    required this.offerId,
  });

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Link Copied')));
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Center(
                child: Hero(
                  tag: 'image_${widget.offerId}_$index',
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _buildFullScreenImage(widget.images[index]),
                  ),
                ),
              );
            },
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullScreenImage(String imageUrl) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.white, size: 64),
                SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.white, size: 64),
              SizedBox(height: 16),
              Text(
                'Invalid image format',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        );
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'Failed to load image',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading high quality image...',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}
