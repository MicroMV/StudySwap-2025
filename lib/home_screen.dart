import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../models/offer_item.dart';
import '../services/database_service.dart';
import 'post_screen.dart';
import 'item_detail_screen.dart';
import 'package:flutter/services.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import 'main_screen.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel;
import 'login.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  Position? _currentPosition;
  Stream<List<OfferItem>>? _offersStream;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _listViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    initializeOffersStream();
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
          initializeOffersStream();
        }
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void initializeOffersStream() {
    setState(() {
      _isLoading = true;
    });

    try {
      // Convert Position to GeoPoint if available
      GeoPoint? userLocation;
      if (_currentPosition != null) {
        userLocation = GeoPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }

      // Get current user ID for filtering
      final currentUser = FirebaseAuth.instance.currentUser;

      // Call DatabaseService.getOffers with updated parameters
      _offersStream = DatabaseService.getOffers(
        action: _selectedFilter == 'All' ? null : _selectedFilter,
        searchQuery: _searchController.text.isEmpty
            ? null
            : _searchController.text,
        userLocation: userLocation,
        currentUserId: currentUser?.uid,
      );

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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(user),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              //if (user != null) _buildWelcomeSection(user),
              // Search Bar
              buildSearchBar(),
              const SizedBox(height: 24),

              buildBannerCarousel(),
              const SizedBox(height: 20),

              // Featured Categories
              _buildFeaturedSection(),
              const SizedBox(height: 32),

              // Filter Section
              _buildFilterSection(),
              const SizedBox(height: 16),

              // Offers List with StreamBuilder
              _buildOffersStreamBuilder(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToPostScreen(context),
        backgroundColor: const Color(0xFF4A90E2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget buildBannerCarousel() {
    final List<Map<String, String>> banners = [
      {
        'image': 'assets/images/banner1.png',
        'title': 'Buy & Sell',
        'subtitle': 'Find great deals on study materials',
      },
      {
        'image': 'assets/images/banner2.png',
        'title': 'Borrow & Lend',
        'subtitle': 'Share resources with your peers',
      },
      {
        'image': 'assets/images/banner3.png',
        'title': 'Swap Items',
        'subtitle': 'Exchange materials you no longer need',
      },
    ];

    return carousel.CarouselSlider(
      options: carousel.CarouselOptions(
        height: 180,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 4),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        autoPlayCurve: Curves.fastOutSlowIn,
        enlargeCenterPage: true,
        viewportFraction: 0.9,
        aspectRatio: 16 / 9,
      ),
      items: banners.map((banner) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF4A90E2), const Color(0xFF357ABD)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Background image
                    Positioned.fill(
                      child: Image.asset(
                        banner['image']!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF4A90E2),
                                  const Color(0xFF357ABD),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Text content
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banner['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            banner['subtitle']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  // StreamBuilder with client-side filtering
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
          return Container(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading offers',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
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

        final allOffers = snapshot.data ?? [];

        // FILTER CLIENT-SIDE instead of reloading from database
        final filteredOffers = _selectedFilter == 'All'
            ? allOffers
            : allOffers
                  .where((offer) => offer.action == _selectedFilter)
                  .toList();

        if (filteredOffers.isEmpty) {
          return Container(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedFilter == 'All'
                        ? 'Try adjusting your search or filters'
                        : 'No $_selectedFilter offers available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          key: _listViewKey,
          controller: _scrollController,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredOffers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final offer = filteredOffers[index];
            return _buildOfferItem(offer);
          },
        );
      },
    );
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

  Widget buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          hintText: 'Search uniforms, bags, shoes, pens...',
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withOpacity(0.5),
          ),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      initializeOffersStream();
                    });
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {});
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_searchController.text == value && mounted) {
              initializeOffersStream();
            }
          });
        },
      ),
    );
  }

  void navigateToFilteredView(BuildContext context, String action) {
    setState(() {
      _selectedFilter = action;
    });
  }

  void _navigateToCategory(String category) {
    _searchController.text = category;
    initializeOffersStream();
  }

  Future<void> _handleRefresh() async {
    await _initializeLocation();
    initializeOffersStream();
  }

  PreferredSizeWidget _buildAppBar(User? user) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        'StudySwap',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      actions: [
        // Dynamic notification badge with real unread count
        StreamBuilder<int>(
          stream: NotificationService.getUnreadNotificationCount(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;

            return IconButton(
              icon: Stack(
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: Theme.of(context).iconTheme.color ?? Colors.white,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => _navigateToNotifications(context),
            );
          },
        ),
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => _showProfileMenu(context, user),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Check if we have data (even old data)
                  if (snapshot.hasData) {
                    final userData =
                        snapshot.data?.data() as Map<String, dynamic>?;
                    final profileImage = _getProfileImage(userData);

                    return CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF4A90E2),
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? _buildDefaultAvatar(user)
                          : null,
                    );
                  }

                  // Only show loading on FIRST load (no data yet)
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[300],
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatar(User user) {
    return Text(
      user.displayName?.isNotEmpty == true
          ? user.displayName![0].toUpperCase()
          : user.email?[0].toUpperCase() ?? 'U',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFeaturedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured Categories',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // First row
        Row(
          children: [
            Expanded(
              child: _buildSubjectCard(
                'School Uniforms',
                const Color(0xFF4A90E2),
                Icons.checkroom,
                () => _navigateToCategory('School Uniforms'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSubjectCard(
                'Bags',
                const Color(0xFF20B2AA),
                Icons.backpack,
                () => _navigateToCategory('Bags'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSubjectCard(
                'Shoes',
                Colors.purple,
                Icons.roller_skating,
                () => _navigateToCategory('Shoes'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row
        Row(
          children: [
            Expanded(
              child: _buildSubjectCard(
                'Pens',
                Colors.orange,
                Icons.edit,
                () => _navigateToCategory('Pens'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSubjectCard(
                'Art Materials',
                Colors.pink,
                Icons.palette,
                () => _navigateToCategory('Art Materials'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSubjectCard(
                'Papers',
                Colors.green,
                Icons.description,
                () => _navigateToCategory('Papers'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubjectCard(
    String subject,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              subject,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build filter section without reinitializing stream
  Widget _buildFilterSection() {
    final filters = ['All', 'Borrow', 'Sell', 'Swap'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nearby Offers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = _selectedFilter == filter;

              return Padding(
                padding: EdgeInsets.only(
                  right: index == filters.length - 1 ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () {
                    // Just update filter without rebuilding stream
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4A90E2)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfferItem(OfferItem offer) {
    final actionColor = _getActionColor(offer.action);

    return GestureDetector(
      onTap: () => _navigateToItemDetails(offer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Item Image/Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(offer.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: offer.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildImage(
                            offer.images.first,
                            offer.category,
                          ),
                        )
                      : Icon(
                          _getCategoryIcon(offer.category),
                          color: _getCategoryColor(offer.category),
                          size: 30,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            offer.distance,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${offer.condition}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    offer.action,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side - User info
                Row(
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(offer.userId)
                          .get(),
                      builder: (context, snapshot) {
                        // Show placeholder while loading
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey[300],
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        // Handle error or no data
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data == null) {
                          return CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFF4A90E2),
                            child: Text(
                              offer.userName.isNotEmpty
                                  ? offer.userName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }

                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>?;

                        // Try to get profile image
                        ImageProvider? profileImage;
                        if (userData != null) {
                          final base64Image = userData['profileImageBase64'];
                          if (base64Image != null &&
                              base64Image is String &&
                              base64Image.isNotEmpty) {
                            try {
                              profileImage = MemoryImage(
                                base64Decode(base64Image),
                              );
                            } catch (e) {
                              print('Error decoding profile image: $e');
                            }
                          }
                        }

                        return CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF4A90E2),
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? Text(
                                  offer.userName.isNotEmpty
                                      ? offer.userName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      offer.userName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),

                // Right side - Price (moved here from top right)
                if (offer.price != null && offer.price!.isNotEmpty)
                  Text(
                    offer.price!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  )
                else if (offer.action == 'Borrow')
                  Text(
                    'Free',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: actionColor,
                    ),
                  )
                else if (offer.action == 'Swap')
                  Text(
                    'Trade',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: actionColor,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build image with base64 support
  Widget _buildImage(String imageUrl, String category) {
    if (imageUrl.startsWith('data:image/')) {
      // Handle base64 images
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
      }
    }

    // Handle network images
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: 60,
      height: 60,
      errorBuilder: (context, error, stackTrace) => Icon(
        _getCategoryIcon(category),
        color: _getCategoryColor(category),
        size: 30,
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
        return Icons.menu_book;
      default:
        return Icons.book;
    }
  }

  // Navigation methods
  void _navigateToPostScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PostScreen()),
    );
  }

  //  Navigate to notifications screen instead of showing SnackBar
  void _navigateToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _navigateToItemDetails(OfferItem offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(initialOffer: offer),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MainScreen(initialTabIndex: 4),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.my_library_books),
              title: const Text('My Offers'),
              onTap: () {
                Navigator.pop(context);
                _navigateToMyOffers(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () => _handleLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    Navigator.pop(context); // Close the confirmation dialog

    try {
      // Set presence offline and sign out (don't await, let them happen in background)
      PresenceService.setOffline();
      FirebaseAuth.instance.signOut();

      // Navigate immediately to login and clear all routes
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  void _navigateToMyOffers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyOffersScreen()),
    );
  }
}

class MyOffersScreen extends StatefulWidget {
  const MyOffersScreen({super.key});

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Offers')),
        body: const Center(child: Text('Please log in to view your offers')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Offers'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PostScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<OfferItem>>(
              stream: DatabaseService.getUserOffers(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  );
                }

                final allOffers = snapshot.data ?? [];

                // Filter out items with completed transactions
                final activeOffers = allOffers.where((offer) {
                  final status = offer.status.toLowerCase();

                  // Check if the main status indicates completion
                  if (status == 'borrowed' ||
                      status == 'sold' ||
                      status == 'swapped' ||
                      status == 'completed') {
                    return false;
                  }

                  // Check action-specific status fields
                  // Check if borrowStatus is completed (for Borrow items)
                  if (offer.borrowStatus?.toLowerCase() == 'completed') {
                    return false;
                  }

                  // Check if sellStatus is completed (for Sell items)
                  if (offer.sellStatus?.toLowerCase() == 'completed') {
                    return false;
                  }

                  // Check if swapStatus is completed (for Swap items)
                  if (offer.swapStatus?.toLowerCase() == 'completed') {
                    return false;
                  }

                  return true;
                }).toList();

                if (activeOffers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 64,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No active offers',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first offer to get started',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PostScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Offer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeOffers.length,
                  itemBuilder: (context, index) {
                    final offer = activeOffers[index];
                    return _buildMyOfferItem(context, offer);
                  },
                );
              },
            ),
    );
  }

  Widget _buildMyOfferItem(BuildContext context, OfferItem offer) {
    final status = offer.status.toLowerCase();
    final isFinalized =
        status == 'borrowed' ||
        status == 'sold' ||
        status == 'swapped' ||
        status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToItemDetails(offer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(offer.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getCategoryColor(
                          offer.category,
                        ).withOpacity(0.2),
                      ),
                    ),
                    child: offer.images.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                _buildImage(offer.images.first, offer.category),
                                if (offer.images.length > 1)
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '+${offer.images.length - 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : Icon(
                            _getCategoryIcon(offer.category),
                            color: _getCategoryColor(offer.category),
                            size: 40,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getActionColor(offer.action),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                offer.action,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getConditionColor(
                                  offer.condition,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getConditionColor(
                                    offer.condition,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                offer.condition,
                                style: TextStyle(
                                  color: _getConditionColor(offer.condition),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (offer.price != null && offer.price!.isNotEmpty)
                          Text(
                            offer.price!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),

                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    onSelected: (value) =>
                        _handleOfferAction(context, offer, value),
                    itemBuilder: (context) => [
                      if (!isFinalized)
                        PopupMenuItem(
                          value: "edit",
                          child: ListTile(
                            leading: Icon(Icons.edit, color: Color(0xFF4A90E2)),
                            title: Text("Edit"),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (!isFinalized)
                        PopupMenuItem(
                          value: offer.isActive ? "Hide" : "Show",
                          child: ListTile(
                            leading: Icon(
                              offer.isActive
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.orange,
                            ),
                            title: Text(offer.isActive ? "Hide" : "Show"),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (!isFinalized)
                        PopupMenuItem(
                          value: "delete",
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text(
                              "Delete",
                              style: TextStyle(color: Colors.red),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Show unavailable overlay for inactive items
              if (!offer.isActive) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.visibility_off,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Unavailable - Hidden from others',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (offer.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  offer.description,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created ${_formatDate(offer.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        offer.isActive
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 16,
                        color: offer.isActive ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        offer.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: offer.isActive ? Colors.green : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced image builder similar to ItemDetailScreen
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
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (context, error, stackTrace) => Icon(
            _getCategoryIcon(category),
            color: _getCategoryColor(category),
            size: 40,
          ),
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
      }
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: 80,
      height: 80,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (context, error, stackTrace) => Icon(
        _getCategoryIcon(category),
        color: _getCategoryColor(category),
        size: 40,
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 80,
          height: 80,
          color: _getCategoryColor(category).withOpacity(0.1),
          child: Center(
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
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} month${difference.inDays ~/ 30 > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _navigateToItemDetails(OfferItem offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailScreen(initialOffer: offer),
      ),
    );
  }

  void _handleOfferAction(
    BuildContext context,
    OfferItem offer,
    String action,
  ) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, offer);
        break;
      case 'delete':
        _showDeleteConfirmation(context, offer);
        break;
      case 'Show':
      case 'Hide':
        _toggleOfferStatus(context, offer);
        break;
    }
  }

  // Enhanced edit dialog similar to ItemDetailScreen
  void _showEditDialog(BuildContext context, OfferItem offer) {
    final titleController = TextEditingController(text: offer.title);
    final descriptionController = TextEditingController(
      text: offer.description,
    );
    final priceController = TextEditingController(
      text: offer.price?.replaceAll('₱', '').trim() ?? '',
    );

    String selectedCondition = offer.condition;
    String selectedAction = offer.action;
    String selectedCategory = offer.category;

    final conditions = ['New', 'Like New', 'Good', 'Fair', 'Used'];
    final actions = ['Borrow', 'Sell', 'Swap'];
    final categories = [
      'School Uniforms',
      'Bags',
      'Shoes',
      'Pens',
      'Art Materials',
      'Papers',
      'Others',
    ];

    if (!categories.contains(selectedCategory)) {
      selectedCategory = categories.first;
    }
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFF4A90E2)),
              const SizedBox(width: 8),
              const Text('Edit Item'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.star_rate),
                  ),
                  items: conditions
                      .map(
                        (condition) => DropdownMenuItem(
                          value: condition,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getConditionColor(condition),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(condition),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedCondition = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAction,
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_offer),
                  ),
                  items: actions
                      .map(
                        (action) => DropdownMenuItem(
                          value: action,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getActionColor(action),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  action,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedAction = value!),
                ),
                if (selectedAction == 'Sell') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      prefixText: '₱ ',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => _saveItemChanges(
                context,
                offer,
                titleController.text,
                descriptionController.text,
                selectedCategory,
                selectedCondition,
                selectedAction,
                priceController.text,
              ),
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveItemChanges(
    BuildContext context,
    OfferItem offer,
    String title,
    String description,
    String category,
    String condition,
    String action,
    String price,
  ) async {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context);
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedData = <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'condition': condition,
        'action': action,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (action == 'Sell' && price.isNotEmpty) {
        updatedData['price'] = '₱$price';
      } else {
        updatedData['price'] = '';
      }

      await DatabaseService.updateOffer(offer.id, updatedData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('"${title.trim()}" updated successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error updating item: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // delete confirmation with better messaging
  void _showDeleteConfirmation(BuildContext context, OfferItem offer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Delete Item'),
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
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: '"${offer.title}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This action cannot be undone',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'All data associated with this item will be permanently removed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => _deleteOffer(context, offer),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // delete function with better success messaging
  Future<void> _deleteOffer(BuildContext context, OfferItem offer) async {
    Navigator.pop(context);

    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseService.deleteOffer(offer.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        TextSpan(
                          text: '"${offer.title}"',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' has been successfully deleted'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'DISMISS',
              textColor: Colors.white,
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to delete "${offer.title}": $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleOfferStatus(BuildContext context, OfferItem offer) async {
    final newStatus = !offer.isActive;
    final action = newStatus ? 'available' : 'unavailable';

    setState(() {
      _isLoading = true;
    });

    try {
      // Update 'items' collection, not 'offers'
      await FirebaseFirestore.instance
          .collection('items') // Changed from 'offers' to 'items'
          .doc(offer.id)
          .update({
            'isActive': newStatus,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        TextSpan(
                          text: '"${offer.title}"',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' is now $action'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error toggling offer status: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error updating status: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Color helper methods
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
      case 'Computer Science':
        return Colors.indigo;
      case 'Engineering':
        return Colors.orange;
      case 'Literature':
        return Colors.brown;
      case 'History':
        return Colors.amber;
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

  Color _getActionColor(String action) {
    switch (action) {
      case 'Borrow':
        return Colors.green;
      case 'Sell':
        return Colors.orange;
      case 'Swap':
        return const Color(0xFF4A90E2);
      case 'Rent':
        return Colors.purple;
      default:
        return Colors.grey;
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

// Extension methods for additional functionality
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }

  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }
}

// Custom widgets that can be reused
class AnimatedActionButton extends StatefulWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const AnimatedActionButton({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.color.withOpacity(0.9)
                    : widget.color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(_isPressed ? 0.2 : 0.3),
                    blurRadius: _isPressed ? 2 : 4,
                    offset: Offset(0, _isPressed ? 1 : 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Loading states and error handling widgets
class LoadingShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const LoadingShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
              colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
            ),
          ),
        );
      },
    );
  }
}

// Custom error widget
class CustomErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String? retryButtonText;

  const CustomErrorWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error,
    this.onRetry,
    this.retryButtonText = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryButtonText!),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionButtonText;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox,
    this.onAction,
    this.actionButtonText = 'Get Started',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          if (onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionButtonText!),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
