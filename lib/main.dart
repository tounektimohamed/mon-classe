import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/models/user_model.dart';
import 'package:mon_classe_manegment/screens/parent/parent_home.dart';
import 'package:mon_classe_manegment/screens/teacher/teacher_home.dart';
import 'package:mon_classe_manegment/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<UserModel?>(
            future: AuthService().getCurrentUser(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (userSnapshot.hasData && userSnapshot.data != null) {
                // Mettre à jour le provider avec l'utilisateur actuel
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Provider.of<UserProvider>(context, listen: false)
                      .setUser(userSnapshot.data!);
                });
                
                return RoleBasedHome(user: userSnapshot.data!);
              }
              
              // Si pas d'utilisateur dans Firestore mais connecté à Firebase
              // Cela peut arriver, on déconnecte
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AuthService().signOut();
                Provider.of<UserProvider>(context, listen: false).clearUser();
              });
              
              return const LoginScreen();
            },
          );
        }
        
        // Pas connecté
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<UserProvider>(context, listen: false).clearUser();
        });
        
        return const LoginScreen();
      },
    );
  }
}

class RoleBasedHome extends StatelessWidget {
  final UserModel user;

  const RoleBasedHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Vérifier le rôle et rediriger
    if (user.role == 'teacher') {
      return const TeacherHome();
    } else if (user.role == 'parent') {
      return const ParentHome();
    } else {
      // Si rôle inconnu, déconnecter
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AuthService().signOut();
        Provider.of<UserProvider>(context, listen: false).clearUser();
      });
      return const LoginScreen();
    }
  }
}