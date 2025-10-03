import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/announcement_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

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

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection: $e')),
      );
    }
  }

  Future<List<String>> _uploadFiles() async {
    List<String> downloadUrls = [];
    
    for (var file in _selectedFiles) {
      try {
        final url = await _storageService.uploadFile(
          file: file,
          folder: 'announcements',
        );
        downloadUrls.add(url);
      } catch (e) {
        print('Erreur upload ${file.name}: $e');
      }
    }
    
    return downloadUrls;
  }

  Future<void> _publishAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;
      List<String> attachments = [];

      // Upload des fichiers si présents
      if (_selectedFiles.isNotEmpty) {
        attachments = await _uploadFiles();
      }

      final announcement = Announcement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        classId: user!.classId!,
        authorId: user.uid,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        timestamp: DateTime.now(),
        attachments: attachments,
      );

      await _firestoreService.createAnnouncement(announcement);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce publiée avec succès')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle annonce'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _publishAnnouncement,
            icon: _isLoading
                ? const CircularProgressIndicator()
                : const Icon(Icons.send),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre de l\'annonce',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un titre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contentController,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Contenu de l\'annonce',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le contenu de l\'annonce';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Section pièces jointes
              Row(
                children: [
                  const Text(
                    'Pièces jointes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Ajouter des fichiers'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Liste des fichiers sélectionnés
              if (_selectedFiles.isNotEmpty) ...[
                ..._selectedFiles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(
                        file.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${(file.size / 1024).toStringAsFixed(1)} KB'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeFile(index),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 10),
                Text(
                  '${_selectedFiles.length} fichier(s) sélectionné(s)',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
              ],
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