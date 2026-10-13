import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:msu_food/screens/login_screen.dart';
import 'package:msu_food/screens/role_gate.dart';
import 'package:msu_food/services/auth_service.dart';
import 'package:msu_food/widgets/retro.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: PixelLoader());
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        // เข้าสู่ระบบแล้ว ส่งต่อให้ด่านที่สอง ตรวจบทบาท
        return RoleGate(user: user);
      },
    );
  }
}
