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

  void _toggleLike() async {
    if (_isLiking) return;

    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _isLiking = true);

    try {
      await _firestoreService.toggleLike(
        announcementId: widget.announcement.id,
        userId: user.uid,
        userName: '${user.firstName} ${user.lastName}',
      );
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      setState(() => _isLiking = false);
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

    // Vérifier que l'utilisateur est bien l'auteur
    final isAuthor = await _firestoreService.isUserAuthor(
      widget.announcement.id,
      user.uid,
    );

    if (!isAuthor) {
      _showError('Vous n\'êtes pas autorisé à supprimer cette annonce');
      return;
    }

    setState(() => _isDeleting = true);

    try {
      await _firestoreService.deleteAnnouncement(widget.announcement.id);
      
      _showSuccess('Annonce supprimée avec succès');
      
      // Notifier le parent widget que l'annonce a été supprimée
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
    // Vérifier si le fichier est déjà en cours de téléchargement
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

  void _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      await _firestoreService.addComment(
        announcementId: widget.announcement.id,
        userId: user.uid,
        userName: '${user.firstName} ${user.lastName}',
        content: _commentController.text.trim(),
      );
      
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      _showError('Erreur: $e');
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
      // Extraire le nom du fichier du chemin
      final segments = path.split('/');
      String fileName = segments.last;
      
      // Décoder les caractères encodés (comme %20 pour les espaces)
      fileName = Uri.decodeComponent(fileName);
      
      // Supprimer le timestamp ajouté lors de l'upload
      final parts = fileName.split('_');
      if (parts.length > 1) {
        // Garder seulement le nom original
        return parts.sublist(1).join('_');
      }
      
      return fileName;
    } catch (e) {
      // En cas d'erreur, retourner une version simplifiée
      return 'fichier';
    }
  }

  Widget _buildAttachmentChip(String fileUrl) {
    final fileName = _getFileNameFromUrl(fileUrl);
    final fileType = FileService.getFileType(fileName);
    final isDownloading = _downloadingFiles[fileUrl] == true;

    return GestureDetector(
      onTap: isDownloading ? null : () => _openFile(fileUrl, fileName),
      child: Chip(
        avatar: isDownloading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                FileService.getFileIcon(fileType),
                size: 16,
                color: FileService.getFileColor(fileType),
              ),
        label: Text(
          fileName.length > 20 ? '${fileName.substring(0, 20)}...' : fileName,
          style: TextStyle(
            fontSize: 12,
            color: isDownloading ? Colors.grey : null,
          ),
        ),
        backgroundColor: isDownloading ? Colors.grey[100] : Colors.grey[50],
        side: BorderSide(
          color: isDownloading ? Colors.grey[300]! : Colors.grey[300]!,
        ),
      ),
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
                // Menu de suppression (seulement pour l'auteur)
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

            // Pièces jointes avec design amélioré
            if (widget.announcement.attachments.isNotEmpty) ...[
              const Text(
                '📎 Pièces jointes',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.announcement.attachments
                    .map((fileUrl) => _buildAttachmentChip(fileUrl))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

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
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: _CommentsSection(
                  announcement: widget.announcement,
                  commentController: _commentController,
                  onAddComment: _addComment,
                ),
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
        // Liste des commentaires avec limite
        if (announcement.comments.isNotEmpty) ...[
          ...announcement.comments.take(5).map((comment) {
            return _CommentItem(comment: comment);
          }).toList(),
          
          // Bouton "Voir plus de commentaires" si nécessaire
          if (announcement.comments.length > 5) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: Naviguer vers une page dédiée aux commentaires
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

        // Champ de commentaire
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