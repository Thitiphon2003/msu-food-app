import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop.dart';
import '../models/menu_item.dart';
import '../models/food_order.dart';

class Db {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _shops =>
      _db.collection('shops');
  CollectionReference<Map<String, dynamic>> get _menu =>
      _db.collection('menuItems');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  // ---------- โปรไฟลและ ์ บทบาท ----------
  // เฝ้าฟังเอกสารผใชู้ ้ใชต้ดสั นิ วา่ จะพาไปหนา้จอของบทบาทใด
  // นคี่ อื ตวอย ั าง่ การฟัง "เอกสารเดยวี " ไมใช่ ท่ งั้คอลเลกชนั
  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((d) => d.exists ? d.data() : null);
  }

  // เลอกื บทบาทลกคู า้
  Future<void> becomeCustomer(String uid, String name) async {
    await _users.doc(uid).set({
      'displayName': name,
      'role': 'customer',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> becomeShop(String uid, String name, String shopName) async {
    final batch = _db.batch();
    final shopRef = _shops.doc(); // สราง้ รหสั ราน้ ลวงหน ่ า้
    batch.set(shopRef, {
      'name': shopName,
      'ownerId': uid,
      'isOpen': false,
      'orderCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_users.doc(uid), {
      'displayName': name,
      'role': 'shop',
      'shopId': shopRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit(); // เขยนี ทงั้สองเอกสารพรอม้ กนั
  }

  // ---------- ราน้ คา้ ----------
  // เฝ้าฟังเอกสารราน้ เดยวี ทงั้สองฝั่งใชเมธ ้ อดนรี้ วม่ กนั
  // ราน้ ใชด้สถานะ ู ของตน ลกคู า้ใชด้ วู า่ ราน้ ยงัเปิดอยหร ู่ อื ไม่
  Stream<Shop> watchShop(String shopId) =>
      _shops.doc(shopId).snapshots().map(Shop.fromDoc);
  // สลบั สถานะเปิดปิดราน้ จดุ สาธติเรยลไท ี มข์ อ้ที่ 1
  Future<void> setShopOpen(String shopId, bool isOpen) async {
    await _shops.doc(shopId).update({
      'isOpen': isOpen,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  // รายชอื่ ราน้ ทงหมด ั้ ลกคู า้เห็นทกุ ราน้ แตกด่ สงไดเฉพาะ ้ ราน้ ทเปี่ ิด

  Stream<List<Shop>> watchShops() => _shops
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Shop.fromDoc).toList());
  // ---------- เมนู (CRUD ครบ) ----------
  Stream<List<MenuItem>> watchMenu(String shopId) => _menu
      .where('shopId', isEqualTo: shopId)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(MenuItem.fromDoc).toList());
  Future<void> addMenuItem(
    String shopId,
    String name,
    num price, {
    String? imageBase64, // ใหม:่ รปู เป็น Base64
  }) async {
    await _menu.add({
      'shopId': shopId,
      'name': name.trim(),
      'price': price,
      'available': true,
      'createdAt': FieldValue.serverTimestamp(),
      // if ใน Map: ใสฟ่ ิลดน์ เฉพาะ ี้ เมอื่ มรีปู เทาน่ ัน้
      if (imageBase64 != null) 'imageBase64': imageBase64,
    });
  }

Future<void> updateMenuItem(
  String id,
  String name,
  num price, {
  String? imageBase64,
  bool removeImage = false,
}) async {
  await _menu.doc(id).update({
    'name': name.trim(),
    'price': price,
    if (imageBase64 != null) 'imageBase64': imageBase64,
    if (removeImage && imageBase64 == null)
      'imageBase64': FieldValue.delete(),
  });
}


// เปิด/ปิดการขาย
Future<void> setAvailable(String id, bool available) async {
  await _menu.doc(id).update({
    'available': available,
  });
}


// ลบเมนู
Future<void> deleteMenuItem(String id) async {
  await _menu.doc(id).delete();
}
  // ใช ้batch เพราะตอง้ เขยนี สองเอกสารใหส้ ํา เร็จพรอม้ กนั
  // คอื สราง้ ออรเด์ อรใหม ์ ่ และเพมิ่ ตวันับออรเด์ อรของ ์ ราน้
  Future<String> placeOrder({
    required Shop shop,
    required String customerId,
    required String customerName,
    required List<OrderItem> items,
    required String note,
  }) async {
    final total = items.fold<num>(0, (sum, e) => sum + e.subtotal);
    final batch = _db.batch();
    final orderRef = _orders.doc();
    batch.set(orderRef, {
      'shopId': shop.id,
      'shopName': shop.name, // เกบ็ ซ้ําไว ้ไมต่ อง้ อาน่ ราน้ อกี
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((e) => e.toMap()).toList(),
      'total': total,
      'status': OrderStatus.pending,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_shops.doc(shop.id), {'orderCount': FieldValue.increment(1)});
    await batch.commit();
    return orderRef.id;
  }

  Stream<List<FoodOrder>> watchShopOrders(String shopId) => _orders
      .where('shopId', isEqualTo: shopId)
      .where('status', whereIn: OrderStatus.active)
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(FoodOrder.fromDoc).toList());
  Stream<List<FoodOrder>> watchOrdersBetween(
    String shopId,
    DateTime start,
    DateTime end,
  ) => _orders
      .where('shopId', isEqualTo: shopId)
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('createdAt', isLessThan: Timestamp.fromDate(end))
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FoodOrder.fromDoc).toList());
  Stream<List<FoodOrder>> watchMyOrders(String customerId) => _orders
      .where('customerId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FoodOrder.fromDoc).toList());

  // ฝั่งลกคู า้: ตดตาม ิ ออรเด์ อรเด์ ยวี แบบละเอยดี

  Stream<FoodOrder> watchOrder(String orderId) =>
      _orders.doc(orderId).snapshots().map(FoodOrder.fromDoc);

  Future<String?> acceptOrder(String orderId) async {
    try {
      await _db.runTransaction((tx) async {
        final ref = _orders.doc(orderId);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw Exception('ไม่พบออเดอร์นี้');
        }
        if (snap.data()!['status'] != OrderStatus.pending) {
          throw Exception('ออเดอร์นี้ถูกใช้ไปแล้ว');
        }
        tx.update(ref, {
          'status': OrderStatus.accepted,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // เลอนื่ ไปยงัสถานะถดั ไปตามลํา ดบั ใน OrderStatus.flow
  Future<void> advanceStatus(String orderId, String current) async {
    final next = OrderStatus.next(current);
    if (next == null) return; // ไมม่ สถานะ ี ถดั ไปแลว้
    await _orders.doc(orderId).update({
      'status': next,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelOrder(String orderId) async {
    await _orders.doc(orderId).update({
      'status': OrderStatus.cancelled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
