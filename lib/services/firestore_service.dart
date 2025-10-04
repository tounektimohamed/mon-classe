import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mon_classe_manegment/models/class_model.dart';
import 'package:mon_classe_manegment/services/storage_service.dart';
import '../models/announcement_model.dart';
import '../models/student_model.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gestion des classes
  Stream<List<ClassModel>> getTeacherClassesStream(String teacherId) {
    return _firestore
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
          final classes = snapshot.docs
              .map((doc) => ClassModel.fromMap(doc.data()))
              .toList();

          // 🔽 Trier côté Flutter
          classes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return classes;
        });
  }

  // Récupérer une classe spécifique
  Stream<ClassModel?> getClassStream(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? ClassModel.fromMap(snapshot.data()!) : null,
        );
  }

  // Créer une nouvelle classe
  Future<void> createClass({
    required String name,
    required String description,
    required String teacherId,
    required String teacherName,
    String subject = '',
    String schoolName = '',
  }) async {
    final classRef = _firestore.collection('classes').doc();

    final classData = {
      'id': classRef.id,
      'name': name,
      'description': description,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'subject': subject,
      'schoolName': schoolName,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'studentIds': [],
    };

    await classRef.set(classData);
  }

  // Gestion des annonces
  Stream<List<Announcement>> getAnnouncements(String classId) {
    return _firestore
        .collection('announcements')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
          final announcements = snapshot.docs
              .map((doc) => Announcement.fromMap(doc.data()))
              .toList();

          // 🔽 Trier côté Flutter
          announcements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return announcements;
        });
  }

  // Créer une annonce pour une classe spécifique
  Future<void> createAnnouncement({
    required String classId,
    required String title,
    required String content,
    required String authorId,
    required String authorName,
    List<String> attachments = const [],
  }) async {
    final announcementRef = _firestore.collection('announcements').doc();

    final announcementData = {
      'id': announcementRef.id,
      'classId': classId,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'attachments': attachments,
      'likes': [],
      'comments': [],
    };

    await announcementRef.set(announcementData);
  }

  // Méthode alternative pour créer une annonce avec objet Announcement
  Future<void> createAnnouncementFromObject(Announcement announcement) async {
    await _firestore
        .collection('announcements')
        .doc(announcement.id)
        .set(announcement.toMap());
  }

  // SYSTÈME DE RÉACTIONS (LIKE)
  Future<void> toggleLike({
    required String announcementId,
    required String userId,
    required String userName,
  }) async {
    final announcementRef = _firestore
        .collection('announcements')
        .doc(announcementId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final reactions = List<Map<String, dynamic>>.from(
        data['reactions'] ?? [],
      );

      // Vérifier si l'utilisateur a déjà liké
      final existingIndex = reactions.indexWhere(
        (r) => r['userId'] == userId && r['type'] == 'like',
      );

      if (existingIndex >= 0) {
        // Retirer le like
        reactions.removeAt(existingIndex);
      } else {
        // Ajouter le like
        reactions.add(
          Reaction(
            userId: userId,
            userName: userName,
            type: 'like',
            timestamp: DateTime.now(),
          ).toMap(),
        );
      }

      transaction.update(announcementRef, {'reactions': reactions});
    });
  }

  // SYSTÈME DE COMMENTAIRES
  Future<void> addComment({
    required String announcementId,
    required String userId,
    required String userName,
    required String content,
  }) async {
    final announcementRef = _firestore
        .collection('announcements')
        .doc(announcementId);
    final commentId = _firestore.collection('announcements').doc().id;

    final newComment = Comment(
      id: commentId,
      userId: userId,
      userName: userName,
      content: content,
      timestamp: DateTime.now(),
    ).toMap();

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
      comments.add(newComment);

      transaction.update(announcementRef, {'comments': comments});
    });
  }

  // RÉPONDRE À UN COMMENTAIRE
  Future<void> addReply({
    required String announcementId,
    required String parentCommentId,
    required String userId,
    required String userName,
    required String content,
  }) async {
    final announcementRef = _firestore
        .collection('announcements')
        .doc(announcementId);
    final replyId = _firestore.collection('announcements').doc().id;

    final newReply = Comment(
      id: replyId,
      userId: userId,
      userName: userName,
      content: content,
      timestamp: DateTime.now(),
    ).toMap();

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);

      // Trouver le commentaire parent et ajouter la réponse
      for (int i = 0; i < comments.length; i++) {
        if (comments[i]['id'] == parentCommentId) {
          final replies = List<Map<String, dynamic>>.from(
            comments[i]['replies'] ?? [],
          );
          replies.add(newReply);
          comments[i]['replies'] = replies;
          break;
        }
      }

      transaction.update(announcementRef, {'comments': comments});
    });
  }

  // SUPPRIMER UN COMMENTAIRE
  Future<void> deleteComment({
    required String announcementId,
    required String commentId,
    required String userId, // Pour vérifier les permissions
  }) async {
    final announcementRef = _firestore
        .collection('announcements')
        .doc(announcementId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);

      // Trouver et supprimer le commentaire (seulement si c'est le propriétaire)
      for (int i = 0; i < comments.length; i++) {
        if (comments[i]['id'] == commentId && comments[i]['userId'] == userId) {
          comments.removeAt(i);
          break;
        }
      }

      transaction.update(announcementRef, {'comments': comments});
    });
  }

  // SUPPRIMER UNE ANNONCE
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      // Supprimer d'abord les fichiers de Storage
      final storageService = StorageService();
      await storageService.deleteAllAnnouncementFiles(announcementId);

      // Supprimer l'annonce principale
      await _firestore.collection('announcements').doc(announcementId).delete();

      print('✅ Annonce supprimée: $announcementId');
    } catch (e) {
      print('❌ Erreur suppression annonce: $e');
      throw Exception('Erreur lors de la suppression de l\'annonce: $e');
    }
  }

  // VÉRIFIER SI L'UTILISATEUR EST L'AUTEUR
  Future<bool> isUserAuthor(String announcementId, String userId) async {
    try {
      final doc = await _firestore
          .collection('announcements')
          .doc(announcementId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return data['authorId'] == userId;
      }
      return false;
    } catch (e) {
      print('❌ Erreur vérification auteur: $e');
      return false;
    }
  }

  // Mettre à jour les pièces jointes d'une annonce
  Future<void> updateAnnouncementAttachments({
    required String announcementId,
    required List<String> attachments,
  }) async {
    await _firestore.collection('announcements').doc(announcementId).update({
      'attachments': attachments,
    });
  }

  // Gestion des élèves

  Future<void> addStudent(Student student) async {
    await _firestore
        .collection('students')
        .doc(student.id)
        .set(student.toMap());
  }

  // Gestion des messages
  Stream<List<Message>> getMessages(String currentUserId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => Message.fromMap(doc.data()))
              .toList();

          // 🔽 Trier côté Flutter
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return messages;
        });
  }

  Stream<List<Message>> getConversationMessages(
  String currentUserId,
  String otherUserId,
) {
  return _firestore
      .collection('messages')
      .where('participants', arrayContains: currentUserId)
      .snapshots()
      .map((snapshot) {
        final messages = snapshot.docs
            .map((doc) => Message.fromMap(doc.data()))
            // 🔽 Garde seulement les messages entre les deux utilisateurs
            .where((message) => message.participants.contains(otherUserId))
            .toList();

        // 🔽 Trie les messages localement par timestamp (le plus récent en premier)
        messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return messages;
      });
}

  Future<void> sendMessage(Message message) async {
    await _firestore
        .collection('messages')
        .doc(message.id)
        .set(message.toMap());
  }

  Future<void> markMessagesAsRead(
    String currentUserId,
    String otherUserId,
  ) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final message = Message.fromMap(doc.data());
      if (message.senderId == otherUserId &&
          message.participants.contains(otherUserId) &&
          !message.isRead) {
        batch.update(doc.reference, {'isRead': true});
      }
    }

    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<int> getUnreadCount(String currentUserId, String otherUserId) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .get();

    int count = 0;
    for (final doc in snapshot.docs) {
      final message = Message.fromMap(doc.data());
      if (message.senderId == otherUserId &&
          message.participants.contains(otherUserId) &&
          !message.isRead) {
        count++;
      }
    }
    return count;
  }

  // Récupérer les conversations avec les derniers messages
 Stream<List<Map<String, dynamic>>> getConversations(String userId) {
  return _firestore
      .collection('messages')
      .where('participants', arrayContains: userId)
      .snapshots()
      .asyncMap((snapshot) async {
        final conversations = <String, Map<String, dynamic>>{};

        // Parcourir les messages récupérés
        for (final doc in snapshot.docs) {
          final message = Message.fromMap(doc.data());
          final otherUserId = message.participants.firstWhere(
            (id) => id != userId,
            orElse: () => message.senderId == userId
                ? message.receiverId
                : message.senderId,
          );

          final conversationKey = '${userId}_$otherUserId';

          if (!conversations.containsKey(conversationKey)) {
            conversations[conversationKey] = {
              'otherUserId': otherUserId,
              'lastMessage': message,
              'unreadCount': await getUnreadCount(userId, otherUserId),
            };
          }
        }

        // 🔽 Trier côté Flutter selon le timestamp du dernier message
        final conversationList = conversations.values.toList();
        conversationList.sort((a, b) {
          final lastMessageA = a['lastMessage'] as Message;
          final lastMessageB = b['lastMessage'] as Message;
          return lastMessageB.timestamp.compareTo(lastMessageA.timestamp);
        });

        return conversationList;
      });
}

  // Récupérer les informations d'un utilisateur
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération info utilisateur: $e');
      return null;
    }
  }

  // Récupérer tous les enseignants (pour les parents)
  Stream<List<Map<String, dynamic>>> getTeachers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Récupérer les étudiants d'un parent
  Stream<List<Student>> getParentStudents(String parentId) {
    return _firestore
        .collection('students')
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Student.fromMap(doc.data())).toList(),
        );
  }

  // Mettre à jour le profil utilisateur
  Future<void> updateUserProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? profileImageUrl,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'firstName': firstName,
      'lastName': lastName,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Gestion des élèves
  Future<void> addStudentToClass({
    required String firstName,
    required String lastName,
    required String classId,
  }) async {
    try {
      final studentRef = _firestore.collection('students').doc();

      final studentData = {
        'id': studentRef.id,
        'firstName': firstName,
        'lastName': lastName,
        'classId': classId,
        'parentId': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      await studentRef.set(studentData);

      // Ajouter l'élève à la liste des étudiants de la classe
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': FieldValue.arrayUnion([studentRef.id]),
      });

      print('✅ Élève ajouté: $firstName $lastName à la classe $classId');
    } catch (e) {
      print('❌ Erreur ajout élève: $e');
      rethrow;
    }
  }

  Future<void> updateStudent({
    required String studentId,
    required String firstName,
    required String lastName,
    required String classId,
  }) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'firstName': firstName,
        'lastName': lastName,
        'classId': classId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ Élève modifié: $firstName $lastName');
    } catch (e) {
      print('❌ Erreur modification élève: $e');
      rethrow;
    }
  }

  Future<void> deleteStudent(String studentId, String classId) async {
    try {
      // Supprimer l'élève
      await _firestore.collection('students').doc(studentId).delete();

      // Retirer l'élève de la liste de la classe
      await _firestore.collection('classes').doc(classId).update({
        'studentIds': FieldValue.arrayRemove([studentId]),
      });

      print('✅ Élève supprimé: $studentId');
    } catch (e) {
      print('❌ Erreur suppression élève: $e');
      rethrow;
    }
  }

  Stream<List<Student>> getStudents(String classId) {
    return _firestore
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
          final students = snapshot.docs
              .map((doc) => Student.fromMap(doc.data()))
              .toList();

          // 🔽 Trier les élèves par prénom côté Flutter
          students.sort((a, b) => a.firstName.compareTo(b.firstName));
          return students;
        });
  }

  // Générer un code d'invitation pour les parents
  Future<String> generateStudentCode(String studentId) async {
    // Générer un code unique de 8 caractères
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );

    // Sauvegarder le code dans Firestore (optionnel)
    await _firestore.collection('student_codes').doc(studentId).set({
      'studentId': studentId,
      'code': code,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    return code;
  }

  // Supprimer une classe
  Future<void> deleteClass(String classId) async {
    try {
      // Supprimer tous les étudiants de la classe
      final studentsSnapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      final batch = _firestore.batch();
      for (final doc in studentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Supprimer toutes les annonces de la classe
      final announcementsSnapshot = await _firestore
          .collection('announcements')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in announcementsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Supprimer la classe
      batch.delete(_firestore.collection('classes').doc(classId));

      await batch.commit();

      // Retirer la classe de la liste des classes de l'enseignant
      final classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();
      if (classDoc.exists) {
        final teacherId = classDoc.data()!['teacherId'];
        await _firestore.collection('users').doc(teacherId).update({
          'classIds': FieldValue.arrayRemove([classId]),
        });
      }

      print('✅ Classe supprimée: $classId');
    } catch (e) {
      print('❌ Erreur suppression classe: $e');
      throw Exception('Erreur lors de la suppression de la classe: $e');
    }
  }
}
