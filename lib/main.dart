import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Web ke liye alag FirebaseOptions
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCeUecZLtf8oB-p3u8jur_Hd-YBQZ3T8Ps",
        authDomain: "chargers-aa43e.firebaseapp.com",
        projectId: "chargers-aa43e",
        storageBucket: "chargers-aa43e.firebasestorage.app",
        messagingSenderId: "272450899801",
        appId: "1:272450899801:web:72966c44dd341e8b0a4648",
        measurementId: "G-DDSS389L7E"
      ),
    );
  } else {
    // Android ke liye
    await Firebase.initializeApp();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) =>  SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}