import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/firebase_options.dart';
import 'package:mon_classe_manegment/screens/parent/parent_home.dart';
import 'package:mon_classe_manegment/screens/teacher/teacher_home.dart';
import 'package:mon_classe_manegment/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/login_screen.dart';

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'Classroom CRM',
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData) {
          return const RoleBasedHome();
        }
        
        return const LoginScreen();
      },
    );
  }
}

class RoleBasedHome extends StatelessWidget {
  const RoleBasedHome({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    if (userProvider.user?.role == 'teacher') {
      return const TeacherHome();
    } else if (userProvider.user?.role == 'parent') {
      return const ParentHome();
    } else {
      return const LoginScreen();
    }
  }
}