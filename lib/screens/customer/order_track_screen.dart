import 'package:flutter/material.dart';
import 'package:msu_food/models/food_order.dart';
import 'package:msu_food/services/db.dart';
import 'package:msu_food/widgets/retro.dart';

/// หน้าติดตามสถานะคำสั่งซื้อ
///
/// ใช้การฟัง "เอกสารเดียว" ซึ่งประหยัดโควตาที่สุด
/// เพราะจะนับการอ่านเพิ่มก็ต่อเมื่อเอกสารใบนั้นเปลี่ยนแปลงจริง
///
/// เมื่อร้านกดเปลี่ยนสถานะบนอีกเครื่อง StreamBuilder จะได้รับค่าใหม่
/// แล้วเรียก builder ให้เองโดยอัตโนมัติ จึงไม่ต้องเรียก setState() เลย
class OrderTrackScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackScreen({super.key, required this.orderId});

  // เลขรับอาหาร 4 ตัวท้ายของรหัสออเดอร์ ใช้บอกร้านตอนมารับ
  String _code(String id) => (id.length > 4 ? id.substring(id.length - 4) : id).toUpperCase();

  Future<void> _confirm(BuildContext context, String title, String ok, Color okColor, VoidCallback onOk) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: pixelDialogShape,
        backgroundColor: retroPaper,
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('กลับ')),
          PixelButton(label: ok, color: okColor, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (yes == true) onOk();
  }

  @override
  Widget build(BuildContext context) {
    final db = Db();
    return Scaffold(
      appBar: AppBar(title: const Text('ติดตามคำสั่งซื้อ'), bottom: retroBarBottom),
      body: StreamBuilder<FoodOrder>(
        stream: db.watchOrder(orderId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: SelectableText('ผิดพลาด: ${snap.error}')),
            );
          }
          if (!snap.hasData) return const PixelLoader();
          final order = snap.data!;
          final steps = OrderStatus.flow;
          final cur = steps.indexOf(order.status);
          final cancelled = order.status == OrderStatus.cancelled;
          final inProgress = OrderStatus.active.contains(order.status);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 32), // ขวาเผื่อเงาพิกเซล
            children: [
              // ---------- แผงสถานะปัจจุบัน ----------
              PixelBox(
                color: statusColor(order.status),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.shopName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: retroInk,
                            ),
                          ),
                        ),
                        PixelTag(label: '#${_code(order.id)}', color: retroPaper),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      OrderStatus.labels[order.status] ?? '',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: retroInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (inProgress)
                      ElapsedText(
                        since: order.createdAt,
                        prefix: 'รอมาแล้ว ',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: retroInk),
                      ),
                    if (order.status == OrderStatus.ready) ...[
                      const SizedBox(height: 10),
                      Blink(
                        child: Text(
                          '> บอกเลข #${_code(order.id)} ที่ร้านได้เลย <',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: retroInk),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ---------- ไทม์ไลน์ (ยกเลิกแล้วไม่แสดง) ----------
              if (!cancelled)
                PixelBox(
                  child: Column(
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: i <= cur ? retroGreen : Colors.transparent,
                                  border: Border.all(color: retroInk, width: 2),
                                ),
                                child: i <= cur
                                    ? const Icon(Icons.check_rounded, size: 16, color: retroInk)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  OrderStatus.labels[steps[i]] ?? '',
                                  style: TextStyle(
                                    fontWeight: i == cur ? FontWeight.bold : FontWeight.normal,
                                    color: i <= cur ? retroBrown : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (!cancelled) const SizedBox(height: 20),

              // ---------- รายการที่สั่ง ----------
              PixelBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const Divider(height: 22, thickness: 2, color: retroInk),
                    Text(
                      'ยอดรวม ${order.total} บาท',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (order.note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      PixelNote(order.note),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ---------- ปุ่ม ----------
              // ลูกค้ายกเลิกได้เฉพาะตอนที่ร้านยังไม่รับ
              if (order.status == OrderStatus.pending)
                PixelButton(
                  label: 'ยกเลิกคำสั่งซื้อ',
                  icon: Icons.close_rounded,
                  color: retroRed,
                  expand: true,
                  onPressed: () => _confirm(
                    context,
                    'ยกเลิกคำสั่งซื้อนี้?',
                    'ยกเลิก',
                    retroRed,
                    () => db.cancelOrder(order.id),
                  ),
                ),
              // เมื่ออาหารพร้อม ลูกค้ากดยืนยันว่ารับแล้ว
              if (order.status == OrderStatus.ready)
                PixelButton(
                  label: 'ได้รับอาหารแล้ว',
                  icon: Icons.check_rounded,
                  color: retroGreen,
                  expand: true,
                  onPressed: () => db.advanceStatus(order.id, order.status),
                ),
            ],
          );
        },
      ),
    );
  }
}
