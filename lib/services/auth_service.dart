import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Connexion
  Future<UserModel?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
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
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Lier le parent à l'élève
      await _firestore
          .collection('students')
          .doc(studentId)
          .update({'parentId': result.user!.uid});

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

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }
}