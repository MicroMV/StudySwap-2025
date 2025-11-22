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

  // Get offers method with distance calculation
  static Stream<List<OfferItem>> getOffers({
    String? action,
    String? category,
    String? searchQuery,
    GeoPoint? userLocation,
    String? currentUserId,
  }) {
    print('🔍 getOffers called!');
    print(
      '   - userLocation: ${userLocation != null ? "${userLocation.latitude}, ${userLocation.longitude}" : "NULL"}',
    );

    try {
      Query query = _firestore.collection('items');

      // Filter by action
      if (action != null && action != 'All') {
        query = query.where('action', isEqualTo: action);
      }

      // Filter by category
      if (category != null && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }

      // Order by creation date
      query = query.orderBy('createdAt', descending: true);

      return query.snapshots().map((snapshot) {
        print('📦 Processing ${snapshot.docs.length} items');
        List<OfferItem> offers = [];

        for (var doc in snapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;

            // Skip inactive items (except own items)
            String status = data['status'] ?? 'active';
            String itemUserId = data['userId'] ?? '';
            if (status != 'active' && itemUserId != currentUserId) {
              continue;
            }

            // Search filter
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
                continue;
              }
            }

            // *** CALCULATE DISTANCE ***
            if (userLocation != null && data['location'] != null) {
              try {
                final itemLocation = data['location'] as GeoPoint;

                final distanceInMeters = _calculateDistance(
                  userLocation.latitude,
                  userLocation.longitude,
                  itemLocation.latitude,
                  itemLocation.longitude,
                );

                final distanceInKm = distanceInMeters / 1000;
                if (distanceInKm < 1) {
                  data['distance'] =
                      '${(distanceInKm * 1000).toStringAsFixed(0)} m';
                } else if (distanceInKm < 10) {
                  data['distance'] = '${distanceInKm.toStringAsFixed(1)} km';
                } else {
                  data['distance'] = '${distanceInKm.toStringAsFixed(0)} km';
                }

                print('   ✅ ${data['title']}: ${data['distance']}');
              } catch (e) {
                print('   ❌ Error calculating distance: $e');
                data['distance'] = 'Unknown';
              }
            } else {
              print('   ⚠️ No location: ${data['title']}');
              data['distance'] = 'Unknown';
            }

            OfferItem offer = OfferItem.fromMap(data);
            offers.add(offer);
          } catch (e) {
            print('Error parsing ${doc.id}: $e');
          }
        }

        return offers;
      });
    } catch (e) {
      print('Error in getOffers: $e');
      return Stream.value([]);
    }
  }

  // Haversine formula for distance
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
      return Stream.value([]);
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

  // Toggle offer status
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
