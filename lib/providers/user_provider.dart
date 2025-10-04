import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = true;
  String? _error;
  final AuthService _authService = AuthService();

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  // INITIALISATION AVEC VÉRIFICATION RENFORCÉE
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _clearError();
      
      print('🔍 UserProvider - Vérification de l\'utilisateur actuel...');
      
      // Vérifier d'abord l'état Firebase
      final auth = FirebaseAuth.instance;
      final firebaseUser = auth.currentUser;
      
      if (firebaseUser != null) {
        print('👤 Firebase user trouvé: ${firebaseUser.uid}');
        
        // Récupérer les données fraîches depuis Firestore
        UserModel? currentUser = await _authService.getCurrentUser();
        
        if (currentUser != null) {
          print('✅ Utilisateur valide: ${currentUser.email} - Rôle: ${currentUser.role}');
          _user = currentUser;
          _clearError();
        } else {
          print('❌ Utilisateur Firebase mais pas de données Firestore');
          _user = null;
          _setError('Données utilisateur non trouvées');
        }
      } else {
        print('🔒 Aucun utilisateur Firebase connecté');
        _user = null;
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation UserProvider: $e');
      _setError('Erreur lors du chargement de l\'utilisateur');
      _user = null;
    } finally {
      _setLoading(false);
    }
  }

  // DÉCONNEXION COMPLÈTE
  Future<void> signOut() async {
    try {
      _setLoading(true);
      
      print('🚪 UserProvider - Déconnexion en cours...');
      await _authService.signOut();
      
      _user = null;
      _clearError();
      
      print('✅ UserProvider - Déconnexion réussie');
      
    } catch (e) {
      print('❌ UserProvider - Erreur lors de la déconnexion: $e');
      _setError('Erreur lors de la déconnexion');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // CONNEXION
  Future<void> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();
      
      print('🔐 UserProvider - Tentative de connexion: $email');
      
      UserModel? user = await _authService.signIn(email, password);
      
      if (user != null) {
        print('✅ UserProvider - Connexion réussie: ${user.email} - Rôle: ${user.role}');
        _user = user;
        _clearError();
      } else {
        throw Exception('Échec de la connexion');
      }
    } catch (e) {
      print('❌ UserProvider - Erreur de connexion: $e');
      _setError(e.toString().replaceAll('Exception: ', ''));
      _user = null;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // INSCRIPTION ENSEIGNANT
  Future<void> signUpTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolName,
    required String className,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      print('👨‍🏫 UserProvider - Inscription enseignant: $email');
      
      UserModel user = await _authService.signUpTeacher(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        schoolName: schoolName,
        className: className,
      );
      
      print('✅ UserProvider - Inscription réussie: ${user.email}');
      _user = user;
      _clearError();
      
    } catch (e) {
      print('❌ UserProvider - Erreur inscription: $e');
      _setError(e.toString().replaceAll('Exception: ', ''));
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // INSCRIPTION PARENT - ADAPTÉE POUR STUDENTCODE
  Future<void> signUpParent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String studentCode, // ← CHANGEMENT : studentCode au lieu de studentId
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      print('👨‍👩‍👧‍👦 UserProvider - Inscription parent: $email');
      print('🔑 Code élève utilisé: $studentCode');
      
      UserModel user = await _authService.signUpParent(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        studentCode: studentCode, // ← CHANGEMENT
      );
      
      print('✅ UserProvider - Inscription parent réussie: ${user.email}');
      _user = user;
      _clearError();
      
    } catch (e) {
      print('❌ UserProvider - Erreur inscription parent: $e');
      _setError(e.toString().replaceAll('Exception: ', ''));
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // RAFRAÎCHISSEMENT DES DONNÉES UTILISATEUR
  Future<void> refreshUserData() async {
    try {
      print('🔄 UserProvider - Rafraîchissement des données utilisateur...');
      
      final updatedUser = await _authService.getCurrentUser();
      if (updatedUser != null) {
        _user = updatedUser;
        _clearError();
        print('✅ Données utilisateur rafraîchies: ${_user?.email} - Classes: ${_user?.classIds}');
      } else {
        print('⚠️ Aucun utilisateur trouvé lors du rafraîchissement');
        _user = null;
      }
      notifyListeners();
    } catch (e) {
      print('❌ Erreur rafraîchissement données: $e');
      _setError('Erreur lors du rafraîchissement des données');
    }
  }

  // MÉTHODES POUR MODIFIER L'ÉTAT DIRECTEMENT
  void setUser(UserModel user) {
    print('👤 UserProvider - Set user: ${user.email} - Rôle: ${user.role}');
    _user = user;
    _clearError();
    _setLoading(false);
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
    _clearError();
    _setLoading(false);
  }

  // MÉTHODES PRIVÉES POUR GÉRER L'ÉTAT INTERNE
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // VÉRIFICATION DE LA VALIDITÉ DE LA SESSION
  Future<bool> checkSessionValidity() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        print('🔒 Aucune session Firebase active');
        return false;
      }

      // Vérifier que l'utilisateur Firebase correspond à l'utilisateur dans le provider
      if (_user == null || _user!.uid != firebaseUser.uid) {
        print('🔄 Session non synchronisée, rechargement des données...');
        await refreshUserData();
      }

      return _user != null;
    } catch (e) {
      print('❌ Erreur vérification session: $e');
      return false;
    }
  }

  // RÉINITIALISATION COMPLÈTE
  void reset() {
    _user = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
    print('🔄 UserProvider - État réinitialisé');
  }

  // MISE À JOUR DU PROFIL UTILISATEUR
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? profileImageUrl,
  }) async {
    try {
      if (_user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      _setLoading(true);
      
      // Mettre à jour les données localement d'abord
      final updatedUser = UserModel(
        uid: _user!.uid,
        email: _user!.email,
        firstName: firstName ?? _user!.firstName,
        lastName: lastName ?? _user!.lastName,
        role: _user!.role,
        classIds: _user!.classIds,
        profileImageUrl: profileImageUrl ?? _user!.profileImageUrl,
        createdAt: _user!.createdAt,
      );

      _user = updatedUser;
      _clearError();
      
      print('✅ Profil utilisateur mis à jour localement');
      
    } catch (e) {
      print('❌ Erreur mise à jour profil: $e');
      _setError('Erreur lors de la mise à jour du profil');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // AJOUT D'UNE CLASSE (POUR ENSEIGNANTS)
  void addClass(String classId) {
    if (_user != null && _user!.role == 'teacher') {
      final updatedClassIds = List<String>.from(_user!.classIds)..add(classId);
      
      _user = UserModel(
        uid: _user!.uid,
        email: _user!.email,
        firstName: _user!.firstName,
        lastName: _user!.lastName,
        role: _user!.role,
        classIds: updatedClassIds,
        profileImageUrl: _user!.profileImageUrl,
        createdAt: _user!.createdAt,
      );
      
      notifyListeners();
      print('✅ Classe ajoutée: $classId - Total: ${updatedClassIds.length}');
    }
  }

  // SUPPRESSION D'UNE CLASSE (POUR ENSEIGNANTS)
  void removeClass(String classId) {
    if (_user != null && _user!.role == 'teacher') {
      final updatedClassIds = List<String>.from(_user!.classIds)..remove(classId);
      
      _user = UserModel(
        uid: _user!.uid,
        email: _user!.email,
        firstName: _user!.firstName,
        lastName: _user!.lastName,
        role: _user!.role,
        classIds: updatedClassIds,
        profileImageUrl: _user!.profileImageUrl,
        createdAt: _user!.createdAt,
      );
      
      notifyListeners();
      print('✅ Classe supprimée: $classId - Restantes: ${updatedClassIds.length}');
    }
  }

  // VÉRIFICATION DES PERMISSIONS
  bool canManageClass(String classId) {
    if (_user == null) return false;
    
    if (_user!.role == 'teacher') {
      return _user!.classIds.contains(classId);
    }
    
    return false;
  }

  bool canViewClass(String classId) {
    if (_user == null) return false;
    
    if (_user!.role == 'teacher') {
      return _user!.classIds.contains(classId);
    } else if (_user!.role == 'parent') {
      // Pour les parents, on vérifie via les données de l'élève
      // Cette logique sera implémentée dans le ParentHome
      return true;
    }
    
    return false;
  }

  // STATUT CONNEXION DÉTAILLÉ
  Map<String, dynamic> get connectionStatus {
    return {
      'isLoggedIn': isLoggedIn,
      'userEmail': _user?.email,
      'userRole': _user?.role,
      'hasClasses': _user?.classIds.isNotEmpty ?? false,
      'classCount': _user?.classIds.length ?? 0,
      'isLoading': _isLoading,
      'hasError': _error != null,
    };
  }

  // LOGS DÉTAILLÉS (pour le débogage)
  void printDebugInfo() {
    print('''
🧩 UserProvider - État actuel:
├── Utilisateur: ${_user?.email ?? 'Aucun'}
├── Rôle: ${_user?.role ?? 'N/A'}
├── Classes: ${_user?.classIds ?? []}
├── Chargement: $_isLoading
├── Erreur: $_error
└── Connecté: $isLoggedIn
    ''');
  }
}