import 'package:cloud_firestore/cloud_firestore.dart';

class OfferItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String action;
  final String condition;
  final String? price;
  final String? swapDetails;
  final List<String> images;
  final int imageCount;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime? timestamp;
  final DateTime? createdAt;
  final String status;
  final bool isActive;
  final String distance;
  final String? borrowStatus;
  final String? sellStatus;
  final String? swapStatus;

  OfferItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.action,
    required this.condition,
    this.price,
    this.swapDetails,
    required this.images,
    required this.imageCount,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.timestamp,
    this.createdAt,
    required this.status,
    required this.isActive,
    this.distance = 'Unknown',
    this.borrowStatus,
    this.sellStatus,
    this.swapStatus,
  });

  // Create OfferItem from Firestore document
  factory OfferItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return OfferItem.fromMap(data);
  }

  // Create OfferItem from Map (used by DatabaseService)
  factory OfferItem.fromMap(Map<String, dynamic> data) {
    final status = data['status'] ?? 'active';
    final isActiveFromData = data['isActive'];

    // Determine isActive based on status and explicit isActive field
    bool isActive;
    if (isActiveFromData != null) {
      isActive = isActiveFromData as bool;
    } else {
      // If no explicit isActive field, determine from status
      isActive = status == 'active';
    }

    return OfferItem(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      action: data['action'] ?? '',
      condition: data['condition'] ?? 'Good',
      price: data['price'],
      swapDetails: data['swapDetails'],
      images: List<String>.from(data['images'] ?? []),
      imageCount: data['imageCount'] ?? 0,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userEmail: data['userEmail'] ?? '',
      timestamp: _parseTimestamp(data['timestamp']),
      createdAt: _parseTimestamp(data['createdAt']),
      status: status,
      isActive: isActive,
      distance: data['distance'] ?? 'Unknown',
      borrowStatus: data['borrowStatus'] as String?,
      sellStatus: data['sellStatus'] as String?,
      swapStatus: data['swapStatus'] as String?,
    );
  }

  // Helper method to parse Firestore timestamps
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is DateTime) {
      return timestamp;
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }

    return null;
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'action': action,
      'condition': condition,
      'price': price,
      'swapDetails': swapDetails,
      'images': images,
      'imageCount': imageCount,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'status': status,
    };
  }

  // Copy with method for updates
  OfferItem copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? action,
    String? condition,
    String? price,
    String? swapDetails,
    List<String>? images,
    int? imageCount,
    String? userId,
    String? userName,
    String? userEmail,
    DateTime? timestamp,
    DateTime? createdAt,
    String? status,
    bool? isActive,
    String? distance,
  }) {
    return OfferItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      action: action ?? this.action,
      condition: condition ?? this.condition,
      price: price ?? this.price,
      swapDetails: swapDetails ?? this.swapDetails,
      images: images ?? this.images,
      imageCount: imageCount ?? this.imageCount,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      distance: distance ?? this.distance,
    );
  }

  @override
  String toString() {
    return 'OfferItem(id: $id, title: $title, action: $action, category: $category, price: $price, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfferItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
