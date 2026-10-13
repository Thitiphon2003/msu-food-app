import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  // เรยกี ครัง้เดยวี ตอนเปิดแอป กอน่ เรยกี authenticate() เสมอ
  // serverClientId คอื Web client ID ทคี่ ดั ลอกมาในขอ้ 3.6
  static Future<void> init(String serverClientId) async {
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
  }

  // กระแสขอม้ ลู สถานะผใชู้ ้ใชก้บั AuthGate
  Stream<User?> get userChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  // คนื null เมอื่ สํา เร็จ คนื ขอความ ้ เมอื่ เกดิขอ้ผดิ พลาด
  Future<String?> signInWithGoogle() async {
    try {
      // ขนั้ ที่ 1 เปิดหนาต้ าง่ ใหผ้ ใชู้ เล้ อกื บญช ั ีGoogle
      final googleUser = await GoogleSignIn.instance.authenticate();
      // ขนั้ ที่ 2 ดงึ idToken ที่ Google ออกให้
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        return 'ไม่ได้รับ idToken ตรวจสอบค่า serverClientId';
      }
      // ขนั้ ที่ 3 หอ่ idToken เป็น credential ของ Firebase
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      // ขนั้ ที่ 4 เขา้สระบบ ู่ ถา้ยงัไมม่ บี ญช ั จะี สราง้ ใหอ้ตโนม ั ตั ิ
      await _auth.signInWithCredential(credential);
      return null;
    } on GoogleSignInException catch (e) {
      // ผใชู้ กด้ ยกเลกิเอง ไมถ่ อืเป็นขอ้ผดิ พลาด
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      return 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ (${e.code.name})';
    } on FirebaseAuthException catch (e) {
      return 'Firebase ปฏิเสธการเข้าสู่ระบบ (${e.code})';
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
