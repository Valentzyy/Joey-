import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/welcome_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart';
import 'screens/task_list_page.dart';
import 'models/category_item.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskFlow',
      theme: ThemeData(
        useMaterial3: true, // Biar icon + widget tidak error
        primaryColor: const Color(0xFF8B6F47),
        scaffoldBackgroundColor: Colors.white,

        // Set default icon color supaya tidak jadi X
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
      ),

      home: const WelcomePage(),

      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/task-list') {
          final args = settings.arguments as CategoryItem;
          return MaterialPageRoute(
            builder: (context) => TaskListPage(category: args),
          );
        }
        return null;
      },
    );
  }
}
