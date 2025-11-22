import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/offer_item.dart';
import 'dart:math';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create offer method
  static Future<void> createOffer({
    required String title,
    required String action,
    required String category,
    required String? price,
    required String condition,
    required String description,
    required GeoPoint? location,
  }) async {
    try {
      CollectionReference items = _firestore.collection('items');
      await items.add({
        'title': title,
        'action': action,
        'category': category,
        'price': price,
        'condition': condition,
        'description': description,
        'location': location,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    } catch (e) {
      throw Exception('Error creating offer: $e');
    }
  }

  // Get offers method with proper distance calculation
  static Stream<List<OfferItem>> getOffers({
    String? action,
    String? searchQuery,
    GeoPoint? userLocation,
    String? currentUserId,
    String? category,
  }) {
    print('🔍 getOffers called with:');
    print('   - action: $action');
    print('   - category: $category');
    print('   - searchQuery: $searchQuery');
    print(
      '   - userLocation: ${userLocation != null ? "${userLocation.latitude}, ${userLocation.longitude}" : "NULL"}',
    );
    print('   - currentUserId: $currentUserId');

    try {
      Query query = _firestore.collection('items');

      // Filter by action if specified
      if (action != null && action != 'All') {
        query = query.where('action', isEqualTo: action);
      }

      // Filter by category if specified
      if (category != null && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }

      // Filter by active status
      query = query.where('isActive', isEqualTo: true);

      // Order by creation date (newest first)
      query = query.orderBy('createdAt', descending: true);

      return query.snapshots().map((snapshot) {
        print('📦 Received ${snapshot.docs.length} items from Firestore');
        List<OfferItem> offers = [];

        for (var doc in snapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            // Add document ID to data
            data['id'] = doc.id;

            print('📄 Processing item: ${data['title']} (${doc.id})');

            // Skip user's own items
            if (currentUserId != null && data['userId'] == currentUserId) {
              print('   ⏭️ SKIPPED: Own item');
              continue;
            }

            // Search filter (if provided)
            if (searchQuery != null && searchQuery.isNotEmpty) {
              String title = (data['title'] ?? '').toString().toLowerCase();
              String description = (data['description'] ?? '')
                  .toString()
                  .toLowerCase();
              String cat = (data['category'] ?? '').toString().toLowerCase();
              String search = searchQuery.toLowerCase();

              if (!title.contains(search) &&
                  !description.contains(search) &&
                  !cat.contains(search)) {
                print('   ⏭️ SKIPPED: Doesn\'t match search');
                continue;
              }
            }

            // Calculate distance if user location is available
            if (userLocation != null && data['location'] != null) {
              try {
                final itemLocation = data['location'] as GeoPoint;

                print(
                  '   📍 User location: ${userLocation.latitude}, ${userLocation.longitude}',
                );
                print(
                  '   📍 Item location: ${itemLocation.latitude}, ${itemLocation.longitude}',
                );

                // Calculate distance using Haversine formula
                final distanceInMeters = _calculateDistance(
                  userLocation.latitude,
                  userLocation.longitude,
                  itemLocation.latitude,
                  itemLocation.longitude,
                );

                print('   📏 Distance calculated: $distanceInMeters meters');

                // Format distance
                final distanceInKm = distanceInMeters / 1000;
                if (distanceInKm < 1) {
                  data['distance'] =
                      '${(distanceInKm * 1000).toStringAsFixed(0)} m';
                } else if (distanceInKm < 10) {
                  data['distance'] = '${distanceInKm.toStringAsFixed(1)} km';
                } else {
                  data['distance'] = '${distanceInKm.toStringAsFixed(0)} km';
                }

                print('   ✅ Formatted distance: ${data['distance']}');

                // Store numeric distance for sorting
                data['_distanceValue'] = distanceInMeters;
              } catch (e) {
                print('   ❌ Error calculating distance for ${doc.id}: $e');
                data['distance'] = 'Unknown';
                data['_distanceValue'] = double.infinity;
              }
            } else {
              print('   ⚠️ Missing location data:');
              print(
                '      - userLocation: ${userLocation != null ? "Available" : "NULL"}',
              );
              print(
                '      - itemLocation: ${data['location'] != null ? "Available (${data['location']})" : "NULL"}',
              );
              data['distance'] = 'Unknown';
              data['_distanceValue'] = double.infinity;
            }

            OfferItem offer = OfferItem.fromMap(data);
            offers.add(offer);
            print('   ✅ Item added to list with distance: ${offer.distance}');
          } catch (e) {
            print('   ❌ Error parsing document ${doc.id}: $e');
          }
        }

        print('📊 Total items processed: ${offers.length}');

        // Sort by distance if user location is available
        if (userLocation != null) {
          print('🔄 Sorting by distance...');
          offers.sort((a, b) {
            final aDistance = a.distance;
            final bDistance = b.distance;

            // Extract numeric values for comparison
            double aValue = _extractDistanceValue(aDistance);
            double bValue = _extractDistanceValue(bDistance);

            return aValue.compareTo(bValue);
          });
          print('✅ Sorting complete');
        }

        return offers;
      });
    } catch (e) {
      print('❌ Error getting offers: $e');
      return Stream.value([]);
    }
  }

  // Haversine formula to calculate distance between two coordinates
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Helper to extract numeric distance value for sorting
  static double _extractDistanceValue(String distance) {
    if (distance == 'Unknown' || distance == 'Location unavailable') {
      return double.infinity;
    }

    try {
      if (distance.contains('m') && !distance.contains('km')) {
        // meters
        return double.parse(distance.replaceAll(RegExp(r'[^0-9.]'), ''));
      } else if (distance.contains('km')) {
        // kilometers to meters
        return double.parse(distance.replaceAll(RegExp(r'[^0-9.]'), '')) * 1000;
      }
    } catch (e) {
      print('Error extracting distance value from "$distance": $e');
    }

    return double.infinity;
  }

  // Get user's own offers
  static Stream<List<OfferItem>> getUserOffers(String userId) {
    try {
      return _firestore
          .collection('items')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              data['id'] = doc.id;
              return OfferItem.fromMap(data);
            }).toList();
          });
    } catch (e) {
      print('Error getting user offers: $e');
      return Stream.value(<OfferItem>[]);
    }
  }

  // Delete offer
  static Future<void> deleteOffer(String offerId) async {
    try {
      await _firestore.collection('items').doc(offerId).delete();
    } catch (e) {
      throw Exception('Error deleting offer: $e');
    }
  }

  // Toggle offer status (active/inactive)
  static Future<void> toggleOfferStatus(String offerId, bool isActive) async {
    try {
      await _firestore.collection('items').doc(offerId).update({
        'status': isActive ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error updating offer status: $e');
    }
  }

  // Update offer
  static Future<void> updateOffer(
    String offerId,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('items').doc(offerId).update(data);
    } catch (e) {
      throw Exception('Error updating offer: $e');
    }
  }
}
