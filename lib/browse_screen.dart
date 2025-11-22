import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'item_detail_screen.dart';
import '../models/offer_item.dart';
import '../services/database_service.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  String _selectedFilter = 'All';
  String _selectedCategory = 'All';
  String _selectedCondition = 'All';
  final TextEditingController _searchController = TextEditingController();
  Position? _currentPosition;
  Stream<List<OfferItem>>? _offersStream;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeOffersStream();
  }

  Future<void> _initializeLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _currentPosition = await Geolocator.getCurrentPosition();
        if (mounted) {
          _initializeOffersStream();
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _initializeOffersStream() {
    setState(() {
      _isLoading = true;
    });
    try {
      GeoPoint? userLocation;
      if (_currentPosition != null) {
        userLocation = GeoPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserId = currentUser?.uid;

      _offersStream =
          DatabaseService.getOffers(
                action: _selectedFilter == 'All' ? null : _selectedFilter,
                category: _selectedCategory == 'All' ? null : _selectedCategory,
                searchQuery: _searchController.text.isEmpty
                    ? null
                    : _searchController.text,
                userLocation: userLocation,
                currentUserId: currentUserId,
              )
              .map((offers) {
                List<OfferItem> filteredOffers = offers;
                if (_selectedCondition != 'All') {
                  filteredOffers = offers
                      .where(
                        (offer) =>
                            offer.condition.toLowerCase() ==
                            _selectedCondition.toLowerCase(),
                      )
                      .toList();
                }
                return filteredOffers;
              })
              .handleError((error) {
                print('Stream error in browse screen: $error');
                return [];
              });
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing offers stream: $e');
      setState(() {
        _isLoading = false;
        _offersStream = Stream.value([]);
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _initializeLocation();
    _initializeOffersStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Browse Items',
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
            icon: Icon(
              Icons.filter_list,
              color: Theme.of(context).iconTheme.color,
            ),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Column(
          children: [
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      onChanged: (value) {
                        setState(() {});
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_searchController.text == value && mounted) {
                            _initializeOffersStream();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search items...',
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.color?.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(
                            context,
                          ).iconTheme.color?.withOpacity(0.6),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Theme.of(
                                    context,
                                  ).iconTheme.color?.withOpacity(0.6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _initializeOffersStream();
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Borrow', 'Sell', 'Swap'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        Color color = Colors.grey;
                        if (filter == 'Borrow') {
                          color = Colors.green;
                        } else if (filter == 'Sell') {
                          color = Colors.orange;
                        } else if (filter == 'Swap') {
                          color = const Color(0xFF4A90E2);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                              _initializeOffersStream();
                            },
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            selectedColor: color.withOpacity(0.2),
                            checkmarkColor: color,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? color
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.grey[700]),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Items List
            Expanded(child: _buildOffersStreamBuilder()),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersStreamBuilder() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<OfferItem>>(
      stream: _offersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('StreamBuilder error: ${snapshot.error}');
          return Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading items',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleRefresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final offers = snapshot.data ?? [];
        if (offers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFilter == 'All'
                        ? 'Try adjusting your search or filters'
                        : 'No $_selectedFilter items available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = 'All';
                        _selectedCategory = 'All';
                        _selectedCondition = 'All';
                        _searchController.clear();
                      });
                      _initializeOffersStream();
                    },
                    child: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return _buildOfferCard(context, offer);
          },
        );
      },
    );
  }

  Widget _buildOfferCard(BuildContext context, OfferItem offer) {
    Color typeColor = _getActionColor(offer.action);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(initialOffer: offer),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Item Image/Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _getCategoryColor(offer.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: offer.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildImage(offer.images.first, offer.category),
                      )
                    : Icon(
                        _getCategoryIcon(offer.category),
                        color: _getCategoryColor(offer.category),
                        size: 40,
                      ),
              ),
              const SizedBox(width: 16),
              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            offer.action,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      offer.userName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Theme.of(
                            context,
                          ).iconTheme.color?.withOpacity(0.6),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          offer.distance,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${offer.category}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getConditionColor(offer.condition),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            offer.condition,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (offer.price != null && offer.price!.isNotEmpty)
                          Text(
                            offer.price!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: offer.action == 'Sell'
                                  ? Colors.green
                                  : typeColor,
                            ),
                          )
                        else
                          Text(
                            offer.action == 'Borrow' ? 'Free' : 'Trade',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl, String category) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final base64String = imageUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (context, error, stackTrace) => Icon(
            _getCategoryIcon(category),
            color: _getCategoryColor(category),
            size: 40,
          ),
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return Icon(
          _getCategoryIcon(category),
          color: _getCategoryColor(category),
          size: 40,
        );
      }
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: 80,
      height: 80,
      errorBuilder: (context, error, stackTrace) => Icon(
        _getCategoryIcon(category),
        color: _getCategoryColor(category),
        size: 40,
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Category Filter
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                          'All',
                          'School Uniforms',
                          'Bags',
                          'Shoes',
                          'Pens',
                          'Art Materials',
                          'Papers',
                          'Others',
                        ]
                        .map(
                          (category) => FilterChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              setModalState(() {
                                _selectedCategory = category;
                              });
                            },
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            selectedColor: const Color(
                              0xFF4A90E2,
                            ).withOpacity(0.2),
                            checkmarkColor: const Color(0xFF4A90E2),
                            labelStyle: TextStyle(
                              color: _selectedCategory == category
                                  ? const Color(0xFF4A90E2)
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[300]
                                        : Colors.grey[700]),
                              fontWeight: _selectedCategory == category
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 24),
              // Condition Filter
              Text(
                'Condition',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'New', 'Like New', 'Good', 'Fair', 'Used']
                    .map(
                      (condition) => FilterChip(
                        label: Text(condition),
                        selected: _selectedCondition == condition,
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedCondition = condition;
                          });
                        },
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        selectedColor: Colors.green.withOpacity(0.2),
                        checkmarkColor: Colors.green,
                        labelStyle: TextStyle(
                          color: _selectedCondition == condition
                              ? Colors.green
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[700]),
                          fontWeight: _selectedCondition == condition
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
              // Reset and Apply buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedCategory = 'All';
                          _selectedCondition = 'All';
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                        _initializeOffersStream();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
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
      case 'Physics':
        return const Color(0xFF4A90E2);
      case 'Mathematics':
        return const Color(0xFF20B2AA);
      case 'Chemistry':
        return Colors.purple;
      case 'Biology':
        return Colors.green;
      case 'History':
        return Colors.brown;
      case 'Literature':
        return Colors.indigo;
      case 'Electronics':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Physics':
        return Icons.science;
      case 'Mathematics':
        return Icons.calculate;
      case 'Chemistry':
        return Icons.biotech;
      case 'Biology':
        return Icons.eco;
      case 'History':
        return Icons.history_edu;
      case 'Literature':
        return Icons.menu_book;
      case 'Electronics':
        return Icons.memory;
      default:
        return Icons.book;
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
