import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:convert';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

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

class _ReviewsScreenState extends State<ReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Reviews',
          style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4A90E2),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Reviews I Wrote'),
            Tab(text: 'Reviews About Me'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMyReviews(), _buildReviewsAboutMe()],
      ),
    );
  }

  Widget _buildMyReviews() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reviews')
          .where('reviewerId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget('Error loading your reviews');
        }

        final reviews = snapshot.data?.docs ?? [];

        if (reviews.isEmpty) {
          return _buildEmptyWidget(
            'No reviews written yet',
            'Reviews you write about others will appear here',
            Icons.edit_note,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index].data() as Map<String, dynamic>;
            final reviewId = reviews[index].id;
            return _buildMyReviewCard(reviewId, review);
          },
        );
      },
    );
  }

  Widget _buildReviewsAboutMe() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reviews')
          .where('reviewedUserId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget('Error loading reviews about you');
        }

        final reviews = snapshot.data?.docs ?? [];

        if (reviews.isEmpty) {
          return _buildEmptyWidget(
            'No reviews yet',
            'Reviews others write about you will appear here',
            Icons.star_border,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index].data() as Map<String, dynamic>;
            return _buildReviewAboutMeCard(review);
          },
        );
      },
    );
  }

  Widget _buildMyReviewCard(String reviewId, Map<String, dynamic> review) {
    final reviewedUserId = review['reviewedUserId']?.toString() ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: reviewedUserId.isNotEmpty
          ? _firestore.collection('users').doc(reviewedUserId).get()
          : null,
      builder: (context, snapshot) {
        String reviewedUserName = 'Unknown User';
        bool isLoading = snapshot.connectionState != ConnectionState.done;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = _convertToMap(snapshot.data!.data());
          reviewedUserName =
              userData?['displayName']?.toString() ?? 'Unknown User';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]!
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  isLoading
                      ? ShimmerWidget(
                          child: _buildShimmerContainer(
                            width: 40,
                            height: 40,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        )
                      : CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue[400],
                          backgroundImage:
                              snapshot.hasData && snapshot.data!.exists
                              ? _getProfileImage(
                                  _convertToMap(snapshot.data!.data()),
                                )
                              : null,
                          child:
                              (snapshot.hasData &&
                                  snapshot.data!.exists &&
                                  _getProfileImage(
                                        _convertToMap(snapshot.data!.data()),
                                      ) ==
                                      null)
                              ? Text(
                                  reviewedUserName.isNotEmpty &&
                                          reviewedUserName != 'Unknown User'
                                      ? reviewedUserName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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
                                child: _buildShimmerContainer(
                                  width: 150,
                                  height: 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            : Text(
                                'Review for $reviewedUserName',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        const SizedBox(height: 8),
                        isLoading
                            ? ShimmerWidget(
                                child: Row(
                                  children: List.generate(
                                    5,
                                    (index) => Padding(
                                      padding: const EdgeInsets.only(right: 2),
                                      child: _buildShimmerContainer(
                                        width: 16,
                                        height: 16,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : _buildStarRating(
                                _getRatingAsDouble(review['rating']),
                                size: 18,
                              ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
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
              if (review['comment']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    review['comment'].toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _formatTimestamp(review['timestamp']),
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewAboutMeCard(Map<String, dynamic> review) {
    final reviewerId = review['reviewerId']?.toString() ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: reviewerId.isNotEmpty
          ? _firestore.collection('users').doc(reviewerId).get()
          : null,
      builder: (context, snapshot) {
        String reviewerName = 'Anonymous';
        bool isLoading = snapshot.connectionState != ConnectionState.done;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = _convertToMap(snapshot.data!.data());
          reviewerName = userData?['displayName']?.toString() ?? 'Anonymous';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[700]!
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  isLoading
                      ? ShimmerWidget(
                          child: _buildShimmerContainer(
                            width: 40,
                            height: 40,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        )
                      : CircleAvatar(
                          radius: 20,
                          backgroundColor: _getRandomColor(reviewerName),
                          backgroundImage:
                              snapshot.hasData && snapshot.data!.exists
                              ? _getProfileImage(
                                  _convertToMap(snapshot.data!.data()),
                                )
                              : null,
                          child:
                              (snapshot.hasData &&
                                  snapshot.data!.exists &&
                                  _getProfileImage(
                                        _convertToMap(snapshot.data!.data()),
                                      ) ==
                                      null)
                              ? Text(
                                  reviewerName.isNotEmpty &&
                                          reviewerName != 'Anonymous'
                                      ? reviewerName[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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
                                child: _buildShimmerContainer(
                                  width: 120,
                                  height: 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            : Text(
                                reviewerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        const SizedBox(height: 8),
                        isLoading
                            ? ShimmerWidget(
                                child: Row(
                                  children: List.generate(
                                    5,
                                    (index) => Padding(
                                      padding: const EdgeInsets.only(right: 2),
                                      child: _buildShimmerContainer(
                                        width: 16,
                                        height: 16,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : _buildStarRating(
                                _getRatingAsDouble(review['rating']),
                                size: 18,
                              ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getRatingColor(
                        _getRatingAsDouble(review['rating']),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_getRatingAsDouble(review['rating']).toStringAsFixed(1)}/5',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (review['comment']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    review['comment'].toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                _formatTimestamp(review['timestamp']),
                style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditReviewDialog(String reviewId, Map<String, dynamic> reviewData) {
    final TextEditingController commentController = TextEditingController(
      text: reviewData['comment']?.toString() ?? '',
    );
    double rating = _getRatingAsDouble(reviewData['rating']);

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
                  labelText: 'Comment (optional)',
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
              onPressed: () =>
                  _updateReview(reviewId, rating, commentController.text),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateReview(
    String reviewId,
    double rating,
    String comment,
  ) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'rating': rating,
        'comment': comment.trim(),
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

  Widget _buildEmptyWidget(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _convertToMap(Object? data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
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
      if (difference.inDays > 7) {
        return DateFormat('MMM d, yyyy').format(date);
      } else if (difference.inDays > 0) {
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

  Widget _buildStarRating(double rating, {double size = 20}) {
    return RatingBarIndicator(
      rating: rating,
      itemBuilder: (context, index) =>
          const Icon(Icons.star, color: Colors.amber),
      itemCount: 5,
      itemSize: size,
      direction: Axis.horizontal,
    );
  }

  Color _getRandomColor(String name) {
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.red[400]!,
      Colors.teal[400]!,
    ];
    return colors[name.hashCode % colors.length];
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.orange;
    if (rating >= 2.0) return Colors.deepOrange;
    return Colors.red;
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
}
