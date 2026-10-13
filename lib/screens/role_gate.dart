import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:msu_food/screens/customer/shop_list_screen.dart';
import 'package:msu_food/screens/shop/order_board_screen.dart';
import 'package:msu_food/services/auth_service.dart';
import 'package:msu_food/services/db.dart';
import 'package:msu_food/widgets/retro.dart';

class RoleGate extends StatelessWidget {
  final User user;
  const RoleGate({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final db = Db();
    // ฟังเอกสารโปรไฟล์แบบเรียลไทม์
    // ถ้าเลือกบทบาทเสร็จ หน้าจอจะเปลี่ยนเองทันที โดยไม่ต้องสั่ง
    return StreamBuilder<Map<String, dynamic>?>(
      stream: db.watchProfile(user.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: PixelLoader());
        }
        final profile = snap.data;
        // ยังไม่เคยเลือกบทบาท
        if (profile == null) return _ChooseRole(user: user, db: db);
        if (profile['role'] == 'shop') {
          return OrderBoardScreen(user: user, shopId: profile['shopId'] as String);
        }
        return ShopListScreen(user: user);
      },
    );
  }
}

class _ChooseRole extends StatelessWidget {
  final User user;
  final Db db;
  const _ChooseRole({required this.user, required this.db});

  Future<void> _pickShop(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: pixelDialogShape,
        backgroundColor: retroPaper,
        title: const Text('ตั้งชื่อร้านของคุณ'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'เช่น ร้านคุณยาย',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: retroInk, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          PixelButton(label: 'สร้างร้าน', onPressed: () => Navigator.pop(ctx, ctrl.text.trim())),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await db.becomeShop(user.uid, user.displayName ?? '', name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกบทบาท'),
        bottom: retroBarBottom,
        actions: [
          // เผื่อล็อกอินผิดบัญชี จะได้ออกจากหน้านี้ได้
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'ออกจากระบบ',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 28, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SELECT PLAYER',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: retroBrown,
              ),
            ),
            const SizedBox(height: 6),
            const Text('คุณต้องการใช้งานในบทบาทใด', style: TextStyle(color: retroBrown)),
            const SizedBox(height: 28),
            _RoleCard(
              icon: Icons.person_outline_rounded,
              title: 'ลูกค้า',
              detail: 'เลือกร้าน สั่งอาหาร และติดตามสถานะ',
              color: retroYellow,
              onTap: () => db.becomeCustomer(user.uid, user.displayName ?? ''),
            ),
            const SizedBox(height: 20),
            _RoleCard(
              icon: Icons.storefront_outlined,
              title: 'ร้านค้า',
              detail: 'จัดการเมนู รับออเดอร์ และเปลี่ยนสถานะ',
              color: retroPaper,
              onTap: () => _pickShop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title $detail',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: PixelBox(
          color: color,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: retroInk),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: retroInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: const TextStyle(color: retroInk)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: retroInk),
            ],
          ),
        ),
      ),
    );
  }
}
