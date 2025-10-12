import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Joussour/firebase_options.dart';
import 'package:Joussour/models/user_model.dart';
import 'package:Joussour/screens/parent/parent_home.dart';
import 'package:Joussour/screens/teacher/teacher_home.dart';
import 'package:Joussour/services/auth_service.dart';
import 'package:Joussour/services/fcm_service.dart';
import 'package:Joussour/services/pwa_service.dart';
import 'package:Joussour/widgets/pwa_install_dialog.dart';
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
  bool _checkingNotifications = false;
  bool _notificationChecked = false;
  bool _pwaDialogShown = false;
  bool _pwaChecked = false;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _trackUserSession();
  }

  Future<void> _initializeFCM() async {
    try {
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
        _isFcmInitialized = true;
      });
    }
  }

  Future<void> _trackUserSession() async {
    await PwaService.trackUserSession();
  }

  Future<void> _checkAndRequestNotifications(String userId) async {
    if (_checkingNotifications || _notificationChecked) return;
    
    setState(() {
      _checkingNotifications = true;
    });

    try {
      print('🔍 Vérification token FCM pour: $userId');
      
      final tokenDoc = await FirebaseFirestore.instance
          .collection('user_fcm_tokens')
          .doc(userId)
          .get();

      final hasValidToken = tokenDoc.exists && 
                          tokenDoc.data()?['token'] != null && 
                          (tokenDoc.data()?['token'] as String).isNotEmpty &&
                          (tokenDoc.data()?['token'] as String).length > 10;

      if (!hasValidToken && mounted) {
        print('⚠️ Token FCM manquant ou invalide pour: $userId');
        
        _notificationChecked = true;
        
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => _buildNotificationPermissionScreen(userId),
          ),
          (route) => false,
        );
        
      } else {
        print('✅ Token FCM valide présent pour: $userId');
        _notificationChecked = true;
      }
    } catch (e) {
      print('❌ Erreur vérification notifications: $e');
      _notificationChecked = true;
    } finally {
      if (mounted) {
        setState(() {
          _checkingNotifications = false;
        });
      }
    }
  }

  Future<void> _checkPwaInstall() async {
    if (_pwaChecked || _pwaDialogShown) return;

    // Attendre que l'app soit chargée
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;

    final shouldShowPwa = await PwaService.shouldShowPromptWithConditions(
      minSessionCount: 2,
      minSessionDuration: const Duration(minutes: 1), // Réduit pour les tests
    );

    if (shouldShowPwa) {
      setState(() {
        _pwaDialogShown = true;
        _pwaChecked = true;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPwaInstallDialog();
      });
    } else {
      _pwaChecked = true;
    }
  }

  void _showPwaInstallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PwaInstallDialog(
        onInstall: () {
          print('✅ Utilisateur a choisi d\'installer la PWA');
        },
        onDismiss: () {
          print('📅 Installation PWA reportée');
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _pwaDialogShown = false;
        });
      }
    });
  }

  Widget _buildNotificationPermissionScreen(String userId) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_active,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Activer les notifications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Pour recevoir des notifications instantanées quand vous recevez de nouveaux messages',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await _enableNotifications(userId);
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => _buildMainApp()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Activer les notifications',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _notificationChecked = true;
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => _buildMainApp()),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  'Configurer plus tard',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enableNotifications(String userId) async {
    try {
      await FCMService.initialize();
      await FCMService.saveUserFCMToken(userId);
      _notificationChecked = true;
      print('✅ Notifications activées pour: $userId');
    } catch (e) {
      print('❌ Erreur activation notifications: $e');
    }
  }

  Widget _buildMainApp() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    if (user != null) {
      return RoleBasedHome(user: user);
    } else {
      return const LoginScreen();
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
        print('🔄 AuthWrapper - Vérification notifications: $_checkingNotifications');
        print('🔄 AuthWrapper - Notification déjà vérifiée: $_notificationChecked');
        print('🔄 AuthWrapper - PWA dialog affiché: $_pwaDialogShown');

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
          
          // VÉRIFIER LES NOTIFICATIONS UNE SEULE FOIS
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_checkingNotifications && !_notificationChecked) {
              _checkAndRequestNotifications(providerUser.uid);
            }
          });

          // VÉRIFIER PWA UNE SEULE FOIS
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_pwaChecked && !_pwaDialogShown) {
              _checkPwaInstall();
            }
          });
          
          // SAUVEGARDER LE TOKEN FCM
          _saveFCMTokenForUser(providerUser.uid);
          
          return _buildMainApp();
        }

        // CAS 4: Déconnecté - Vérifier PWA quand même
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_pwaChecked && !_pwaDialogShown) {
            _checkPwaInstall();
          }
        });

        print('🔒 Aucun utilisateur connecté - Affichage LoginScreen');
        return const LoginScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    String loadingText = 'Chargement...';
    
    if (!_isFcmInitialized) {
      loadingText = 'Initialisation des notifications...';
    } else if (_checkingNotifications) {
      loadingText = 'Configuration des notifications...';
    } else if (_pwaDialogShown) {
      loadingText = 'Préparation de l\'application...';
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              loadingText,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (_pwaDialogShown) ...[
              const SizedBox(height: 10),
              const Text(
                'Installation PWA en cours...',
                style: TextStyle(fontSize: 14, color: Colors.blue),
              ),
            ],
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
        
        // Réinitialiser les flags
        _notificationChecked = false;
        _pwaChecked = false;
        
      } else {
        print('⚠️ Synchronisation échouée - données non trouvées');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<UserProvider>(context, listen: false).clearUser();
        });
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
      print('✅ Token FCM sauvegardé pour: $userId');
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