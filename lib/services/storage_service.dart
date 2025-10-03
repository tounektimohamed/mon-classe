import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadFile({
    required PlatformFile file,
    required String folder,
  }) async {
    try {
      final Reference storageRef = _storage
          .ref()
          .child(folder)
          .child('${DateTime.now().millisecondsSinceEpoch}_${file.name}');

      final UploadTask uploadTask = storageRef.putData(
        file.bytes!,
        SettableMetadata(contentType: file.extension),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Erreur upload fichier: $e');
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final Reference storageRef = _storage.refFromURL(url);
      await storageRef.delete();
    } catch (e) {
      throw Exception('Erreur suppression fichier: $e');
    }
  }
}