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
      await _auth.signOut();
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
      print('✅ Déconnexion forcée réussie');
    } catch (e) {
      print('❌ Erreur forceSignOut: $e');
      rethrow;
    }
  }

  // INSCRIPTION ENSEIGNANT - CORRIGÉE POUR MULTIPLES CLASSES
  Future<UserModel> signUpTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolName,
    required String className,
  }) async {
    try {
      print('👨‍🏫 Inscription enseignant: $email');

      // Configurer la persistance
      await _auth.setPersistence(Persistence.LOCAL);

      // Créer l'utilisateur
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Compte Firebase créé: ${result.user!.uid}');

      // Attendre la synchronisation Firebase
      await Future.delayed(const Duration(seconds: 1));
      await result.user!.reload();
      
      // Vérifier que l'utilisateur est bien authentifié
      if (_auth.currentUser == null) {
        throw Exception('Erreur de création de compte');
      }

      final classNameFinal = className.isEmpty ? 'Classe de $firstName $lastName' : className;
      
      // Vérifier si une classe avec le même nom existe déjà
      final existingClassQuery = await _firestore
          .collection('classes')
          .where('schoolName', isEqualTo: schoolName)
          .where('name', isEqualTo: classNameFinal)
          .get();

      if (existingClassQuery.docs.isNotEmpty) {
        await result.user!.delete();
        throw Exception('Une classe avec ce nom existe déjà dans cette école.');
      }

      // Créer une nouvelle classe
      DocumentReference classRef = _firestore.collection('classes').doc();
      await classRef.set({
        'id': classRef.id,
        'name': classNameFinal,
        'schoolName': schoolName,
        'teacherId': result.user!.uid,
        'teacherEmail': email,
        'teacherName': '$firstName $lastName',
        'description': 'Classe créée par $firstName $lastName',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'studentIds': [],
        'subject': '',
      });

      print('✅ Classe créée: ${classRef.id}');

      // Créer le profil enseignant avec classIds comme liste
      UserModel teacher = UserModel(
        uid: result.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: 'teacher',
        classIds: [classRef.id], // ← CHANGEMENT : Liste au lieu d'un seul ID
        createdAt: DateTime.now(),
      );

      // Sauvegarder dans Firestore
      await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .set(teacher.toMap());

      print('✅ Enseignant sauvegardé dans Firestore: ${teacher.email}');

      // Attendre la synchronisation Firestore
      await Future.delayed(const Duration(milliseconds: 500));

      return teacher;

    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Un compte avec cet email existe déjà.');
        case 'invalid-email':
          throw Exception('L\'adresse email est invalide.');
        case 'weak-password':
          throw Exception('Le mot de passe est trop faible (minimum 6 caractères).');
        case 'operation-not-allowed':
          throw Exception('L\'authentification par email/mot de passe n\'est pas activée.');
        default:
          throw Exception('Erreur d\'authentification: ${e.code}');
      }
    } catch (e) {
      print('❌ Erreur inscription enseignant: $e');
      throw Exception('Erreur d\'inscription: ${e.toString()}');
    }
  }

  // INSCRIPTION PARENT - CORRIGÉE
  // services/auth_service.dart - Modifiez la méthode signUpParent
Future<UserModel> signUpParent({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required String studentCode, // ← CHANGEMENT : studentCode au lieu de studentId
}) async {
  try {
    print('👨‍👩‍👧‍👦 Inscription parent avec code: $studentCode');

    // 1. Vérifier si le code existe dans student_codes
    final codeSnapshot = await _firestore
        .collection('student_codes')
        .where('code', isEqualTo: studentCode)
        .get();

    if (codeSnapshot.docs.isEmpty) {
      throw Exception('Code élève invalide. Vérifiez le code et réessayez.');
    }

    final codeData = codeSnapshot.docs.first.data();
    final studentId = codeData['studentId'];
    
    print('✅ Code valide trouvé pour l\'élève: $studentId');

    // 2. Vérifier si l'élève existe
    final studentDoc = await _firestore
        .collection('students')
        .doc(studentId)
        .get();

    if (!studentDoc.exists) {
      throw Exception('Élève non trouvé. Contactez l\'enseignant.');
    }

    // 3. Vérifier si l'élève a déjà un parent
    final studentData = studentDoc.data()!;
    if (studentData['parentId'] != null) {
      throw Exception('Cet élève est déjà associé à un compte parent.');
    }

    // 4. Configurer la persistance
    await _auth.setPersistence(Persistence.LOCAL);

    // 5. Créer le compte utilisateur
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    print('✅ Compte parent Firebase créé: ${result.user!.uid}');

    // 6. Attendre la synchronisation
    await Future.delayed(const Duration(seconds: 1));
    await result.user!.reload();

    // 7. Lier le parent à l'élève
    await _firestore
        .collection('students')
        .doc(studentId)
        .update({
          'parentId': result.user!.uid,
          'parentEmail': email,
          'parentName': '$firstName $lastName',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

    // 8. Supprimer le code utilisé (optionnel - pour éviter la réutilisation)
    await _firestore
        .collection('student_codes')
        .doc(codeSnapshot.docs.first.id)
        .delete();

    print('✅ Code utilisé supprimé: $studentCode');

    // 9. Créer le profil parent
    UserModel parent = UserModel(
      uid: result.user!.uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      role: 'parent',
      classIds: [studentData['classId']], // ← IMPORTANT : Ajouter classId
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(result.user!.uid)
        .set(parent.toMap());

    print('✅ Parent inscrit: ${parent.email}');
    
    // 10. Attendre la synchronisation
    await Future.delayed(const Duration(milliseconds: 500));
    
    return parent;

  } on FirebaseAuthException catch (e) {
    print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
    
    switch (e.code) {
      case 'email-already-in-use':
        throw Exception('Un compte avec cet email existe déjà.');
      case 'invalid-email':
        throw Exception('L\'adresse email est invalide.');
      case 'weak-password':
        throw Exception('Le mot de passe est trop faible (minimum 6 caractères).');
      default:
        throw Exception('Erreur d\'authentification: ${e.code}');
    }
  } catch (e) {
    print('❌ Erreur inscription parent: $e');
    throw Exception('Erreur d\'inscription parent: ${e.toString()}');
  }
}
  // CONNEXION - CORRIGÉE
  Future<UserModel?> signIn(String email, String password) async {
    try {
      // S'assurer d'être déconnecté avant de se connecter
      if (_auth.currentUser != null) {
        await forceSignOut();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await _auth.setPersistence(Persistence.LOCAL);
      
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Attendre la synchronisation
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Recharger l'utilisateur pour s'assurer des données fraîches
      await result.user?.reload();
      User? freshUser = _auth.currentUser;
      
      if (freshUser == null) {
        throw Exception('Échec de la connexion');
      }

      // Récupérer les données utilisateur depuis Firestore avec timeout
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(freshUser.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userModel = UserModel.fromMap(userData);
        print('✅ Utilisateur connecté: ${userModel.email} - Rôle: ${userModel.role}');
        print('📚 Classes de l\'enseignant: ${userModel.classIds}');
        return userModel;
      }
      
      throw Exception('Profil utilisateur non trouvé');
      
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
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

  // VÉRIFIER L'UTILISATEUR ACTUEL - CORRIGÉE
  Future<UserModel?> getCurrentUser() async {
    try {
      User? firebaseUser = _auth.currentUser;
      
      if (firebaseUser != null) {
        print('🔍 Vérification utilisateur Firebase: ${firebaseUser.uid}');
        
        // Recharger pour s'assurer des données à jour
        await firebaseUser.reload();
        firebaseUser = _auth.currentUser;
        
        if (firebaseUser != null) {
          print('📊 Récupération données Firestore pour: ${firebaseUser.uid}');
          
          // Ajouter un timeout pour éviter les blocages
          final userDoc = await _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .get()
              .timeout(const Duration(seconds: 10));
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userModel = UserModel.fromMap(userData);
            print('✅ Utilisateur trouvé: ${userModel.email} - Rôle: ${userModel.role}');
            print('📚 Classes: ${userModel.classIds}');
            return userModel;
          } else {
            print('❌ Données Firestore non trouvées pour l\'utilisateur ${firebaseUser.uid}');
            return null;
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

   // CRÉER UNE NOUVELLE CLASSE (pour enseignants existants)
  Future<void> createNewClass({
    required String teacherId,
    required String teacherName,
    required String teacherEmail,
    required String className,
    required String schoolName,
    String description = '',
    String subject = '',
  }) async {
    try {
      // Vérifier si une classe avec le même nom existe déjà
      final existingClassQuery = await _firestore
          .collection('classes')
          .where('schoolName', isEqualTo: schoolName)
          .where('name', isEqualTo: className)
          .get();

      if (existingClassQuery.docs.isNotEmpty) {
        throw Exception('Une classe avec ce nom existe déjà dans cette école.');
      }

      // Créer une nouvelle classe
      DocumentReference classRef = _firestore.collection('classes').doc();
      await classRef.set({
        'id': classRef.id,
        'name': className,
        'description': description,
        'schoolName': schoolName,
        'teacherId': teacherId,
        'teacherEmail': teacherEmail,
        'teacherName': teacherName,
        'subject': subject,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'studentIds': [],
      });

      // AJOUTER L'ID DE LA CLASSE À LA LISTE DE L'ENSEIGNANT
      await _firestore
          .collection('users')
          .doc(teacherId)
          .update({
            'classIds': FieldValue.arrayUnion([classRef.id])
          });

      print('✅ Nouvelle classe créée: $className (ID: ${classRef.id})');
    } catch (e) {
      print('❌ Erreur création classe: $e');
      rethrow;
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