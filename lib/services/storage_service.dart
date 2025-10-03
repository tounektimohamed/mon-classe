import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Uploader un fichier vers Firebase Storage
  Future<Map<String, dynamic>> uploadFile({
    required PlatformFile file,
    required String announcementId,
  }) async {
    try {
      // Générer un nom de fichier unique
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final Reference storageRef = _storage.ref().child('announcements/$announcementId/$fileName');
      
      // Uploader le fichier
      final UploadTask uploadTask = storageRef.putData(
        file.bytes!,
        SettableMetadata(contentType: _getMimeType(file.extension)),
      );

      // Attendre la fin de l'upload
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Retourner les métadonnées du fichier
      return {
        'name': file.name,
        'size': file.size,
        'extension': file.extension ?? 'unknown',
        'url': downloadUrl,
        'storagePath': snapshot.ref.fullPath,
        'uploadedAt': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      throw Exception('Erreur lors de l\'upload du fichier: $e');
    }
  }

  // Uploader plusieurs fichiers
  Future<List<Map<String, dynamic>>> uploadFiles({
    required List<PlatformFile> files,
    required String announcementId,
  }) async {
    try {
      List<Map<String, dynamic>> uploadedFiles = [];
      
      for (var file in files) {
        final fileData = await uploadFile(
          file: file,
          announcementId: announcementId,
        );
        uploadedFiles.add(fileData);
      }
      
      return uploadedFiles;
    } catch (e) {
      throw Exception('Erreur lors de l\'upload des fichiers: $e');
    }
  }

  // Sauvegarder les métadonnées des fichiers dans Firestore
  Future<void> saveFileMetadata({
    required String announcementId,
    required List<Map<String, dynamic>> filesMetadata,
  }) async {
    try {
      final batch = _firestore.batch();
      final attachmentsRef = _firestore
          .collection('announcements')
          .doc(announcementId)
          .collection('attachments');

      for (final fileMetadata in filesMetadata) {
        final docRef = attachmentsRef.doc();
        batch.set(docRef, fileMetadata);
      }
      
      await batch.commit();
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde des métadonnées: $e');
    }
  }

  // Récupérer les pièces jointes d'une annonce
  Stream<List<Map<String, dynamic>>> getAttachments(String announcementId) {
    return _firestore
        .collection('announcements')
        .doc(announcementId)
        .collection('attachments')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  // Supprimer un fichier
  Future<void> deleteFile({
    required String storagePath,
    required String announcementId,
    required String fileId,
  }) async {
    try {
      // Supprimer de Firebase Storage
      await _storage.ref().child(storagePath).delete();
      
      // Supprimer les métadonnées de Firestore
      await _firestore
          .collection('announcements')
          .doc(announcementId)
          .collection('attachments')
          .doc(fileId)
          .delete();
    } catch (e) {
      throw Exception('Erreur lors de la suppression du fichier: $e');
    }
  }

  // Supprimer tous les fichiers d'une annonce
  Future<void> deleteAllAnnouncementFiles(String announcementId) async {
    try {
      // Récupérer tous les fichiers de l'annonce
      final snapshot = await _firestore
          .collection('announcements')
          .doc(announcementId)
          .collection('attachments')
          .get();

      // Supprimer chaque fichier de Storage
      final storage = _storage;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final storagePath = data['storagePath'];
        if (storagePath != null) {
          await storage.ref().child(storagePath).delete();
        }
      }

      // Supprimer tous les documents de la sous-collection
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Erreur lors de la suppression des fichiers: $e');
    }
  }

  // Obtenir le type MIME à partir de l'extension
  String _getMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}