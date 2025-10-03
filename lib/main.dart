import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/firebase_options.dart';
import 'package:mon_classe_manegment/models/user_model.dart';
import 'package:mon_classe_manegment/screens/parent/parent_home.dart';
import 'package:mon_classe_manegment/screens/teacher/teacher_home.dart';
import 'package:mon_classe_manegment/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialisé avec succès');
  } catch (e) {
    print('❌ Erreur initialisation Firebase: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider()..initialize(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'Joussour',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
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
    final userProvider = Provider.of<UserProvider>(context);
    
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        print('🔄 AuthWrapper - Firebase user: ${authSnapshot.data?.email}');
        print('🔄 AuthWrapper - Provider user: ${userProvider.user?.email}');
        print('🔄 AuthWrapper - Provider loading: ${userProvider.isLoading}');

        // Écran de chargement
        if (authSnapshot.connectionState == ConnectionState.waiting || 
            userProvider.isLoading) {
          return _buildLoadingScreen();
        }

        final firebaseUser = authSnapshot.data;
        final providerUser = userProvider.user;

        // CAS 1: Incohérence - Firebase a un user mais pas le Provider
        if (firebaseUser != null && providerUser == null) {
          print('⚠️ Incohérence: Firebase connecté mais Provider vide');
          print('🔍 User ID: ${firebaseUser.uid}');
          _syncUserFromFirebase(firebaseUser.uid);
          return _buildLoadingScreen();
        }

        // CAS 2: Incohérence - Firebase déconnecté mais Provider a un user
        if (firebaseUser == null && providerUser != null) {
          print('⚠️ Incohérence: Firebase déconnecté mais Provider a un user');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            userProvider.clearUser();
          });
          return _buildLoadingScreen();
        }

        // CAS 3: Utilisateur connecté et cohérent
        if (providerUser != null && firebaseUser != null) {
          print('✅ Utilisateur cohérent: ${providerUser.email} - Rôle: ${providerUser.role}');
          return RoleBasedHome(user: providerUser);
        }

        // CAS 4: Déconnecté
        print('🔒 Aucun utilisateur connecté - Affichage LoginScreen');
        return const LoginScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Chargement...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _syncUserFromFirebase(String uid) async {
    try {
      print('🔄 Synchronisation depuis Firebase: $uid');
      final user = await AuthService().getCurrentUser();
      
      if (user != null && mounted) {
        print('✅ Synchronisation réussie: ${user.email}');
        Provider.of<UserProvider>(context, listen: false).setUser(user);
      } else {
        print('⚠️ Synchronisation échouée - données non trouvées');
        // Réessayer après un délai
        await Future.delayed(const Duration(seconds: 2));
        
        final userRetry = await AuthService().getCurrentUser();
        if (userRetry != null && mounted) {
          print('✅ Synchronisation réussie au 2ème essai: ${userRetry.email}');
          Provider.of<UserProvider>(context, listen: false).setUser(userRetry);
        } else {
          print('❌ Échec définitif de synchronisation');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<UserProvider>(context, listen: false).clearUser();
          });
        }
      }
    } catch (e) {
      print('❌ Erreur synchronisation: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<UserProvider>(context, listen: false).clearUser();
      });
    }
  }
}

class RoleBasedHome extends StatelessWidget {
  final UserModel user;
  
  const RoleBasedHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    print('🎯 Redirection vers l\'écran ${user.role}');
    
    switch (user.role) {
      case 'teacher':
        return const TeacherHome();
      case 'parent':
        return const ParentHome();
      default:
        print('❌ Rôle inconnu: ${user.role}');
        return const LoginScreen();
    }
  }
}