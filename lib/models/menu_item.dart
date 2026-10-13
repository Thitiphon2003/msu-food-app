import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/image_service.dart';

class MenuItem {
  final String id;
  final String shopId;
  final String name;
  final num price;
  final bool available;
  final Uint8List? imageBytes; // ใหม:่ รปเมน ู ู (null = ไมม่ รีปู )
  MenuItem({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
    required this.available,
    this.imageBytes,
  });
  factory MenuItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return MenuItem(
      id: d.id,
      shopId: m['shopId'] as String? ?? '',
      name: m['name'] as String? ?? '',
      price: m['price'] as num? ?? 0,
      available: m['available'] as bool? ?? true,
      // เมนูเกาท่ ไมี่ ม่ ฟีิลดน์ จะี้ ได ้null และแสดงไอคอนแทน
      imageBytes: ImageService.decode(m['imageBase64'] as String?),
    );
  }
}
