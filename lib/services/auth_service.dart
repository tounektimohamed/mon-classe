import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // FORCER LA DÉCONNEXION COMPLÈTE
  Future<void> forceSignOut() async {
    try {
      print('🚪 Déconnexion forcée en cours...');
      
      // Méthode agressive pour garantir la déconnexion
      await _auth.signOut();
      
      // Attendre que Firebase traite la déconnexion
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Vérifier que la déconnexion est effective
      if (_auth.currentUser != null) {
        print('⚠️ User toujours connecté, nouvelle tentative...');
        await _auth.signOut();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      print('✅ Déconnexion forcée réussie');
    } catch (e) {
      print('❌ Erreur forceSignOut: $e');
      rethrow;
    }
  }

  // CONNEXION AVEC NETTOYAGE COMPLET
  Future<UserModel?> signIn(String email, String password) async {
    try {
      print('🔐 Tentative de connexion: $email');

      // S'assurer d'être déconnecté avant de se connecter
      if (_auth.currentUser != null) {
        print('🔄 Nettoyage de la session précédente...');
        await forceSignOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Configurer la persistance
      await _auth.setPersistence(Persistence.LOCAL);
      
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Attendre que l'authentification soit complète
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Recharger l'utilisateur pour s'assurer des données fraîches
      await result.user?.reload();
      User? freshUser = _auth.currentUser;
      
      if (freshUser == null) {
        throw Exception('Échec de la connexion');
      }

      print('✅ Firebase auth réussie, récupération des données Firestore...');

      // Récupérer les données utilisateur depuis Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(freshUser.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userModel = UserModel.fromMap(userData);
        print('✅ Utilisateur connecté: ${userModel.email} - Rôle: ${userModel.role}');
        return userModel;
      }
      
      throw Exception('Profil utilisateur non trouvé');
      
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code}');
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      print('❌ Erreur de connexion: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  // INSCRIPTION ENSEIGNANT
  Future<UserModel> signUpTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolName,
  }) async {
    try {
      print('👨‍🏫 Inscription enseignant: $email');

      // Vérifier d'abord si l'email existe déjà
      try {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: 'temporary_password',
        );
        throw Exception('Un compte avec cet email existe déjà.');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Email disponible, continuer
        } else if (e.code == 'wrong-password') {
          throw Exception('Un compte avec cet email existe déjà.');
        } else {
          throw Exception(_getAuthErrorMessage(e.code));
        }
      }

      // Configurer la persistance
      await _auth.setPersistence(Persistence.LOCAL);

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Créer une nouvelle classe
      DocumentReference classRef = await _firestore.collection('classes').add({
        'name': 'Classe de $firstName $lastName',
        'schoolName': schoolName,
        'teacherId': result.user!.uid,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Créer le profil enseignant
      UserModel teacher = UserModel(
        uid: result.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: 'teacher',
        classId: classRef.id,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .set(teacher.toMap());

      print('✅ Enseignant inscrit: ${teacher.email}');
      return teacher;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Un compte avec cet email existe déjà.');
      }
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Erreur d\'inscription enseignant: $e');
    }
  }

  // INSCRIPTION PARENT
  Future<UserModel> signUpParent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String studentId,
  }) async {
    try {
      print('👨‍👩‍👧‍👦 Inscription parent: $email');

      // Vérifier d'abord si l'email existe déjà
      try {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: 'temporary_password',
        );
        throw Exception('Un compte avec cet email existe déjà.');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Email disponible, continuer
        } else if (e.code == 'wrong-password') {
          throw Exception('Un compte avec cet email existe déjà.');
        } else {
          throw Exception(_getAuthErrorMessage(e.code));
        }
      }

      // Vérifier si l'élève existe
      DocumentSnapshot studentDoc = await _firestore
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        throw Exception('Code élève invalide. Vérifiez le code et réessayez.');
      }

      // Vérifier si l'élève a déjà un parent
      final studentData = studentDoc.data() as Map<String, dynamic>?;
      if (studentData != null && studentData['parentId'] != null) {
        throw Exception('Cet élève est déjà associé à un compte parent.');
      }

      // Configurer la persistance
      await _auth.setPersistence(Persistence.LOCAL);

      // Créer le compte utilisateur
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Lier le parent à l'élève
      await _firestore
          .collection('students')
          .doc(studentId)
          .update({
            'parentId': result.user!.uid,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      // Créer le profil parent
      UserModel parent = UserModel(
        uid: result.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: 'parent',
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .set(parent.toMap());

      print('✅ Parent inscrit: ${parent.email}');
      return parent;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Un compte avec cet email existe déjà.');
      }
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Erreur d\'inscription parent: $e');
    }
  }

  // DÉCONNEXION
  Future<void> signOut() async {
    try {
      await forceSignOut();
    } catch (e) {
      throw Exception('Erreur de déconnexion: $e');
    }
  }

  // VÉRIFIER L'UTILISATEUR ACTUEL AVEC DONNÉES FRAÎCHES
  Future<UserModel?> getCurrentUser() async {
    try {
      User? firebaseUser = _auth.currentUser;
      
      if (firebaseUser != null) {
        print('🔍 Vérification utilisateur actuel: ${firebaseUser.uid}');
        
        // Recharger pour s'assurer des données à jour
        await firebaseUser.reload();
        firebaseUser = _auth.currentUser;
        
        if (firebaseUser != null) {
          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userModel = UserModel.fromMap(userData);
            print('✅ Utilisateur actuel: ${userModel.email} - Rôle: ${userModel.role}');
            return userModel;
          } else {
            print('❌ Données Firestore non trouvées pour l\'utilisateur');
          }
        }
      } else {
        print('🔒 Aucun utilisateur Firebase connecté');
      }
      return null;
    } catch (e) {
      print('❌ Erreur getCurrentUser: $e');
      return null;
    }
  }

  // RÉCUPÉRER L'UTILISATEUR PAR UID
  Future<UserModel?> getUserById(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      
      if (userDoc.exists) {
        return UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ Erreur getUserById: $e');
      return null;
    }
  }

  // MESSAGES D'ERREUR D'AUTHENTIFICATION
  String _getAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'weak-password':
        return 'Le mot de passe est trop faible (minimum 6 caractères).';
      case 'email-already-in-use':
        return 'Un compte avec cet email existe déjà.';
      case 'invalid-email':
        return 'L\'adresse email est invalide.';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'network-request-failed':
        return 'Erreur de connexion internet. Vérifiez votre connexion.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'operation-not-allowed':
        return 'L\'authentification par email/mot de passe n\'est pas activée. Contactez l\'administrateur.';
      default:
        return 'Une erreur est survenue: $errorCode';
    }
  }
}