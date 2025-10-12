import 'dart:math';

import 'package:Joussour/models/class_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Joussour/models/class_model.dart';
import 'package:Joussour/models/sanction_model.dart';
import 'package:Joussour/services/storage_service.dart';
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

  // Créer une annonce pour une classe spécifique
  // services/firestore_service.dart - Ajoutez cette méthode
  Future<void> createAnnouncement({
    required String classId,
    required String title,
    required String content,
    required String authorId,
    required String authorName,
    List<String> attachments = const [],
    List<String> base64Images = const [],
  }) async {
    try {
      final announcementId = DateTime.now().millisecondsSinceEpoch.toString();

      final announcement = Announcement(
        id: announcementId,
        classId: classId,
        authorId: authorId,
        authorName: authorName,
        title: title,
        content: content,
        timestamp: DateTime.now(),
        attachments: attachments,
        base64Images: base64Images,
      );

      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('announcements')
          .doc(announcementId)
          .set(announcement.toMap());
    } catch (e) {
      throw Exception('Erreur lors de la création de l\'annonce: $e');
    }
  }

  Future<void> toggleLike({
    required String announcementId,
    required String userId,
    required String userName,
    required String classId, // AJOUT IMPORTANT: besoin de classId
  }) async {
    try {
      print(
        '❤️ Toggle like - Classe: $classId, Annonce: $announcementId, User: $userId',
      );

      // CHEMIN CORRECT: classes/{classId}/announcements/{announcementId}
      final announcementRef = _firestore
          .collection('classes')
          .doc(classId)
          .collection('announcements')
          .doc(announcementId);

      final doc = await announcementRef.get();
      if (!doc.exists) {
        throw Exception('Annonce non trouvée');
      }

      final data = doc.data()!;
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
        print('✅ Like retiré');
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
        print('✅ Like ajouté');
      }

      await announcementRef.update({'reactions': reactions});
      print('✅ Reactions mises à jour dans Firestore');
    } catch (e) {
      print('❌ Erreur toggleLike: $e');
      rethrow;
    }
  }

  // SYSTÈME DE COMMENTAIRES
  Future<void> addComment({
    required String announcementId,
    required String userId,
    required String userName,
    required String content,
    required String classId, // AJOUT IMPORTANT: besoin de classId
  }) async {
    try {
      print(
        '💬 Ajout commentaire - Classe: $classId, Annonce: $announcementId, User: $userId',
      );

      // CHEMIN CORRECT: classes/{classId}/announcements/{announcementId}
      final announcementRef = _firestore
          .collection('classes')
          .doc(classId)
          .collection('announcements')
          .doc(announcementId);

      final doc = await announcementRef.get();
      if (!doc.exists) {
        throw Exception('Annonce non trouvée');
      }

      final data = doc.data()!;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);

      // Créer le nouveau commentaire
      final newComment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: userName,
        content: content.trim(),
        timestamp: DateTime.now(),
        reactions: [],
        replies: [],
      ).toMap();

      comments.add(newComment);

      await announcementRef.update({'comments': comments});
      print('✅ Commentaire ajouté avec succès');
    } catch (e) {
      print('❌ Erreur addComment: $e');
      rethrow;
    }
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
      // Cette méthode doit aussi chercher dans toutes les classes
      // Pour l'instant, on lance une exception
      throw Exception('Méthode deleteAnnouncement à implémenter avec classId');
    } catch (e) {
      print('❌ Erreur deleteAnnouncement: $e');
      rethrow;
    }
  }

  Future<bool> isUserAuthor(String announcementId, String userId) async {
    try {
      // Cette méthode doit chercher dans toutes les classes
      // Pour l'instant, retournons true pour tester
      // Vous devrez implémenter la logique de recherche
      return true;
    } catch (e) {
      print('❌ Erreur isUserAuthor: $e');
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

  // services/firestore_service.dart - AJOUTEZ cette méthode
  Stream<List<Announcement>> getAnnouncementsStream(String classId) {
    try {
      print(
        '🔍 FirestoreService - Récupération annonces pour classe: $classId',
      );

      return _firestore
          .collection('classes')
          .doc(classId)
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .handleError((error) {
            print('❌ FirestoreService - Erreur stream annonces: $error');
            throw error;
          })
          .map((snapshot) {
            final announcements = snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                print('📄 FirestoreService - Données annonce: ${doc.id}');
                print('📄 FirestoreService - Titre: ${data['title']}');
                print(
                  '📄 FirestoreService - Base64Images: ${data['base64Images']}',
                );
                print(
                  '📄 FirestoreService - Attachments: ${data['attachments']}',
                );

                return Announcement.fromMap(data);
              } catch (e) {
                print(
                  '❌ FirestoreService - Erreur parsing annonce ${doc.id}: $e',
                );
                print(
                  '❌ FirestoreService - Données problématiques: ${doc.data()}',
                );
                rethrow;
              }
            }).toList();

            print(
              '✅ FirestoreService - ${announcements.length} annonces chargées',
            );
            return announcements;
          });
    } catch (e) {
      print('❌ FirestoreService - Erreur initialisation stream: $e');
      rethrow;
    }
  }

  // Si vous avez une méthode getAnnouncements (sans stream), assurez-vous qu'elle existe aussi
  Future<List<Announcement>> getAnnouncements(String classId) async {
    try {
      print(
        '🔍 FirestoreService - Récupération annonces (once) pour classe: $classId',
      );

      final snapshot = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .get();

      final announcements = snapshot.docs.map((doc) {
        final data = doc.data();
        print('📄 FirestoreService - Données annonce: ${doc.id}');
        return Announcement.fromMap(data);
      }).toList();

      print(
        '✅ FirestoreService - ${announcements.length} annonces chargées (once)',
      );
      return announcements;
    } catch (e) {
      print('❌ FirestoreService - Erreur récupération annonces: $e');
      rethrow;
    }
  }

  // Dans services/firestore_service.dart
  Future<void> addSanction(Sanction sanction) async {
    try {
      await _firestore
          .collection('sanctions')
          .doc(sanction.id)
          .set(sanction.toMap());

      print('✅ Sanction ajoutée pour ${sanction.studentName}');

      // Le trigger Cloud Functions se déclenche automatiquement
      // grâce à la méthode onCreate sur la collection 'sanctions'
    } catch (e) {
      print('❌ Erreur ajout sanction: $e');
      rethrow;
    }
  }

  // Récupérer les sanctions d'un élève
  // Récupérer les sanctions d'un élève
  Stream<List<Sanction>> getStudentSanctions(String studentId) {
    return _firestore
        .collection('sanctions')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final sanctions = snapshot.docs
              .map((doc) => Sanction.fromMap(doc.data()))
              .toList();

          // 🔹 Trier localement par date (du plus récent au plus ancien)
          sanctions.sort((a, b) => b.date.compareTo(a.date));

          return sanctions;
        });
  }

  // Récupérer les sanctions d'une classe
  Stream<List<Sanction>> getClassSanctions(String classId) {
    return _firestore
        .collection('sanctions')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
          final sanctions = snapshot.docs
              .map((doc) => Sanction.fromMap(doc.data()))
              .toList();

          // 🔹 Trier localement par date (du plus récent au plus ancien)
          sanctions.sort((a, b) => b.date.compareTo(a.date));

          return sanctions;
        });
  }

  // Compter les sanctions actives d'un élève
  Future<int> getStudentActiveSanctionsCount(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('sanctions')
          .where('studentId', isEqualTo: studentId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Erreur comptage sanctions: $e');
      return 0;
    }
  }

  // Marquer une sanction comme résolue
  Future<void> resolveSanction(String sanctionId) async {
    try {
      await _firestore.collection('sanctions').doc(sanctionId).update({
        'isActive': false,
      });

      print('✅ Sanction marquée comme résolue: $sanctionId');
    } catch (e) {
      print('❌ Erreur résolution sanction: $e');
      rethrow;
    }
  }

  // Supprimer une sanction
  Future<void> deleteSanction(String sanctionId) async {
    try {
      await _firestore.collection('sanctions').doc(sanctionId).delete();

      print('✅ Sanction supprimée: $sanctionId');
    } catch (e) {
      print('❌ Erreur suppression sanction: $e');
      rethrow;
    }
  }

  // Obtenir les statistiques de sanctions d'une classe
  Future<Map<String, dynamic>> getClassSanctionsStats(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('sanctions')
          .where('classId', isEqualTo: classId)
          .get();

      final sanctions = snapshot.docs
          .map((doc) => Sanction.fromMap(doc.data()))
          .toList();

      final activeSanctions = sanctions.where((s) => s.isValid).length;
      final totalSanctions = sanctions.length;

      // 🔹 Compter par type (tous les types définis dans l'enum)
      final remarqueOrales = sanctions
          .where((s) => s.type == SanctionType.remarqueOrale)
          .length;
      final observations = sanctions
          .where((s) => s.type == SanctionType.observationEcrite)
          .length;
      final travauxEducatifs = sanctions
          .where((s) => s.type == SanctionType.travailEducatif)
          .length;
      final avertissements = sanctions
          .where((s) => s.type == SanctionType.avertissement)
          .length;
      final tachesAide = sanctions
          .where((s) => s.type == SanctionType.tacheAide)
          .length;
      final detentions = sanctions
          .where((s) => s.type == SanctionType.detention)
          .length;
      final exclusions = sanctions
          .where((s) => s.type == SanctionType.exclusion)
          .length;
      final autres = sanctions
          .where((s) => s.type == SanctionType.autre)
          .length;

      return {
        'total': totalSanctions,
        'active': activeSanctions,
        'remarqueOrales': remarqueOrales,
        'observations': observations,
        'travauxEducatifs': travauxEducatifs,
        'avertissements': avertissements,
        'tachesAide': tachesAide,
        'detentions': detentions,
        'exclusions': exclusions,
        'autres': autres,
      };
    } catch (e) {
      print('❌ Erreur statistiques sanctions: $e');
      return {
        'total': 0,
        'active': 0,
        'remarqueOrales': 0,
        'observations': 0,
        'travauxEducatifs': 0,
        'avertissements': 0,
        'tachesAide': 0,
        'detentions': 0,
        'exclusions': 0,
        'autres': 0,
      };
    }
  }
}
