import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:msu_food/models/food_order.dart';
import 'package:msu_food/models/menu_item.dart';
import 'package:msu_food/models/shop.dart';
import 'package:msu_food/screens/customer/order_track_screen.dart';
import 'package:msu_food/services/db.dart';
import 'package:msu_food/widgets/menu_image.dart';
import 'package:msu_food/widgets/retro.dart';

/// หน้าเมนูและตะกร้าของลูกค้า
///
/// ฟังสองกระแสข้อมูลพร้อมกัน
/// กระแสที่ 1: เอกสารร้าน -> ดูว่ายังเปิดอยู่หรือไม่
/// กระแสที่ 2: รายการเมนู -> ดูว่าเมนูใดของหมด
/// เมื่อร้านปิดสวิตช์หรือกดเมนูของหมดบนอีกเครื่อง หน้าจอนี้จะเปลี่ยนทันที
/// [reorder] = รายการจากออเดอร์เก่า ใช้เติมตะกร้าให้อัตโนมัติ (ปุ่ม "สั่งซ้ำ")
class MenuScreen extends StatefulWidget {
  final Shop shop;
  final User user;
  final List<OrderItem>? reorder;
  const MenuScreen({super.key, required this.shop, required this.user, this.reorder});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _db = Db();
  final _noteCtrl = TextEditingController();

  // เก็บ stream ไว้ในฟิลด์ ไม่สร้างใหม่ทุกครั้งที่กดบวก/ลบ (ของเดิมสมัครฟังใหม่ทุกครั้ง)
  late final Stream<Shop> _shopStream = _db.watchShop(widget.shop.id);
  late final Stream<List<MenuItem>> _menuStream = _db.watchMenu(widget.shop.id);

  /// ตะกร้าเก็บไว้ในหน่วยความจำของหน้าจอเท่านั้น ยังไม่บันทึกลงฐานข้อมูลจนกว่าจะกดยืนยัน
  /// key = รหัสเมนู, value = จำนวน
  final Map<String, int> _cart = {};

  /// เก็บข้อมูลเมนูล่าสุดไว้ใช้ตอนสร้างออเดอร์
  List<MenuItem> _menu = [];
  bool _placing = false;
  bool _reorderDone = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  num get _total {
    num sum = 0;
    for (final m in _menu) {
      sum += m.price * (_cart[m.id] ?? 0);
    }
    return sum;
  }

  /// เติมตะกร้าจากออเดอร์เก่า (จับคู่ด้วยชื่อ เพราะออเดอร์เก็บชื่อ ไม่ได้เก็บรหัสเมนู)
  void _applyReorder(List<MenuItem> menu) {
    final old = widget.reorder;
    if (_reorderDone || old == null) return;
    _reorderDone = true;
    var skipped = 0;
    for (final it in old) {
      MenuItem? hit;
      for (final m in menu) {
        if (m.name == it.name && m.available) {
          hit = m;
          break;
        }
      }
      if (hit == null) {
        skipped++;
      } else {
        _cart[hit.id] = it.qty;
      }
    }
    if (skipped > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$skipped รายการหมดหรือไม่มีแล้ว จึงไม่ได้ใส่ตะกร้า')),
        );
      });
    }
  }

  Future<void> _placeOrder() async {
    // แปลงตะกร้าให้เป็นรายการอาหารของออเดอร์
    final items = <OrderItem>[];
    for (final m in _menu) {
      final qty = _cart[m.id] ?? 0;
      if (qty > 0) items.add(OrderItem(name: m.name, price: m.price, qty: qty));
    }
    if (items.isEmpty) return;
    setState(() => _placing = true);
    try {
      final orderId = await _db.placeOrder(
        shop: widget.shop,
        customerId: widget.user.uid,
        customerName: widget.user.displayName ?? 'ลูกค้า',
        items: items,
        note: _noteCtrl.text,
      );
      if (!mounted) return;
      // แทนที่หน้านี้ด้วยหน้าติดตามสถานะ
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderTrackScreen(orderId: orderId)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('สั่งซื้อไม่สำเร็จ: $e')));
    }
  }

  void _zoom(MenuItem m) => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: MenuImage(bytes: m.imageBytes, size: 280, grayscale: !m.available),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.shop.name), bottom: retroBarBottom),
      // กระแสที่ 1 เฝ้าฟังสถานะร้าน
      body: StreamBuilder<Shop>(
        stream: _shopStream,
        builder: (context, shopSnap) {
          final isOpen = shopSnap.data?.isOpen ?? false;
          return Column(
            children: [
              if (shopSnap.hasData && !isOpen)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 20, 0),
                  child: PixelBox(
                    color: retroRed,
                    child: Row(
                      children: [
                        Icon(Icons.storefront_outlined, color: retroInk),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ขณะนี้ร้านปิดอยู่ สั่งอาหารไม่ได้',
                            style: TextStyle(fontWeight: FontWeight.bold, color: retroInk),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // กระแสที่ 2 เฝ้าฟังรายการเมนู
              Expanded(
                child: StreamBuilder<List<MenuItem>>(
                  stream: _menuStream,
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('ผิดพลาด: ${snap.error}'));
                    if (!snap.hasData) return const PixelLoader();
                    _menu = snap.data!;
                    _applyReorder(_menu);
                    // เมนูที่เพิ่งหมด/ถูกลบ ต้องหลุดออกจากตะกร้า ไม่งั้นจะสั่งของที่ไม่มีได้
                    final ok = {for (final m in _menu) if (m.available) m.id};
                    _cart.removeWhere((id, _) => !ok.contains(id));

                    if (_menu.isEmpty) {
                      return const Center(
                        child: Text(
                          '- EMPTY MENU -\nร้านนี้ยังไม่มีเมนู',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, color: retroBrown),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
                            itemCount: _menu.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (_, i) => _item(_menu[i], isOpen),
                          ),
                        ),
                        if (_cart.isNotEmpty) _cartBar(isOpen),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _item(MenuItem m, bool isOpen) {
    final qty = _cart[m.id] ?? 0;
    // เมนูที่ของหมดหรือร้านปิดจะกดเพิ่มไม่ได้
    final canAdd = isOpen && m.available;
    final hasImage = m.imageBytes?.isNotEmpty ?? false;
    return PixelBox(
      color: m.available ? retroPaper : const Color(0xFFEDE3D6),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          GestureDetector(
            onTap: hasImage ? () => _zoom(m) : null,
            child: MenuImage(bytes: m.imageBytes, size: 56, grayscale: !m.available),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: retroBrown,
                  ),
                ),
                const SizedBox(height: 4),
                m.available
                    ? Text(
                        '${m.price} บาท',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: retroAccent),
                      )
                    : const PixelTag(label: 'SOLD OUT · หมดแล้ว', color: retroRed),
              ],
            ),
          ),
          if (qty > 0) ...[
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              tooltip: 'ลด ${m.name}',
              onPressed: () => setState(() {
                if (qty - 1 == 0) {
                  _cart.remove(m.id);
                } else {
                  _cart[m.id] = qty - 1;
                }
              }),
            ),
            SizedBox(
              width: 22,
              child: Center(
                child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.add_circle_rounded),
            tooltip: 'เพิ่ม ${m.name}',
            color: retroBrown,
            onPressed: canAdd ? () => setState(() => _cart[m.id] = qty + 1) : null,
          ),
        ],
      ),
    );
  }

  // ---------- แถบสรุปและปุ่มสั่งซื้อ ----------
  Widget _cartBar(bool isOpen) {
    final count = _cart.values.fold<int>(0, (a, b) => a + b);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 20, 12),
        child: PixelBox(
          color: retroYellow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_basket_rounded, color: retroInk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$count รายการ · รวม $_total บาท',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: retroInk),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(_cart.clear),
                    child: const Text('ล้าง', style: TextStyle(color: retroInk)),
                  ),
                ],
              ),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุถึงร้าน (ไม่บังคับ)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: retroInk, width: 2),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: retroPaper,
                ),
              ),
              const SizedBox(height: 10),
              _placing
                  ? const SizedBox(height: 70, child: PixelLoader(label: 'ORDERING'))
                  : PixelButton(
                      label: 'ยืนยันสั่งซื้อ',
                      icon: Icons.check_rounded,
                      color: retroGreen,
                      expand: true,
                      onPressed: isOpen ? _placeOrder : null,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
