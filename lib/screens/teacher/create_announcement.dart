import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/models/class_model.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/announcement_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final String classId;

  const CreateAnnouncementScreen({super.key, required this.classId});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  
  bool _isLoading = false;
  List<PlatformFile> _selectedFiles = [];
  List<Map<String, dynamic>> _uploadedFiles = [];
  List<String> _base64Images = [];

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'txt'],
      );

      if (result != null) {
        for (var file in result.files) {
          if (_isImageFile(file.name)) {
            final bytes = file.bytes;
            if (bytes != null) {
              final base64String = base64Encode(bytes);
              setState(() {
                _base64Images.add(base64String);
              });
            }
          } else {
            setState(() {
              _selectedFiles.add(file);
            });
          }
        }
      }
    } catch (e) {
      _showError('Erreur lors de la sélection des fichiers: $e');
    }
  }

  bool _isImageFile(String fileName) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final lowerFileName = fileName.toLowerCase();
    return imageExtensions.any((ext) => lowerFileName.endsWith(ext));
  }

  Future<void> _publishAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      
      if (user == null) {
        throw Exception('Utilisateur non trouvé');
      }

      final announcementId = DateTime.now().millisecondsSinceEpoch.toString();

      if (_selectedFiles.isNotEmpty) {
        _uploadedFiles = await _storageService.uploadFiles(
          files: _selectedFiles,
          announcementId: announcementId,
        );

        await _storageService.saveFileMetadata(
          announcementId: announcementId,
          filesMetadata: _uploadedFiles,
        );
      }

      await _firestoreService.createAnnouncement(
        classId: widget.classId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        authorId: user.uid,
        authorName: '${user.firstName} ${user.lastName}',
        attachments: _uploadedFiles.map((file) => file['url'] as String).toList(),
        base64Images: _base64Images,
      );

      _showSuccess('Annonce publiée avec succès');
      Navigator.pop(context);
      
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _removeBase64Image(int index) {
    setState(() {
      _base64Images.removeAt(index);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Widget _buildFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24);
      case 'doc':
      case 'docx':
        return const Icon(Icons.description, color: Colors.blue, size: 24);
      case 'jpg':
      case 'jpeg':
      case 'png':
        return const Icon(Icons.image, color: Colors.green, size: 24);
      case 'txt':
        return const Icon(Icons.text_fields, color: Colors.orange, size: 24);
      default:
        return const Icon(Icons.insert_drive_file, color: Colors.grey, size: 24);
    }
  }

  Widget _buildBase64ImagePreview(String base64Image, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(base64Image),
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.white, size: 16),
                onPressed: () => _removeBase64Image(index),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle annonce'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _publishAnnouncement,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(_isLoading ? 'Publication...' : 'Publier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Publication en cours...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    StreamBuilder<ClassModel?>(
                      stream: FirestoreService().getClassStream(widget.classId),
                      builder: (context, snapshot) {
                        final className = snapshot.data?.name ?? 'Chargement...';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Créer une annonce',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pour la classe: $className',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Partagez des informations importantes avec les parents',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre de l\'annonce *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                        hintText: 'Ex: Réunion parents-professeurs',
                      ),
                      maxLength: 100,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un titre';
                        }
                        if (value.length < 3) {
                          return 'Le titre doit contenir au moins 3 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _contentController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Contenu de l\'annonce *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        hintText: 'Décrivez votre annonce en détail...',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer le contenu de l\'annonce';
                        }
                        if (value.length < 10) {
                          return 'Le contenu doit contenir au moins 10 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.attach_file, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pièces jointes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (_selectedFiles.isNotEmpty || _base64Images.isNotEmpty)
                                  Text(
                                    '${_selectedFiles.length + _base64Images.length} fichier(s)',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ajoutez des documents, images ou autres fichiers pour accompagner votre annonce',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _pickFiles,
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter des fichiers'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),

                            if (_base64Images.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                'Images:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._base64Images.asMap().entries.map((entry) {
                                final index = entry.key;
                                final base64Image = entry.value;
                                return _buildBase64ImagePreview(base64Image, index);
                              }).toList(),
                            ],

                            if (_selectedFiles.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              if (_base64Images.isNotEmpty) const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                'Fichiers:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._selectedFiles.asMap().entries.map((entry) {
                                final index = entry.key;
                                final file = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: ListTile(
                                    leading: _buildFileIcon(file.name),
                                    title: Text(
                                      file.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      _getFileSize(file.size),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeFile(index),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    dense: true,
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Card(
                      elevation: 1,
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cette annonce sera visible par tous les parents de cette classe',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}