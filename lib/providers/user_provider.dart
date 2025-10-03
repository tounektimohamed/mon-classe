import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = true;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // INITIALISATION AVEC VÉRIFICATION RENFORCÉE
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      print('🔍 UserProvider - Vérification de l\'utilisateur actuel...');
      
      // Vérifier d'abord l'état Firebase
      final auth = FirebaseAuth.instance;
      final firebaseUser = auth.currentUser;
      
      if (firebaseUser != null) {
        print('👤 Firebase user trouvé: ${firebaseUser.uid}');
        
        // Récupérer les données fraîches depuis Firestore
        UserModel? currentUser = await AuthService().getCurrentUser();
        
        if (currentUser != null) {
          print('✅ Utilisateur valide: ${currentUser.email} - Rôle: ${currentUser.role}');
          _user = currentUser;
          _error = null;
        } else {
          print('❌ Utilisateur Firebase mais pas de données Firestore - Déconnexion forcée');
          await AuthService().forceSignOut();
          _user = null;
        }
      } else {
        print('🔒 Aucun utilisateur Firebase connecté');
        _user = null;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation UserProvider: $e');
      _error = 'Erreur lors du chargement de l\'utilisateur';
      _user = null;
      
      // En cas d'erreur, forcer la déconnexion
      try {
        await AuthService().forceSignOut();
      } catch (e) {
        print('Erreur lors de la déconnexion de secours: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // DÉCONNEXION COMPLÈTE
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      print('🚪 UserProvider - Déconnexion en cours...');
      await AuthService().forceSignOut();
      
      _user = null;
      _error = null;
      _isLoading = false;
      
      print('✅ UserProvider - Déconnexion réussie');
      notifyListeners();
      
    } catch (e) {
      print('❌ UserProvider - Erreur lors de la déconnexion: $e');
      _error = 'Erreur lors de la déconnexion';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // CONNEXION AVEC NETTOYAGE
  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      print('🔐 UserProvider - Tentative de connexion: $email');
      
      // Utiliser le AuthService pour la connexion
      UserModel? user = await AuthService().signIn(email, password);
      
      if (user != null) {
        print('✅ UserProvider - Connexion réussie: ${user.email} - Rôle: ${user.role}');
        _user = user;
        _error = null;
      } else {
        throw Exception('Échec de la connexion');
      }
    } catch (e) {
      print('❌ UserProvider - Erreur de connexion: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _user = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUser(UserModel user) {
    print('👤 UserProvider - Set user: ${user.email} - Rôle: ${user.role}');
    _user = user;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}