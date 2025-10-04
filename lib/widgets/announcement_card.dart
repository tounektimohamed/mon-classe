// widgets/announcement_card.dart - CODE COMPLET CORRIGÉ

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/services/FileService.dart';
import 'package:provider/provider.dart';
import '../models/announcement_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';

class AnnouncementCard extends StatefulWidget {
  final Announcement announcement;
  final VoidCallback? onAnnouncementDeleted;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onAnnouncementDeleted,
  });

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard> {
  final FirestoreService _firestoreService = FirestoreService();
  final FileService _fileService = FileService();
  final TextEditingController _commentController = TextEditingController();
  bool _showComments = false;
  bool _isLiking = false;
  bool _showFullContent = false;
  bool _isDeleting = false;
  final int _maxContentLength = 150;
  Map<String, bool> _downloadingFiles = {};

  // CORRECTION: Méthode toggleLike avec classId
  void _toggleLike() async {
    if (_isLiking) return;

    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      _showError('Utilisateur non connecté');
      return;
    }

    setState(() => _isLiking = true);

    try {
      await _firestoreService.toggleLike(
        announcementId: widget.announcement.id,
        userId: user.uid,
        userName: '${user.firstName} ${user.lastName}',
        classId: widget.announcement.classId, // AJOUT CRITIQUE
      );
      
      print('✅ Like action terminée');
    } catch (e) {
      print('❌ Erreur toggleLike: $e');
      _showError('Erreur: $e');
    } finally {
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

  // CORRECTION: Méthode addComment avec classId
  void _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) {
      _showError('Utilisateur non connecté');
      return;
    }

    try {
      await _firestoreService.addComment(
        announcementId: widget.announcement.id,
        userId: user.uid,
        userName: '${user.firstName} ${user.lastName}',
        content: _commentController.text.trim(),
        classId: widget.announcement.classId, // AJOUT CRITIQUE
      );
      
      _commentController.clear();
      FocusScope.of(context).unfocus();
      print('✅ Commentaire ajouté avec succès');
      
    } catch (e) {
      print('❌ Erreur addComment: $e');
      _showError('Erreur: $e');
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer l\'annonce'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette annonce ? Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAnnouncement();
              },
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteAnnouncement() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isDeleting = true);

    try {
      await _firestoreService.deleteAnnouncement(widget.announcement.id);
      
      _showSuccess('Annonce supprimée avec succès');
      
      if (widget.onAnnouncementDeleted != null) {
        widget.onAnnouncementDeleted!();
      }
    } catch (e) {
      _showError('Erreur lors de la suppression: $e');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _openFile(String fileUrl, String fileName) async {
    if (_downloadingFiles[fileUrl] == true) return;

    setState(() {
      _downloadingFiles[fileUrl] = true;
    });

    try {
      await _fileService.downloadAndOpenFile(fileUrl, fileName);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier ouvert: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _downloadingFiles[fileUrl] = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final segments = path.split('/');
      String fileName = segments.last;
      fileName = Uri.decodeComponent(fileName);
      
      final parts = fileName.split('_');
      if (parts.length > 1) {
        return parts.sublist(1).join('_');
      }
      
      return fileName;
    } catch (e) {
      return 'fichier';
    }
  }

  bool _isImageFile(String fileName) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final lowerFileName = fileName.toLowerCase();
    return imageExtensions.any((ext) => lowerFileName.endsWith(ext));
  }

  // Méthode pour afficher les images Base64
  Widget _buildBase64ImageAttachment(String base64Image, int index) {
    try {
      final bytes = base64Decode(base64Image);
      return GestureDetector(
        onTap: () => _showBase64ImageDialog(context, bytes, index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Image.memory(
                  bytes,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImageErrorWidget();
                  },
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Erreur décodage Base64: $e');
      return _buildImageErrorWidget();
    }
  }

  Widget _buildImageErrorWidget() {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
          const SizedBox(height: 8),
          const Text(
            'Erreur d\'affichage',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showBase64ImageDialog(BuildContext context, Uint8List imageBytes, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAttachment(String fileUrl, String fileName) {
    final isDownloading = _downloadingFiles[fileUrl] == true;

    return GestureDetector(
      onTap: isDownloading ? null : () => _openFile(fileUrl, fileName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                fileUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildImageErrorWidget();
                },
              ),
              
              if (!isDownloading)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.zoom_in,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              
              if (isDownloading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 8),
                            Text(
                              'Téléchargement...',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileAttachment(String fileUrl, String fileName) {
    final fileType = FileService.getFileType(fileName);
    final isDownloading = _downloadingFiles[fileUrl] == true;

    // Méthode helper pour convertir FileType en String
    String getFileTypeName(dynamic type) {
      if (type is String) return type;
      if (type is Enum) return type.name;
      return type.toString();
    }

    return GestureDetector(
      onTap: isDownloading ? null : () => _openFile(fileUrl, fileName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FileService.getFileColor(fileType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                FileService.getFileIcon(fileType),
                size: 24,
                color: FileService.getFileColor(fileType),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getFileTypeName(fileType).toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isDownloading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.download,
                color: Colors.grey[600],
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    final hasBase64Images = widget.announcement.base64Images.isNotEmpty;
    final hasAttachments = widget.announcement.attachments.isNotEmpty;

    if (!hasBase64Images && !hasAttachments) {
      return const SizedBox.shrink();
    }

    final imageAttachments = widget.announcement.attachments
        .where((url) => _isImageFile(_getFileNameFromUrl(url)))
        .toList();
    
    final fileAttachments = widget.announcement.attachments
        .where((url) => !_isImageFile(_getFileNameFromUrl(url)))
        .toList();

    final hasImageUrls = imageAttachments.isNotEmpty;
    final hasFiles = fileAttachments.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Images Base64
        if (hasBase64Images) ...[
          const SizedBox(height: 12),
          const Text(
            '📷 Photos',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: widget.announcement.base64Images
                .asMap()
                .entries
                .map((entry) => _buildBase64ImageAttachment(entry.value, entry.key))
                .toList(),
          ),
        ],

        // Section Images URLs
        if (hasImageUrls) ...[
          const SizedBox(height: 12),
          const Text(
            '📷 Photos',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: imageAttachments
                .map((url) => _buildImageAttachment(url, _getFileNameFromUrl(url)))
                .toList(),
          ),
        ],

        // Section Fichiers
        if (hasFiles) ...[
          const SizedBox(height: 12),
          const Text(
            '📎 Fichiers',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: fileAttachments
                .map((url) => _buildFileAttachment(url, _getFileNameFromUrl(url)))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? Colors.blue[700] : Colors.grey[600],
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.blue[700] : Colors.grey[600],
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;
    final isLiked = user != null ? widget.announcement.isLikedBy(user.uid) : false;
    final isAuthor = user != null && widget.announcement.authorId == user.uid;
    final shouldShowReadMore = widget.announcement.content.length > _maxContentLength && !_showFullContent;

    // DEBUG
    print('🎯 AnnouncementCard - ID: ${widget.announcement.id}');
    print('🎯 AnnouncementCard - ClassID: ${widget.announcement.classId}');
    print('🎯 AnnouncementCard - Likes: ${widget.announcement.likesCount}');
    print('🎯 AnnouncementCard - Comments: ${widget.announcement.commentsCount}');
    print('🎯 AnnouncementCard - IsLiked: $isLiked');
    print('🎯 AnnouncementCard - User: ${user?.uid}');

    if (_isDeleting) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Suppression en cours...'),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec menu de suppression
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.announcement.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTimeAgo(widget.announcement.timestamp),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAuthor) ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation();
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Titre
            if (widget.announcement.title.isNotEmpty) ...[
              Text(
                widget.announcement.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Contenu avec "Lire plus"
            Text(
              _showFullContent 
                  ? widget.announcement.content
                  : shouldShowReadMore
                      ? '${widget.announcement.content.substring(0, _maxContentLength)}...'
                      : widget.announcement.content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
            if (shouldShowReadMore) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showFullContent = true;
                  });
                },
                child: Text(
                  'Lire plus',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Pièces jointes
            _buildAttachments(),

            // Statistiques discrètes
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.announcement.likesCount > 0) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.thumb_up, size: 12, color: Colors.blue[700]),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.announcement.likesCount}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.announcement.commentsCount > 0) ...[
                    Text(
                      '${widget.announcement.commentsCount} commentaire${widget.announcement.commentsCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Boutons d'action avec design moderne
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                      label: 'J\'aime',
                      isActive: isLiked,
                      onTap: _toggleLike,
                      isLoading: _isLiking,
                    ),
                  ),
                  Expanded(
                    child: _buildActionButton(
                      icon: _showComments ? Icons.comment : Icons.comment_outlined,
                      label: 'Commenter',
                      isActive: _showComments,
                      onTap: () {
                        setState(() {
                          _showComments = !_showComments;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Section commentaires avec animation
            if (_showComments) ...[
              const SizedBox(height: 16),
              _CommentsSection(
                announcement: widget.announcement,
                commentController: _commentController,
                onAddComment: _addComment,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class _CommentsSection extends StatelessWidget {
  final Announcement announcement;
  final TextEditingController commentController;
  final VoidCallback onAddComment;

  const _CommentsSection({
    required this.announcement,
    required this.commentController,
    required this.onAddComment,
  });

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (announcement.comments.isNotEmpty) ...[
          ...announcement.comments.take(5).map((comment) {
            return _CommentItem(comment: comment);
          }).toList(),
          
          if (announcement.comments.length > 5) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fonctionnalité à venir')),
                  );
                },
                child: Text(
                  'Voir les ${announcement.comments.length - 5} commentaires supplémentaires',
                  style: TextStyle(color: Colors.blue[600]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: 'Écrivez un commentaire...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => onAddComment(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onAddComment,
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;

  const _CommentItem({required this.comment});

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 16, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Text(
                        _formatTimeAgo(comment.timestamp),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (comment.likesCount > 0) ...[
                        Icon(Icons.thumb_up, size: 10, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(
                          '${comment.likesCount}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}