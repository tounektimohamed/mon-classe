import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class FileService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Télécharger et ouvrir un fichier
  Future<void> downloadAndOpenFile(String fileUrl, String fileName) async {
    try {
      if (kIsWeb) {
        // Implémentation pour le web
        await _downloadFileWeb(fileUrl, fileName);
      } else {
        // Implémentation pour mobile/desktop
        await _downloadFileMobile(fileUrl, fileName);
      }
    } catch (e) {
      print('❌ Erreur dans downloadAndOpenFile: $e');
      rethrow;
    }
  }

  // Implémentation pour le web - CORRIGÉE
  Future<void> _downloadFileWeb(String fileUrl, String fileName) async {
    try {
      print('🌐 Début du téléchargement web: $fileName');
      print('📁 URL: $fileUrl');

      // Méthode 1: Utiliser directement l'URL Firebase Storage
      await _downloadViaAnchor(fileUrl, fileName);
      
    } catch (e) {
      print('❌ Erreur téléchargement web: $e');
      // Essayer une méthode alternative
      await _downloadViaHttpRequest(fileUrl, fileName);
    }
  }

  // Méthode 1: Téléchargement direct via anchor element
  Future<void> _downloadViaAnchor(String fileUrl, String fileName) async {
    try {
      // Créer un élément anchor pour le téléchargement
      final anchor = html.AnchorElement(href: fileUrl)
        ..target = '_blank'
        ..download = fileName
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      
      print('✅ Téléchargement via anchor réussi: $fileName');
    } catch (e) {
      print('❌ Erreur avec anchor: $e');
      rethrow;
    }
  }

  // Méthode 2: Téléchargement via HTTP request (alternative)
  Future<void> _downloadViaHttpRequest(String fileUrl, String fileName) async {
    try {
      print('🔄 Tentative de téléchargement via HTTP request...');
      
      // Créer une requête HTTP
      final response = await html.HttpRequest.request(
        fileUrl,
        method: 'GET',
        responseType: 'blob',
      );

      if (response.status == 200) {
        final blob = response.response as html.Blob;
        final url = html.Url.createObjectUrl(blob);
        
        final anchor = html.AnchorElement(href: url)
          ..download = fileName
          ..style.display = 'none';
        
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        
        print('✅ Téléchargement via HTTP réussi: $fileName');
      } else {
        throw Exception('Erreur HTTP: ${response.status}');
      }
    } catch (e) {
      print('❌ Erreur avec HTTP request: $e');
      
      // Méthode 3: Ouvrir dans un nouvel onglet
      await _openInNewTab(fileUrl);
    }
  }

  // Méthode 3: Ouvrir dans un nouvel onglet
  Future<void> _openInNewTab(String fileUrl) async {
    try {
      html.window.open(fileUrl, '_blank');
      print('✅ Fichier ouvert dans un nouvel onglet');
    } catch (e) {
      print('❌ Erreur avec ouverture nouvel onglet: $e');
      throw Exception('Impossible de télécharger ou d\'ouvrir le fichier');
    }
  }

  // Implémentation pour mobile/desktop
  Future<void> _downloadFileMobile(String fileUrl, String fileName) async {
    try {
      // Vérifier les permissions de stockage
      if (await _requestStoragePermission()) {
        await _downloadAndOpenMobile(fileUrl, fileName);
      } else {
        throw Exception('Permission de stockage refusée');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // Sur iOS, les permissions sont gérées différemment
  }

  Future<void> _downloadAndOpenMobile(String fileUrl, String fileName) async {
    try {
      // Obtenir le répertoire de téléchargement
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';

      // Télécharger le fichier depuis Firebase Storage
      final Reference ref = _storage.refFromURL(fileUrl);
      final File file = File(filePath);
      
      // Télécharger le fichier
      await ref.writeToFile(file);
      
      print('✅ Fichier téléchargé: $filePath');

      // Ouvrir le fichier
      final result = await OpenFilex.open(filePath);
      
      print('📁 Résultat ouverture: ${result.message}');
      
      if (result.type != ResultType.done) {
        throw Exception('Impossible d\'ouvrir le fichier: ${result.message}');
      }
      
    } catch (e) {
      print('❌ Erreur téléchargement/ouverture mobile: $e');
      rethrow;
    }
  }

  // Obtenir le type de fichier pour l'icône
  static FileType getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return FileType.pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return FileType.image;
      case 'doc':
      case 'docx':
        return FileType.word;
      case 'xls':
      case 'xlsx':
        return FileType.excel;
      case 'ppt':
      case 'pptx':
        return FileType.powerpoint;
      case 'txt':
        return FileType.text;
      case 'zip':
      case 'rar':
        return FileType.archive;
      default:
        return FileType.unknown;
    }
  }

  // Obtenir l'icône correspondante
  static IconData getFileIcon(FileType fileType) {
    switch (fileType) {
      case FileType.pdf:
        return Icons.picture_as_pdf;
      case FileType.image:
        return Icons.image;
      case FileType.word:
        return Icons.description;
      case FileType.excel:
        return Icons.table_chart;
      case FileType.powerpoint:
        return Icons.slideshow;
      case FileType.text:
        return Icons.text_fields;
      case FileType.archive:
        return Icons.folder_zip;
      case FileType.unknown:
        return Icons.insert_drive_file;
    }
  }

  // Obtenir la couleur correspondante
  static Color getFileColor(FileType fileType) {
    switch (fileType) {
      case FileType.pdf:
        return Colors.red;
      case FileType.image:
        return Colors.green;
      case FileType.word:
        return Colors.blue;
      case FileType.excel:
        return Colors.green;
      case FileType.powerpoint:
        return Colors.orange;
      case FileType.text:
        return Colors.blueGrey;
      case FileType.archive:
        return Colors.amber;
      case FileType.unknown:
        return Colors.grey;
    }
  }
}

enum FileType {
  pdf,
  image,
  word,
  excel,
  powerpoint,
  text,
  archive,
  unknown,
}