import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:msu_food/models/food_order.dart';
import 'package:msu_food/widgets/retro.dart';

/// before = ออเดอร์เดิมที่เคยเห็น (null = เพิ่งโผล่) , now = ออเดอร์ล่าสุด
/// คืนข้อความเพื่อแจ้งเตือน หรือ null = ไม่ต้องแจ้ง
typedef AlertMessage = String? Function(FoodOrder? before, FoodOrder now);

/// ฟังสตรีมออเดอร์แล้วเด้งแถบแจ้งเตือน + สั่น เมื่อ messageFor ตอบกลับข้อความ
/// ใช้ได้ทั้งฝั่งร้าน (ออเดอร์ใหม่) และฝั่งลูกค้า (สถานะเปลี่ยน)
/// ข้อจำกัด: ทำงานตอนแอปเปิดอยู่เท่านั้น (ถ้าจะแจ้งตอนปิดแอปต้องใช้ FCM + APNs)
class OrderAlerts extends StatefulWidget {
  final Stream<List<FoodOrder>> stream;
  final AlertMessage messageFor;
  final void Function(FoodOrder order)? onOpen;
  final Widget child;
  const OrderAlerts({
    super.key,
    required this.stream,
    required this.messageFor,
    required this.child,
    this.onOpen,
  });

  @override
  State<OrderAlerts> createState() => _OrderAlertsState();
}

class _OrderAlertsState extends State<OrderAlerts> {
  final Map<String, FoodOrder> _seen = {};
  bool _primed = false; // ข้อมูลชุดแรกคือของเดิม ไม่แจ้งเตือน
  StreamSubscription<List<FoodOrder>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(_onData, onError: (_) {});
  }

  void _onData(List<FoodOrder> orders) {
    String? msg;
    FoodOrder? target;
    if (_primed) {
      for (final o in orders) {
        final m = widget.messageFor(_seen[o.id], o);
        if (m != null) {
          msg = m;
          target = o;
        }
      }
    }
    _primed = true;
    for (final o in orders) {
      _seen[o.id] = o;
    }
    if (msg == null || target == null || !mounted) return;

    final order = target;
    final open = widget.onOpen;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: retroYellow,
          shape: pixelDialogShape,
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: retroInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    color: retroInk,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          action: open == null
              ? null
              : SnackBarAction(
                  label: 'ดู',
                  textColor: retroInk,
                  onPressed: () => open(order),
                ),
        ),
      );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
