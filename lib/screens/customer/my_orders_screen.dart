import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:msu_food/models/food_order.dart';
import 'package:msu_food/models/shop.dart';
import 'package:msu_food/screens/customer/menu_screen.dart';
import 'package:msu_food/screens/customer/order_track_screen.dart';
import 'package:msu_food/services/db.dart';
import 'package:msu_food/widgets/retro.dart';

class MyOrdersScreen extends StatelessWidget {
  final User user;
  const MyOrdersScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final db = Db();
    return Scaffold(
      appBar: AppBar(title: const Text('ออเดอร์ของฉัน'), bottom: retroBarBottom),
      body: StreamBuilder<List<FoodOrder>>(
        stream: db.watchMyOrders(user.uid),
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
                  Icon(Icons.receipt_long_rounded, size: 56, color: retroAccent),
                  SizedBox(height: 8),
                  Text(
                    '- NO HISTORY -',
                    style: TextStyle(fontWeight: FontWeight.bold, color: retroBrown),
                  ),
                  Text('ยังไม่มีประวัติการสั่งซื้อ'),
                ],
              ),
            );
          }
          final active = orders.where((o) => OrderStatus.active.contains(o.status)).toList();
          final done = orders.where((o) => !OrderStatus.active.contains(o.status)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 24), // ขวาเผื่อเงาพิกเซล
            children: [
              if (active.isNotEmpty) ...[
                const _Header('IN PROGRESS · กำลังดำเนินการ'),
                for (final o in active) _OrderTile(order: o, user: user),
              ],
              if (done.isNotEmpty) ...[
                const _Header('HISTORY · ประวัติ'),
                for (final o in done) _OrderTile(order: o, user: user),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: retroBrown,
          ),
        ),
      );
}

class _OrderTile extends StatelessWidget {
  final FoodOrder order;
  final User user;
  const _OrderTile({required this.order, required this.user});

  bool get _isActive => OrderStatus.active.contains(order.status);

  void _track(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderTrackScreen(orderId: order.id)),
      );

  // สั่งซ้ำ: เปิดเมนูร้านเดิมพร้อมเติมตะกร้าให้ตามออเดอร์เก่า
  void _reorder(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MenuScreen(
            shop: Shop(id: order.shopId, name: order.shopName, ownerId: '', isOpen: true),
            user: user,
            reorder: order.items,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('d/M/yyyy HH:mm').format(order.createdAt);
    final summary = order.items.map((e) => '${e.name} ×${e.qty}').join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _track(context),
        child: PixelBox(
          padding: const EdgeInsets.all(14),
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
                        color: retroBrown,
                      ),
                    ),
                  ),
                  PixelTag(
                    label: OrderStatus.labels[order.status] ?? '',
                    color: statusColor(order.status),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(when, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 6),
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (_isActive) ...[
                const SizedBox(height: 10),
                PixelSteps(
                  step: OrderStatus.active.indexOf(order.status),
                  total: OrderStatus.active.length,
                ),
                const SizedBox(height: 6),
                ElapsedText(since: order.createdAt),
              ],
              const Divider(height: 22, thickness: 2, color: retroInk),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${order.total} บาท',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (_isActive)
                    PixelButton(
                      label: 'ติดตาม',
                      icon: Icons.timelapse_rounded,
                      onPressed: () => _track(context),
                    )
                  else
                    PixelButton(
                      label: 'สั่งซ้ำ',
                      icon: Icons.replay_rounded,
                      color: retroGreen,
                      onPressed: () => _reorder(context),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
