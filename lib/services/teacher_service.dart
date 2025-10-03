import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class TeacherService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // RÉCUPÉRER TOUS LES ENSEIGNANTS
  Future<List<UserModel>> getAllTeachers() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Erreur récupération enseignants: $e');
      throw Exception('Erreur lors de la récupération des enseignants');
    }
  }

  // RÉCUPÉRER UN ENSEIGNANT PAR SON ID
  Future<UserModel?> getTeacherById(String teacherId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(teacherId)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération enseignant: $e');
      return null;
    }
  }

  // RÉCUPÉRER LES CLASSES D'UN ENSEIGNANT
  Future<QuerySnapshot> getTeacherClasses(String teacherId) async {
    try {
      return await _firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
    } catch (e) {
      print('❌ Erreur récupération classes: $e');
      rethrow;
    }
  }

  // RÉCUPÉRER TOUTES LES CLASSES (pour l'admin)
  Future<List<Map<String, dynamic>>> getAllClasses() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('classes')
          .get();

      return querySnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          })
          .toList();
    } catch (e) {
      print('❌ Erreur récupération classes: $e');
      throw Exception('Erreur lors de la récupération des classes');
    }
  }

  // METTRE À JOUR UN ENSEIGNANT
  Future<void> updateTeacher(String teacherId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('users')
          .doc(teacherId)
          .update(updates);
    } catch (e) {
      print('❌ Erreur mise à jour enseignant: $e');
      throw Exception('Erreur lors de la mise à jour de l\'enseignant');
    }
  }

  // SUPPRIMER UN ENSEIGNANT (attention: opération sensible)
  Future<void> deleteTeacher(String teacherId) async {
    try {
      // Vérifier si l'enseignant a des classes
      final classes = await getTeacherClasses(teacherId);
      
      if (classes.docs.isNotEmpty) {
        throw Exception('Impossible de supprimer: l\'enseignant a des classes associées');
      }

      await _firestore
          .collection('users')
          .doc(teacherId)
          .delete();
    } catch (e) {
      print('❌ Erreur suppression enseignant: $e');
      rethrow;
    }
  }
}