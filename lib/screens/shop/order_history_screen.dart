import 'package:flutter/material.dart';
import 'package:msu_food/models/food_order.dart';
import 'package:msu_food/services/db.dart';
import 'package:msu_food/widgets/retro.dart';

enum HistoryRange { day, month, year }

enum _Filter { all, done, cancelled }

/// ช่วงเวลา [เริ่ม, สิ้นสุด) ของ [anchor] ตามหน่วย [r] ใช้เป็นเงื่อนไข query ฝั่ง Firestore
(DateTime, DateTime) periodRange(DateTime anchor, HistoryRange r) => switch (r) {
      HistoryRange.day => (
          DateTime(anchor.year, anchor.month, anchor.day),
          DateTime(anchor.year, anchor.month, anchor.day + 1),
        ),
      HistoryRange.month => (
          DateTime(anchor.year, anchor.month),
          DateTime(anchor.year, anchor.month + 1),
        ),
      HistoryRange.year => (
          DateTime(anchor.year),
          DateTime(anchor.year + 1),
        ),
    };

const _months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

String _money(num n) => n
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class OrderHistoryScreen extends StatefulWidget {
  final String shopId;
  const OrderHistoryScreen({super.key, required this.shopId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  HistoryRange _range = HistoryRange.month;
  DateTime _anchor = DateTime.now();
  _Filter _filter = _Filter.all;
  late Stream<List<FoodOrder>> _stream = _open();

  // ดึงทุกสถานะ เฉพาะช่วงที่เลือก (ของเดิมใช้ stream ของหน้าออเดอร์ที่ตัดงานจบแล้วทิ้ง จึงไม่เห็นประวัติ)
  Stream<List<FoodOrder>> _open() {
    final (start, end) = periodRange(_anchor, _range);
    return Db().watchOrdersBetween(widget.shopId, start, end);
  }

  // เปลี่ยนช่วง/วันที่แล้วสร้าง stream ใหม่ครั้งเดียว (ไม่สร้างซ้ำทุกครั้งที่ build)
  void _set({HistoryRange? range, DateTime? anchor}) => setState(() {
        _range = range ?? _range;
        _anchor = anchor ?? _anchor;
        _stream = _open();
      });

  DateTime _shift(int n) => switch (_range) {
        HistoryRange.day => DateTime(_anchor.year, _anchor.month, _anchor.day + n),
        HistoryRange.month => DateTime(_anchor.year, _anchor.month + n),
        HistoryRange.year => DateTime(_anchor.year + n),
      };

  String get _label => switch (_range) {
        HistoryRange.day => '${_anchor.day} ${_months[_anchor.month - 1]} ${_anchor.year + 543}',
        HistoryRange.month => '${_months[_anchor.month - 1]} ${_anchor.year + 543}',
        HistoryRange.year => '${_anchor.year + 543}',
      };

  String get _unit => switch (_range) {
        HistoryRange.day => 'รายวัน',
        HistoryRange.month => 'รายเดือน',
        HistoryRange.year => 'รายปี',
      };

  // กดที่วันที่เพื่อเปิดปฏิทิน: ระบบใช้ส่วนที่ต้องการตามหน่วยที่เลือกอยู่
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _anchor.isAfter(now) ? now : _anchor,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'เลือกวันที่',
      cancelText: 'ยกเลิก',
      confirmText: 'ตกลง',
    );
    if (d != null) _set(anchor: d);
  }

  ButtonStyle get _segStyle => SegmentedButton.styleFrom(
        shape: const RoundedRectangleBorder(),
        side: const BorderSide(color: retroInk, width: 2),
        backgroundColor: retroPaper,
        foregroundColor: retroBrown,
        selectedBackgroundColor: retroYellow,
        selectedForegroundColor: retroInk,
      );

  @override
  Widget build(BuildContext context) {
    final canNext = !_shift(1).isAfter(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติออเดอร์'), bottom: retroBarBottom),
      body: StreamBuilder<List<FoodOrder>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            // ครั้งแรกอาจขึ้นลิงก์สร้าง index ของ Firestore: เลือกข้อความแล้วคัดลอกไปเปิดได้
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: SelectableText('ผิดพลาด: ${snap.error}')),
            );
          }
          if (!snap.hasData) return const PixelLoader();

          final all = snap.data!; // เรียงใหม่→เก่าจาก query แล้ว
          // ยอดขายไม่นับออเดอร์ที่ถูกปฏิเสธ/ยกเลิก
          final sold = all.where((o) => o.status != OrderStatus.cancelled).toList();
          final total = sold.fold<num>(0, (s, o) => s + o.total);
          final shown = switch (_filter) {
            _Filter.all => all,
            _Filter.done => all.where((o) => o.status == OrderStatus.completed).toList(),
            _Filter.cancelled => all.where((o) => o.status == OrderStatus.cancelled).toList(),
          };

          // เมนูขายดี 3 อันดับในช่วงที่เลือก
          final qty = <String, int>{};
          for (final o in sold) {
            for (final e in o.items) {
              qty[e.name] = (qty[e.name] ?? 0) + e.qty;
            }
          }
          final top = (qty.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              .take(3)
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
                child: SegmentedButton<HistoryRange>(
                  showSelectedIcon: false,
                  style: _segStyle,
                  segments: const [
                    ButtonSegment(value: HistoryRange.day, label: Text('รายวัน')),
                    ButtonSegment(value: HistoryRange.month, label: Text('รายเดือน')),
                    ButtonSegment(value: HistoryRange.year, label: Text('รายปี')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => _set(range: s.first, anchor: DateTime.now()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'ก่อนหน้า',
                    onPressed: () => _set(anchor: _shift(-1)),
                  ),
                  Semantics(
                    button: true,
                    label: 'เลือกวันที่จากปฏิทิน',
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: PixelBox(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 18, color: retroBrown),
                            const SizedBox(width: 6),
                            Text(
                              _label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: retroBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'ถัดไป',
                    onPressed: canNext ? () => _set(anchor: _shift(1)) : null,
                  ),
                ],
              ),
              // สรุปตามช่วงที่เลือก
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 20, 4),
                child: PixelBox(
                  color: retroYellow,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SCORE · ยอดขาย$_unit',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: retroInk),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '฿${_money(total)}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: retroInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${sold.length} ออเดอร์',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: retroInk),
                          ),
                        ],
                      ),
                      if (top.isNotEmpty) ...[
                        const Divider(height: 20, thickness: 2, color: retroInk),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.emoji_events_rounded, size: 20, color: retroInk),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ขายดี: ${top.map((e) => '${e.key} ×${e.value}').join(' · ')}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: retroInk),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 20, 4),
                child: SegmentedButton<_Filter>(
                  showSelectedIcon: false,
                  style: _segStyle,
                  segments: const [
                    ButtonSegment(value: _Filter.all, label: Text('ทั้งหมด')),
                    ButtonSegment(value: _Filter.done, label: Text('สำเร็จ')),
                    ButtonSegment(value: _Filter.cancelled, label: Text('ยกเลิก')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text(
                          '- NO DATA -\nไม่มีออเดอร์ในช่วงนี้',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, color: retroBrown),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 20, 24), // ขวาเผื่อเงาพิกเซล
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, i) => _tile(shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(FoodOrder o) {
    final t = o.createdAt;
    final time = '${t.day} ${_months[t.month - 1]} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final cancelled = o.status == OrderStatus.cancelled;
    return PixelBox(
      color: cancelled ? const Color(0xFFEDE3D6) : retroPaper,
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          o.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: retroBrown),
        ),
        subtitle: Text(
          '$time · ${OrderStatus.labels[o.status] ?? ''} · ${_money(o.total)} บาท',
          style: TextStyle(color: cancelled ? Colors.grey.shade700 : retroBrown),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...o.items.map(
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
          if (o.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            PixelNote(o.note),
          ],
        ],
      ),
    );
  }
}
