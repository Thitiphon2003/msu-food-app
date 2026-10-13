import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:msu_food/models/food_order.dart';
import 'package:msu_food/models/shop.dart';
import 'package:msu_food/screens/shop/customers_screen.dart';
import 'package:msu_food/screens/shop/menu_manage_screen.dart';
import 'package:msu_food/screens/shop/order_history_screen.dart';
import 'package:msu_food/services/auth_service.dart';
import 'package:msu_food/services/db.dart';
import 'package:msu_food/widgets/order_alerts.dart';
import 'package:msu_food/widgets/retro.dart';

class OrderBoardScreen extends StatelessWidget {
  final User user;
  final String shopId;
  const OrderBoardScreen({super.key, required this.user, required this.shopId});

  void _go(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final db = Db();
    // เด้งแจ้งเตือน + สั่น เมื่อมีออเดอร์ใหม่เข้ามาขณะเปิดแอป
    return OrderAlerts(
      stream: db.watchShopOrders(shopId),
      messageFor: (before, now) => before == null && now.status == OrderStatus.pending
          ? 'ออเดอร์ใหม่จาก ${now.customerName}'
          : null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ออเดอร์เข้าใหม่'),
          bottom: retroBarBottom,
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'ประวัติออเดอร์',
              onPressed: () => _go(context, OrderHistoryScreen(shopId: shopId)),
            ),
            IconButton(
              icon: const Icon(Icons.people_alt_outlined),
              tooltip: 'โปรไฟล์ลูกค้า',
              onPressed: () => _go(context, const CustomersScreen()),
            ),
            IconButton(
              icon: const Icon(Icons.restaurant_menu_rounded),
              tooltip: 'จัดการเมนู',
              onPressed: () => _go(context, MenuManageScreen(shopId: shopId)),
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
            // สวิตช์เปิด-ปิดร้าน: ฟังเอกสารร้านเดียว เพื่อให้สวิตช์ตรงกับค่าจริงเสมอ
            StreamBuilder<Shop>(
              stream: db.watchShop(shopId),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final shop = snap.data!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
                  child: PixelBox(
                    color: shop.isOpen ? const Color(0xFFD9F2CF) : const Color(0xFFF6D5CC),
                    padding: EdgeInsets.zero,
                    child: SwitchListTile(
                      title: Text(
                        shop.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: retroBrown),
                      ),
                      subtitle: Text(
                        shop.isOpen ? 'OPEN · ลูกค้าสั่งได้' : 'CLOSED · ลูกค้าสั่งไม่ได้',
                        style: const TextStyle(color: retroBrown),
                      ),
                      value: shop.isOpen,
                      onChanged: (v) => db.setShopOpen(shopId, v),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: StreamBuilder<List<FoodOrder>>(
                stream: db.watchShopOrders(shopId),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: SelectableText('ผิดพลาด: ${snap.error}')),
                    );
                  }
                  if (!snap.hasData) return const PixelLoader();
                  final orders = snap.data!;
                  if (orders.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.coffee_outlined, size: 56, color: retroAccent),
                          SizedBox(height: 8),
                          Text(
                            '- NO ORDERS -',
                            style: TextStyle(fontWeight: FontWeight.bold, color: retroBrown),
                          ),
                          Text('ยังไม่มีออเดอร์เข้ามา พักก่อนได้เลย'),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 20, 24), // ขวาเผื่อเงาพิกเซล
                    itemCount: orders.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => i == 0
                        ? _Counters(orders: orders)
                        : _OrderCard(order: orders[i - 1], db: db),
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

/// สรุปจำนวนงานแต่ละขั้น เห็นภาพรวมทันทีไม่ต้องไล่อ่านการ์ด
class _Counters extends StatelessWidget {
  final List<FoodOrder> orders;
  const _Counters({required this.orders});

  @override
  Widget build(BuildContext context) {
    int n(bool Function(FoodOrder) test) => orders.where(test).length;
    final waiting = n((o) => o.status == OrderStatus.pending);
    final cooking = n((o) => o.status == OrderStatus.accepted || o.status == OrderStatus.cooking);
    final ready = n((o) => o.status == OrderStatus.ready);

    Widget cell(String label, int v, Color c) => Expanded(
          child: PixelBox(
            color: c,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$v',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: retroInk),
                ),
                Text(label, style: const TextStyle(fontSize: 12, color: retroInk)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        cell('รอรับ', waiting, retroYellow),
        const SizedBox(width: 10),
        cell('กำลังทำ', cooking, retroPaper),
        const SizedBox(width: 10),
        cell('พร้อมรับ', ready, const Color(0xFFD9F2CF)),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final FoodOrder order;
  final Db db;
  const _OrderCard({required this.order, required this.db});

  bool get _isNew => order.status == OrderStatus.pending;

  Future<void> _onAction(BuildContext context) async {
    // pending ใช้ธุรกรรมกันกดซ้ำ
    if (_isNew) {
      final error = await db.acceptOrder(order.id);
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    await db.advanceStatus(order.id, order.status);
  }

  // กันกดปฏิเสธพลาด (ยกเลิกแล้วย้อนไม่ได้)
  Future<void> _reject(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: pixelDialogShape,
        backgroundColor: retroPaper,
        title: const Text('ปฏิเสธออเดอร์นี้?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('กลับ')),
          PixelButton(
            label: 'ปฏิเสธ',
            color: retroRed,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) db.cancelOrder(order.id);
  }

  @override
  Widget build(BuildContext context) {
    final action = OrderStatus.actionLabel(order.status);
    final step = OrderStatus.active.indexOf(order.status);
    return PixelBox(
      color: _isNew ? const Color(0xFFFFF0CF) : retroPaper,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isNew) ...[
                const Blink(child: PixelTag(label: 'NEW!')),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: retroBrown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PixelSteps(step: step, total: OrderStatus.active.length),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  OrderStatus.labels[order.status] ?? '',
                  style: const TextStyle(fontSize: 13, color: retroBrown),
                ),
              ),
              // ร้านเห็นว่าออเดอร์ไหนรอนานแล้ว จะได้ทำตามลำดับ
              ElapsedText(since: order.createdAt),
            ],
          ),
          const SizedBox(height: 8),
          ...order.items.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text('${e.name} × ${e.qty}')),
                  Text('${e.subtotal} บาท'),
                ],
              ),
            ),
          ),
          if (order.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            PixelNote(order.note),
          ],
          const Divider(height: 24, thickness: 2, color: retroInk),
          Text(
            'รวม ${order.total} บาท',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_isNew)
                  PixelButton(
                    label: 'ปฏิเสธ',
                    color: retroRed,
                    onPressed: () => _reject(context),
                  ),
                if (action != null)
                  PixelButton(label: action, onPressed: () => _onAction(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
