import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'package:msu_food/widgets/retro.dart';


// นํา คา่ นมาี้ จาก Firebase Console ตามขอ้ 3.6
const String kServerClientId ='926132297615-0s5fkea1eeiprb0k2m6cp318p1ftgl22.apps.googleusercontent.com';
Future<void> main() async {
  // เตรยมี สวน่ เชอมื่ ตอ่ กบั ระบบปฏบิ ตั การ ิ ใหพร ้ อม้
  // จํา เป็นเมอื่ ตอง้ เรยกี โคดฝ้ ั่ง Native กอน่ runApp() จะทํา งาน

  WidgetsFlutterBinding.ensureInitialized();
  // เชอมื่ ตอ่ กบั โปรเจกต์ Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // เตรยมี GoogleSignIn ใหพร ้ อม้ ตอง้ ทํา กอน่ เรยกี authenticate()
  await AuthService.init(kServerClientId);
  runApp(const MsuFoodApp());
}

class MsuFoodApp extends StatelessWidget {
  const MsuFoodApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSU Food',
      debugShowCheckedModeBanner: false,
       theme: buildRetroTheme(),
      // สามสวน่ นที้ ํา ใหกล้ อง่ โตตอบ ้ มาตรฐานแสดงเป็นภาษาไทย
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('th'), Locale('en')],
      locale: const Locale('th'),
      home: const AuthGate(),
    );
    
  }
}
