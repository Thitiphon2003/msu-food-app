import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:msu_food/models/food_order.dart';
import 'package:msu_food/models/shop.dart';
import 'package:msu_food/screens/customer/menu_screen.dart';
import 'package:msu_food/screens/customer/my_orders_screen.dart';
import 'package:msu_food/screens/customer/order_track_screen.dart';
import 'package:msu_food/services/auth_service.dart';
import 'package:msu_food/services/db.dart';
import 'package:msu_food/widgets/order_alerts.dart';
import 'package:msu_food/widgets/retro.dart';

/// หน้าแรกของฝั่งลูกค้า แสดงรายชื่อร้านทั้งหมด + ออเดอร์ที่กำลังทำอยู่ + แจ้งเตือนเมื่อสถานะเปลี่ยน
///
/// ป้ายเปิด/ปิดของแต่ละร้านมาจากฟิลด์ isOpen
/// เมื่อร้านสลับสวิตช์บนอีกเครื่อง ป้ายนี้จะเปลี่ยนเองทันที
class ShopListScreen extends StatefulWidget {
  final User user;
  const ShopListScreen({super.key, required this.user});

  @override
  State<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends State<ShopListScreen> {
  final _db = Db();
  // broadcast เพื่อให้ทั้งตัวแจ้งเตือนและการ์ดออเดอร์ฟังสตรีมเดียวกันได้
  late final Stream<List<FoodOrder>> _mine =
      _db.watchMyOrders(widget.user.uid).asBroadcastStream();

  void _track(FoodOrder o) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderTrackScreen(orderId: o.id)),
      );

  // สถานะที่ร้านเป็นคนเปลี่ยน → แจ้งลูกค้า (completed ลูกค้ากดเองจึงไม่แจ้ง)
  String? _alertFor(FoodOrder? before, FoodOrder now) {
    if (before == null || before.status == now.status) return null;
    return switch (now.status) {
      OrderStatus.accepted => '${now.shopName} รับออเดอร์ของคุณแล้ว',
      OrderStatus.cooking => 'กำลังปรุงอาหารของคุณ',
      OrderStatus.ready => 'อาหารพร้อมแล้ว! มารับที่ร้านได้เลย',
      OrderStatus.cancelled => 'ออเดอร์ถูกยกเลิก',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return OrderAlerts(
      stream: _mine,
      messageFor: _alertFor,
      onOpen: _track,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('เลือกร้านอาหาร'),
          bottom: retroBarBottom,
          actions: [
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded),
              tooltip: 'ออเดอร์ของฉัน',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MyOrdersScreen(user: widget.user)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'ออกจากระบบ',
              onPressed: () => AuthService().signOut(),
            ),
          ],
        ),
        body: Column(
          children: [
            // ออเดอร์ที่ยังไม่จบ (สูงสุด 2 ใบ) แตะเพื่อดูรายละเอียด
            StreamBuilder<List<FoodOrder>>(
              stream: _mine,
              builder: (context, snap) {
                final active = (snap.data ?? const <FoodOrder>[])
                    .where((o) => OrderStatus.active.contains(o.status))
                    .take(2)
                    .toList();
                return Column(
                  children: [
                    for (final o in active) _ActiveOrderCard(order: o, onTap: () => _track(o)),
                  ],
                );
              },
            ),
            Expanded(
              child: StreamBuilder<List<Shop>>(
                stream: _db.watchShops(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('ผิดพลาด: ${snap.error}'));
                  if (!snap.hasData) return const PixelLoader();
                  // ร้านที่เปิดอยู่ขึ้นก่อน
                  final shops = [...snap.data!]..sort((a, b) {
                      final c = (b.isOpen ? 1 : 0).compareTo(a.isOpen ? 1 : 0);
                      return c != 0 ? c : a.name.compareTo(b.name);
                    });
                  if (shops.isEmpty) {
                    return const Center(child: Text('ยังไม่มีร้านค้าในระบบ'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 20, 24), // ขวาเผื่อเงาพิกเซล
                    itemCount: shops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final s = shops[i];
                      return Semantics(
                        button: true,
                        label: '${s.name} ${s.isOpen ? 'เปิดอยู่' : 'ปิดอยู่'}',
                        excludeSemantics: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MenuScreen(shop: s, user: widget.user),
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MenuScreen(shop: s, user: widget.user),
                            ),
                          ),
                          child: PixelBox(
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: s.isOpen ? retroGreen : Colors.grey.shade300,
                                    border: Border.all(color: retroInk, width: 2),
                                  ),
                                  child: const Icon(Icons.storefront_rounded, color: retroInk),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: retroBrown,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      PixelTag(
                                        label: s.isOpen ? 'OPEN · เปิดอยู่' : 'CLOSED · ปิดอยู่',
                                        color: s.isOpen ? retroGreen : Colors.grey.shade300,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: retroBrown),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final FoodOrder order;
  final VoidCallback onTap;
  const _ActiveOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
      child: Semantics(
        button: true,
        label: 'ดูสถานะออเดอร์ ${order.shopName} ${OrderStatus.labels[order.status] ?? ''}',
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          onTap: onTap,
          child: PixelBox(
            color: statusColor(order.status),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.shopName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: retroInk,
                        ),
                      ),
                    ),
                    ElapsedText(
                      since: order.createdAt,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: retroInk),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  OrderStatus.labels[order.status] ?? '',
                  style: const TextStyle(color: retroInk),
                ),
                const SizedBox(height: 8),
                PixelSteps(
                  step: OrderStatus.active.indexOf(order.status),
                  total: OrderStatus.active.length,
                  fill: retroInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
