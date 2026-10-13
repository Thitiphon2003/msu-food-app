import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:msu_food/models/menu_item.dart';
import 'package:msu_food/services/db.dart';
import 'package:msu_food/services/image_service.dart';
import 'package:msu_food/widgets/menu_image.dart';
import 'package:msu_food/widgets/retro.dart';

/// หน้าจัดการเมนูของร้าน — CRUD ครบทั้งสี่การกระทำ + รูปเมนู
/// C: ปุ่ม เพิ่มเมนู | R: StreamBuilder ที่ฟัง watchMenu()
/// U: แตะที่รายการเพื่อแก้ไข และสวิตช์เปิดปิดการขาย | D: ปุ่มถังขยะพร้อมกล่องยืนยัน
class MenuManageScreen extends StatelessWidget {
  final String shopId;
  const MenuManageScreen({super.key, required this.shopId});

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

  /// กล่องโต้ตอบเดียว ใช้ได้ทั้งเพิ่มใหม่และแก้ไข (item == null คือโหมดเพิ่ม)
  Future<void> _openForm(BuildContext context, Db db, MenuItem? item) async {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final priceCtrl = TextEditingController(text: item == null ? '' : '${item.price}');
    final picker = ImageService();
    var preview = item?.imageBytes; // รูปที่แสดงอยู่ในกล่อง
    String? newImage; // base64 ของรูปใหม่ (null = ไม่เปลี่ยนรูป)
    var removeImage = false;
    var saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pick(ImageSource src) async {
            try {
              final b64 = await picker.pickAsBase64(src);
              if (b64 == null) return; // ผู้ใช้กดยกเลิก
              setS(() {
                newImage = b64;
                removeImage = false;
                preview = ImageService.decode(b64);
                error = null;
              });
            } catch (e) {
              // แสดงในกล่องเอง เพราะ SnackBar จะไปอยู่หลังกล่องโต้ตอบ
              setS(() => error = e.toString().replaceFirst('Exception: ', ''));
            }
          }

          Future<void> save() async {
            final name = nameCtrl.text.trim();
            final price = num.tryParse(priceCtrl.text.trim());
            if (name.isEmpty || price == null || price < 0) {
              setS(() => error = 'กรอกชื่อเมนูและราคาให้ถูกต้อง');
              return;
            }
            setS(() {
              saving = true;
              error = null;
            });
            try {
              if (item == null) {
                await db.addMenuItem(shopId, name, price, imageBase64: newImage); // CREATE
              } else {
                await db.updateMenuItem(
                  item.id,
                  name,
                  price,
                  imageBase64: newImage,
                  removeImage: removeImage,
                ); // UPDATE
              }
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              setS(() {
                saving = false;
                error = 'บันทึกไม่สำเร็จ: $e';
              });
            }
          }

          return AlertDialog(
            shape: pixelDialogShape,
            backgroundColor: retroPaper,
            title: Text(item == null ? 'เพิ่มเมนูใหม่' : 'แก้ไขเมนู'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MenuImage(bytes: preview, size: 88),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            PixelButton(
                              label: 'ถ่ายรูป',
                              icon: Icons.photo_camera_outlined,
                              onPressed: () => pick(ImageSource.camera),
                            ),
                            PixelButton(
                              label: 'คลังภาพ',
                              icon: Icons.photo_library_outlined,
                              color: retroPaper,
                              onPressed: () => pick(ImageSource.gallery),
                            ),
                            if (preview != null)
                              PixelButton(
                                label: 'ลบรูป',
                                color: retroRed,
                                onPressed: () => setS(() {
                                  newImage = null;
                                  removeImage = true;
                                  preview = null;
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: nameCtrl, decoration: _field('ชื่อเมนู')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _field('ราคา (บาท)'),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              PixelButton(
                label: saving ? 'กำลังบันทึก...' : 'บันทึก',
                onPressed: saving ? null : save,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Db db, MenuItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: pixelDialogShape,
        backgroundColor: retroPaper,
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบเมนู "${item.name}" หรือไม่'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          PixelButton(label: 'ลบ', color: retroRed, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) await db.deleteMenuItem(item.id); // DELETE
  }

  @override
  Widget build(BuildContext context) {
    final db = Db();
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการเมนู'), bottom: retroBarBottom),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, db, null),
        backgroundColor: retroYellow,
        foregroundColor: retroInk,
        elevation: 0,
        shape: pixelDialogShape,
        icon: const Icon(Icons.add_rounded),
        label: const Text('เพิ่มเมนู', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      // READ แบบเรียลไทม์
      body: StreamBuilder<List<MenuItem>>(
        stream: db.watchMenu(shopId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: SelectableText('ผิดพลาด: ${snap.error}')),
            );
          }
          if (!snap.hasData) return const PixelLoader();
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                '- EMPTY MENU -\nกด "เพิ่มเมนู" ได้เลย',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: retroBrown),
              ),
            );
          }
          return ListView.separated(
            // ขวาเผื่อเงาพิกเซล ล่างเผื่อที่ให้ปุ่มไม่บังรายการสุดท้าย
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final m = items[i];
              return GestureDetector(
                onTap: () => _openForm(context, db, m),
                child: PixelBox(
                  padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                  child: Row(
                    children: [
                      MenuImage(bytes: m.imageBytes, size: 56, grayscale: !m.available),
                      const SizedBox(width: 12),
                      Expanded(
                        // เมนูที่ปิดขายจะจางลง เห็นสถานะได้ทันที
                        child: Opacity(
                          opacity: m.available ? 1 : .55,
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
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('${m.price} บาท'),
                                  PixelTag(
                                    label: m.available ? 'ON SALE' : 'SOLD OUT',
                                    color: m.available ? retroGreen : Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // สวิตช์นี้คือจุดสาธิตเรียลไทม์ กดแล้วหน้าจอลูกค้าเปลี่ยนทันที
                      Switch(
                        value: m.available,
                        onChanged: (v) => db.setAvailable(m.id, v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'ลบเมนู',
                        onPressed: () => _confirmDelete(context, db, m),
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
