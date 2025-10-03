import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Utiliser idTokenChanges pour plus de fiabilité
  Stream<User?> get authStateChanges => _auth.idTokenChanges();

  // Connexion
  Future<UserModel?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Attendre un peu pour que Firebase se synchronise
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Récupérer les données utilisateur depuis Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .get();
      
      if (userDoc.exists) {
        return UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Inscription Enseignant
  Future<UserModel> signUpTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String schoolName,
  }) async {
    try {
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

      return teacher;
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  // Inscription Parent
  Future<UserModel> signUpParent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String studentId,
  }) async {
    try {
      // Vérifier d'abord si l'élève existe
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

      return parent;
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  // Déconnexion - VERSION CORRIGÉE
  Future<void> signOut() async {
    try {
      // Nettoyer le cache Firebase d'abord
      await _auth.signOut();
      
      // Attendre que la déconnexion soit complète
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Forcer un refresh du token
      await _auth.currentUser?.reload();
    } catch (e) {
      throw Exception('Erreur de déconnexion: $e');
    }
  }

  // Méthode pour récupérer l'utilisateur actuel
  Future<UserModel?> getCurrentUser() async {
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        
        if (userDoc.exists) {
          return UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}