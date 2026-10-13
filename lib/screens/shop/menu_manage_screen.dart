
import 'package:flutter/material.dart';
import '../../models/menu_item.dart';
import '../../services/db.dart';
import '../../widgets/retro.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/image_service.dart';
import '../../widgets/menu_image.dart';

const _brown = Color(0xFF4A3B2E);
const _paper = Color(0xFFFFF8EA);

/// หน้าจัดการเมนูของร้าน — CRUD ครบทั้งสี่การกระทำ
/// C: ปุ่ม เพิ่มเมนู | R: StreamBuilder ที่ฟัง watchMenu()
/// U: แตะที่รายการเพื่อแก้ไข และสวิตช์เปิดปิดการขาย | D: ปุ่มถังขยะพร้อมกล่องยืนยัน
class MenuManageScreen extends StatelessWidget {
  final String shopId;
  const MenuManageScreen({super.key, required this.shopId});

  // ช่องกรอกเหลี่ยม ขอบหนา
  InputDecoration _field(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: retroInk, width: 2),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: retroInk, width: 3),
    ),
  );

  // กรอบกล่องโต้ตอบแบบพิกเซล
  static const _dialogShape = RoundedRectangleBorder(
    side: BorderSide(color: retroInk, width: 3),
  );

  /// กล่องโต้ตอบเดียว ใช้ได้ทั้งเพิ่มใหม่และแก้ไข (item == null คือโหมดเพิ่ม)
  Future<void> _openForm(
    BuildContext context,
    Db db,
    MenuItem? item,
  ) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final priceCtrl = TextEditingController(
      text: item == null ? '' : '${item.price}',
    );

    final imageService = ImageService();

    // สถานะของรูปภายในฟอร์ม
    String? newImage;
    bool removeImage = false;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // ลำดับการเลือกรูปตัวอย่าง: รูปใหม่ > รูปเดิม > ไม่มีรูป
          final preview = newImage != null
              ? ImageService.decode(newImage)
              : (removeImage ? null : item?.imageBytes);

          Future<void> pick(ImageSource source) async {
            try {
              final b64 = await imageService.pickAsBase64(source);

              if (b64 == null || !ctx.mounted) return;

              setDialogState(() {
                newImage = b64;
                removeImage = false;
              });
            } catch (e) {
              if (!ctx.mounted) return;

              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    e.toString().replaceFirst('Exception: ', ''),
                  ),
                ),
              );
            }
          }

          return AlertDialog(
            title: Text(
              item == null ? 'เพิ่มเมนูใหม่: ' : 'แก้ไขเมนู',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MenuImage(
                    bytes: preview, 
                    size: 120,
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'ถ่ายรูป',
                        icon: const Icon(Icons.photo_camera),
                        onPressed: saving
                            ? null
                            : () => pick(ImageSource.camera),
                      ),

                      IconButton.filledTonal(
                        tooltip: 'เลือกจากคลังภาพ',
                        icon: const Icon(Icons.photo_library),
                        onPressed: saving
                            ? null
                            : () => pick(ImageSource.gallery),
                      ),

                      if (preview != null)
                        IconButton(
                          tooltip: 'ลบรูป',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: saving
                              ? null
                              : () => setDialogState(() {
                                    newImage = null;
                                    removeImage = true;
                                  }),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อเมนู',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ราคา (บาท)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),

              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final price =
                            num.tryParse(priceCtrl.text.trim());

                        if (name.isEmpty || price == null) return;

                        setDialogState(() => saving = true);

                        try {
                          if (item == null) {
                            await db.addMenuItem(
                              shopId,
                              name,
                              price,
                              imageBase64: newImage,
                            );
                          } else {
                            await db.updateMenuItem(
                              item.id,
                              name,
                              price,
                              imageBase64: newImage,
                              removeImage: removeImage,
                            );
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        } catch (e) {
                          if (!ctx.mounted) return;

                          setDialogState(() => saving = false);

                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                'บันทึกไม่สำเร็จ: $e',
                              ),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Db db,
    MenuItem item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _dialogShape,
        backgroundColor: _paper,
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'ต้องการลบเมนู "${item.name}" หรือไม่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),

          PixelButton(
            label: 'ลบ',
            color: const Color(0xFFFF8A80),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      await db.deleteMenuItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Db();

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการเมนู'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: Divider(
            height: 3,
            thickness: 3,
            color: retroInk,
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, db, null),
        backgroundColor: retroYellow,
        foregroundColor: retroInk,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(
            color: retroInk,
            width: 3,
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'เพิ่มเมนู',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // READ แบบเรียลไทม์
      body: StreamBuilder<List<MenuItem>>(
        stream: db.watchMenu(shopId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('ผิดพลาด: ${snap.error}'),
            );
          }

          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final items = snap.data!;

          if (items.isEmpty) {
            return const Center(
              child: Text(
                '- EMPTY MENU -\nกด "เพิ่มเมนู" ได้เลย',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _brown,
                ),
              ),
            );
          }

          return ListView.separated(
            // ขวาเผื่อเงาพิกเซล ล่างเผื่อที่ให้ปุ่มไม่บังรายการสุดท้าย
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              20,
              96,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 14),

            itemBuilder: (context, i) {
              final m = items[i];

              return GestureDetector(
                onTap: () => _openForm(context, db, m),

                child: PixelBox(
                  color: _paper,
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    10,
                    6,
                    10,
                  ),

                  child: Row(
                    children: [
                      // ==============================
                      // รูปภาพเมนู
                      // ==============================
                      MenuImage(
                        bytes: m.imageBytes,
                        size: 70,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        // เมนูที่ปิดขายจะจางลง เห็นสถานะได้ทันที
                        child: Opacity(
                          opacity: m.available ? 1 : .45,

                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Text(
                                m.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _brown,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Row(
                                children: [
                                  Text('${m.price} บาท'),

                                  const SizedBox(width: 8),

                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),

                                    decoration: BoxDecoration(
                                      color: m.available
                                          ? retroGreen
                                          : Colors.grey.shade400,

                                      border: Border.all(
                                        color: retroInk,
                                        width: 2,
                                      ),
                                    ),

                                    child: Text(
                                      m.available
                                          ? 'ON SALE'
                                          : 'SOLD OUT',

                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight.bold,
                                        color: retroInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // สวิตช์นี้คือจุดสาธิตเรียลไทม์
                      // กดแล้วหน้าจอลูกค้าเปลี่ยนทันที
                      Switch(
                        value: m.available,
                        onChanged: (v) =>
                            db.setAvailable(m.id, v),
                      ),

                      // ปุ่มลบ
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                        ),
                        tooltip: 'ลบเมนู',
                        onPressed: () =>
                            _confirmDelete(context, db, m),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
