import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/retro.dart'; // ปรับ path ตามที่วาง retro.dart จริง

const _usersCollection = 'users'; // ปรับให้ตรงชื่อ collection ของคุณ
const _brown = Color(0xFF4A3B2E);
const _paper = Color(0xFFFFF8EA);

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลูกค้าที่สมัครแล้ว'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: Divider(height: 3, thickness: 3, color: retroInk),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(_usersCollection).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('ผิดพลาด: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('- NO PLAYERS -\nยังไม่มีลูกค้าสมัคร',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: _brown)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 24), // ขวาเผื่อเงาพิกเซล
            itemCount: docs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: PixelBox(
                    color: retroYellow,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text('PLAYERS × ${docs.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: retroInk)),
                  ),
                );
              }
              final d = docs[i - 1].data();
              final name = (d['name'] ?? d['displayName'] ?? 'ไม่ระบุชื่อ').toString();
              final contact = (d['email'] ?? d['phone'] ?? '').toString();
              return PixelBox(
                color: _paper,
                child: Row(
                  children: [
                    // อวาตาร์สี่เหลี่ยมแทนวงกลม
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1E4D3),
                        border: Border.all(color: retroInk, width: 2),
                      ),
                      child: Text(name.isEmpty ? '?' : name[0],
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _brown)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: _brown)),
                          if (contact.isNotEmpty) Text(contact, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}