import 'dart:async';
import 'package:flutter/material.dart';
import 'package:msu_food/models/food_order.dart';

// ---------- พาเลตต์ (cozy cream + พิกเซล) ----------
const retroInk = Color(0xFF0B0B14);
const retroYellow = Color(0xFFFFD23F);
const retroGreen = Color(0xFF6BFF8A);
const retroRed = Color(0xFFFF8A80);
const retroBrown = Color(0xFF4A3B2E);
const retroAccent = Color(0xFFC98B5A);
const retroPaper = Color(0xFFFFF8EA);
const retroCream = Color(0xFFFAF6F0);

const pixelDialogShape = RoundedRectangleBorder(
  side: BorderSide(color: retroInk, width: 3),
);

/// เส้นหนาใต้ AppBar: AppBar(bottom: retroBarBottom)
const retroBarBottom = PreferredSize(
  preferredSize: Size.fromHeight(3),
  child: Divider(height: 3, thickness: 3, color: retroInk),
);

/// ใส่ใน MaterialApp(theme: buildRetroTheme()) ครั้งเดียว ทุกหน้าได้สี/AppBar/SnackBar เหมือนกัน
ThemeData buildRetroTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: retroAccent),
      scaffoldBackgroundColor: retroCream,
      appBarTheme: const AppBarTheme(
        backgroundColor: retroCream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: retroBrown,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: retroBrown,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: retroBrown,
        contentTextStyle: TextStyle(color: Colors.white),
        shape: pixelDialogShape,
      ),
    );

/// สีป้ายตามสถานะออเดอร์ (ใช้ทั้งฝั่งร้านและลูกค้า)
Color statusColor(String s) => switch (s) {
      OrderStatus.pending => retroYellow,
      OrderStatus.accepted || OrderStatus.cooking => const Color(0xFFFFD9B0),
      OrderStatus.ready => retroGreen,
      OrderStatus.cancelled => retroRed,
      _ => retroPaper,
    };

/// กรอบพิกเซล: ไม่มุมมน ขอบหนา เงาแข็งเยื้อง ไม่เบลอ
class PixelBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  const PixelBox({
    super.key,
    required this.child,
    this.color = retroPaper,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: retroInk, width: 3),
          boxShadow: const [BoxShadow(color: retroInk, offset: Offset(4, 4))],
        ),
        child: child,
      );
}

/// ป้ายเล็กๆ เช่น OPEN / SOLD OUT / สถานะ
class PixelTag extends StatelessWidget {
  final String label;
  final Color color;
  const PixelTag({super.key, required this.label, this.color = retroYellow});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: retroInk, width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: retroInk,
          ),
        ),
      );
}

/// ปุ่มพิกเซล สูงขั้นต่ำ 44 ตามมาตรฐานการแตะ onPressed = null คือปิดปุ่ม
class PixelButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool expand;
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = retroYellow,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: PixelBox(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 38),
              child: Center(
                widthFactor: expand ? null : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: retroInk),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: retroInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// กล่องหมายเหตุของออเดอร์
class PixelNote extends StatelessWidget {
  final String text;
  const PixelNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: PixelBox(
          color: const Color(0xFFFFE9A8),
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sticky_note_2_outlined, size: 18, color: retroInk),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}

/// แถบความคืบหน้าแบบบล็อก step = ขั้นปัจจุบัน (0-based), -1 = ยังไม่เริ่ม
class PixelSteps extends StatelessWidget {
  final int step;
  final int total;
  final Color fill;
  const PixelSteps({
    super.key,
    required this.step,
    required this.total,
    this.fill = retroAccent,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'ขั้นตอน ${step + 1} จาก $total',
        excludeSemantics: true,
        child: Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Container(
                  height: 10,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: i <= step ? fill : Colors.transparent,
                    border: Border.all(color: retroInk, width: 2),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// กะพริบสองจังหวะแบบเกมเก่า ถ้าผู้ใช้ปิดแอนิเมชันในระบบ จะแสดงนิ่ง
class Blink extends StatefulWidget {
  final Widget child;
  const Blink({super.key, required this.child});
  @override
  State<Blink> createState() => _BlinkState();
}

class _BlinkState extends State<Blink> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(opacity: _c.value < .5 ? 1 : 0, child: child),
      child: widget.child,
    );
  }
}

/// ตัวโหลดแบบพิกเซล: บล็อก 4 ก้อนเด้งตามกัน + จุดไข่ปลา ใช้แทน CircularProgressIndicator
class PixelLoader extends StatefulWidget {
  final String label;
  const PixelLoader({super.key, this.label = 'LOADING'});
  @override
  State<PixelLoader> createState() => _PixelLoaderState();
}

class _PixelLoaderState extends State<PixelLoader>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: 'กำลังโหลด',
      liveRegion: true,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final step = still ? 3 : (_c.value * 4).floor() % 4;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 4; i++)
                      SizedBox(
                        width: 26,
                        height: 36,
                        child: Align(
                          alignment: i == step
                              ? Alignment.topCenter
                              : Alignment.bottomCenter,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: i == step ? retroYellow : retroAccent,
                              border: Border.all(color: retroInk, width: 3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: retroBrown,
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '.' * (step % 4),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: retroBrown,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// เวลานับขึ้นแบบสด "รอมา 5:12 นาที" ใช้ทั้งฝั่งร้านและลูกค้า
class ElapsedText extends StatefulWidget {
  final DateTime since;
  final String prefix;
  final TextStyle? style;
  const ElapsedText({
    super.key,
    required this.since,
    this.prefix = 'รอมา ',
    this.style,
  });
  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var d = DateTime.now().difference(widget.since);
    if (d.isNegative) d = Duration.zero; // นาฬิกาเครื่องช้ากว่าเซิร์ฟเวอร์เล็กน้อย
    final m = d.inMinutes;
    final text = m >= 60
        ? '${d.inHours} ชม. ${m % 60} นาที'
        : '$m:${(d.inSeconds % 60).toString().padLeft(2, '0')} นาที';
    return Text(
      '${widget.prefix}$text',
      style: widget.style ??
          const TextStyle(fontWeight: FontWeight.bold, color: retroBrown),
    );
  }
}
