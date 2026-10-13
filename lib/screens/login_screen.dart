import 'package:flutter/material.dart';
import 'package:msu_food/services/auth_service.dart';
import 'package:msu_food/widgets/retro.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final error = await _auth.signInWithGoogle();
    // mounted ตรวจว่าหน้าจอยังอยู่หรือไม่ ป้องกัน setState หลังหน้าจอถูกปิดไปแล้ว
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 36, 32), // ขวาเผื่อเงาพิกเซล
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // โลโก้วาดเองด้วยไอคอน ไม่พึ่งรูปจากเน็ต (ออฟไลน์/ลิงก์เสียก็ไม่พัง)
                const PixelBox(
                  color: retroYellow,
                  padding: EdgeInsets.all(26),
                  child: Icon(Icons.ramen_dining_rounded, size: 72, color: retroInk),
                ),
                const SizedBox(height: 28),
                const Text(
                  'MSU FOOD',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: retroBrown,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'สั่งอาหารในมหาวิทยาลัย',
                  style: TextStyle(color: retroBrown),
                ),
                const SizedBox(height: 40),
                _busy
                    ? const SizedBox(height: 80, child: PixelLoader(label: 'SIGNING IN'))
                    : PixelButton(
                        label: 'เข้าสู่ระบบด้วย Google',
                        icon: Icons.login_rounded,
                        expand: true,
                        onPressed: _signIn,
                      ),
                const SizedBox(height: 20),
                const Blink(
                  child: Text(
                    '> PRESS START <',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: retroBrown,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
