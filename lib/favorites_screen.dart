import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/offer_item.dart';
import 'item_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Favorites',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('favorites')
            .where('userId', isEqualTo: currentUserId)
            .orderBy('addedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorWidget();
          }

          final favorites = snapshot.data?.docs ?? [];
          if (favorites.isEmpty) {
            return _buildEmptyWidget();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite = favorites[index].data() as Map<String, dynamic>;
              return _buildFavoriteCard(favorite);
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> favorite) {
    final itemId = favorite['itemId'];
    final itemTitle = favorite['itemTitle'] ?? 'Unknown Item';
    final itemAction = favorite['itemAction'] ?? 'Unknown';
    final itemCategory = favorite['itemCategory'] ?? 'Others';
    final itemPrice = favorite['itemPrice'] ?? '';
    final itemCondition = favorite['itemCondition'] ?? 'Unknown';
    final itemDistance = favorite['itemDistance'] ?? 'Unknown';
    final itemUserName = favorite['itemUserName'] ?? 'Unknown User';
    final addedAt = favorite['addedAt'] as Timestamp?;
    final itemImages = List<String>.from(favorite['itemImages'] ?? []);

    Color actionColor = _getActionColor(itemAction);
    Color categoryColor = _getCategoryColor(itemCategory);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('transactions')
          .where('itemId', isEqualTo: itemId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .snapshots(),
      builder: (context, transactionSnapshot) {
        final isActive =
            !transactionSnapshot.hasData ||
            (transactionSnapshot.data?.docs.isEmpty ?? true);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (!isActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text('This item is no longer available'),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                _navigateToItemDetail(favorite);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: categoryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: itemImages.isNotEmpty
                              ? _buildItemImage(itemImages[0], itemCategory)
                              : Icon(
                                  _getCategoryIcon(itemCategory),
                                  color: categoryColor,
                                  size: 30,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itemTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'by $itemUserName',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                            if (itemPrice.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                itemPrice,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: itemAction == 'Sell'
                                      ? Colors.green
                                      : actionColor,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildDetailChip(
                                  Icons.star_rate,
                                  itemCondition,
                                  _getConditionColor(itemCondition),
                                ),
                                const SizedBox(width: 6),
                                _buildDetailChip(
                                  Icons.location_on,
                                  itemDistance,
                                  Colors.blue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _removeFromFavorites(favorite),
                          ),
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: actionColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              itemAction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isActive) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Colors.red[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Unavailable',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (addedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Added ${_formatTimestamp(addedAt.toDate())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemImage(String imageUrl, String category) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
          errorBuilder: (context, error, stackTrace) => Icon(
            _getCategoryIcon(category),
            color: _getCategoryColor(category),
            size: 30,
          ),
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return Icon(
          _getCategoryIcon(category),
          color: _getCategoryColor(category),
          size: 30,
        );
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: 60,
      height: 60,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: _getCategoryColor(category),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Icon(
        _getCategoryIcon(category),
        color: _getCategoryColor(category),
        size: 30,
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[600]
                : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the heart icon on items you love\nto add them to your favorites',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error loading favorites'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromFavorites(Map<String, dynamic> favorite) async {
    final itemId = favorite['itemId'];
    final favoriteId = '${currentUserId}_$itemId';
    try {
      await _firestore.collection('favorites').doc(favoriteId).delete();
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing favorite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToItemDetail(Map<String, dynamic> favorite) {
    final itemImages = List<String>.from(favorite['itemImages'] ?? []);
    final offerItem = OfferItem(
      id: favorite['itemId'] ?? '',
      title: favorite['itemTitle'] ?? '',
      description: favorite['itemDescription'] ?? '',
      price: favorite['itemPrice'],
      category: favorite['itemCategory'] ?? 'Others',
      condition: favorite['itemCondition'] ?? 'Unknown',
      action: favorite['itemAction'] ?? 'Sell',
      images: itemImages,
      imageCount: itemImages.length,
      userId: favorite['itemUserId'] ?? '',
      userName: favorite['itemUserName'] ?? '',
      userEmail: favorite['itemUserEmail'] ?? '',
      status: favorite['itemStatus'] ?? 'available',
      createdAt: favorite['itemCreatedAt'] != null
          ? (favorite['itemCreatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: favorite['itemIsActive'] ?? true,
      distance: favorite['itemDistance'] ?? 'Unknown',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(initialOffer: offerItem),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
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
