import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:Joussour/firebase_options.dart';
import 'package:Joussour/models/user_model.dart';
import 'package:Joussour/screens/parent/parent_home.dart';
import 'package:Joussour/screens/teacher/teacher_home.dart';
import 'package:Joussour/services/auth_service.dart';
import 'package:Joussour/services/fcm_service.dart';
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
    
    // Initialiser FCM
    await FCMService.initialize();
    print('✅ FCM initialisé avec succès');
    
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
          visualDensity: VisualDensity.adaptivePlatformDensity,
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
  bool _isFcmInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    try {
      // Vérifier si FCM est déjà initialisé
      if (!_isFcmInitialized) {
        await FCMService.initialize();
        setState(() {
          _isFcmInitialized = true;
        });
        print('✅ FCM initialisé dans AuthWrapper');
      }
    } catch (e) {
      print('❌ Erreur initialisation FCM dans AuthWrapper: $e');
      setState(() {
        _isFcmInitialized = true; // Continuer même si FCM échoue
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        print('🔄 AuthWrapper - Firebase user: ${authSnapshot.data?.email}');
        print('🔄 AuthWrapper - Provider user: ${userProvider.user?.email}');
        print('🔄 AuthWrapper - Provider loading: ${userProvider.isLoading}');
        print('🔄 AuthWrapper - FCM initialisé: $_isFcmInitialized');

        // Écran de chargement
        if (authSnapshot.connectionState == ConnectionState.waiting || 
            userProvider.isLoading ||
            !_isFcmInitialized) {
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
          
          // Sauvegarder le token FCM pour l'utilisateur connecté
          _saveFCMTokenForUser(providerUser.uid);
          
          return RoleBasedHome(user: providerUser);
        }

        // CAS 4: Déconnecté
        print('🔒 Aucun utilisateur connecté - Affichage LoginScreen');
        return const LoginScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _isFcmInitialized ? 'Chargement...' : 'Initialisation des notifications...',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
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
        
        // Sauvegarder le token FCM après synchronisation
        _saveFCMTokenForUser(user.uid);
      } else {
        print('⚠️ Synchronisation échouée - données non trouvées');
        // Réessayer après un délai
        await Future.delayed(const Duration(seconds: 2));
        
        final userRetry = await AuthService().getCurrentUser();
        if (userRetry != null && mounted) {
          print('✅ Synchronisation réussie au 2ème essai: ${userRetry.email}');
          Provider.of<UserProvider>(context, listen: false).setUser(userRetry);
          
          // Sauvegarder le token FCM après synchronisation
          _saveFCMTokenForUser(userRetry.uid);
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

  Future<void> _saveFCMTokenForUser(String userId) async {
    try {
      await FCMService.saveUserFCMToken(userId);
      print('✅ Token FCM sauvegardé pour l\'utilisateur: $userId');
    } catch (e) {
      print('❌ Erreur sauvegarde token FCM: $e');
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