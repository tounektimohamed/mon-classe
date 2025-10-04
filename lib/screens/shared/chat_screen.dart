// screens/shared/chat_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mon_classe_manegment/widgets/message_bubble.dart';
import '../../models/message_model.dart';
import '../../models/student_model.dart';
import '../../services/message_service.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserRole;
  final Student student;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    required this.student,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final MessageService _messageService = MessageService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  bool _canSendMessage = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_updateSendButtonState);
    _markMessagesAsRead();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _updateSendButtonState() {
    final canSend = _messageController.text.trim().isNotEmpty;
    if (_canSendMessage != canSend) {
      setState(() {
        _canSendMessage = canSend;
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: widget.currentUserId,
      receiverId: widget.otherUserId,
      studentId: widget.student.id,
      content: message,
      timestamp: DateTime.now(),
      isRead: false,
      participants: [widget.currentUserId, widget.otherUserId],
      messageType: 'text',
    );

    try {
      await _messageService.sendMessage(newMessage);
      _messageController.clear();
      _scrollToBottom();
      setState(() {
        _canSendMessage = false;
      });
    } catch (e) {
      _showError('Erreur lors de l\'envoi: $e');
    }
  }

  /// ✅ Envoi image Firebase + encodage Base64 Firestore
  Future<void> _sendImage() async {
    try {
      Uint8List? imageData;
      String? fileName;

      if (kIsWeb) {
        final imageInfo = await ImagePickerWeb.getImageAsBytes();
        if (imageInfo != null) {
          imageData = imageInfo;
          fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserId}.jpg';
        }
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1024,
        );
        if (image != null) {
          imageData = await image.readAsBytes();
          fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${widget.currentUserId}.jpg';
        }
      }

      if (imageData == null) return;

      setState(() => _isUploading = true);

      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images/${widget.student.id}/$fileName');

      final UploadTask uploadTask = storageRef.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // 🔥 Convertir image en Base64 (pour Firestore et affichage web)
      String base64String = base64Encode(imageData);

      final imageMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: widget.currentUserId,
        receiverId: widget.otherUserId,
        studentId: widget.student.id,
        content: '📷 Image',
        timestamp: DateTime.now(),
        isRead: false,
        participants: [widget.currentUserId, widget.otherUserId],
        messageType: 'image',
        fileUrl: downloadUrl,
        fileBase64: base64String,
      );

      await _messageService.sendMessage(imageMessage);
      _scrollToBottom();

      _showSuccess('Image envoyée avec succès');
    } catch (e) {
      _showError('Erreur lors de l\'envoi de l\'image: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _markMessagesAsRead() {
    _messageService.markMessagesAsRead(widget.currentUserId, widget.otherUserId);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onMessageSent() {
    if (_canSendMessage) {
      _sendMessage();
      _focusNode.requestFocus();
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: Text(kIsWeb ? 'Importer une image' : 'Galerie photos'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            Text(
              widget.otherUserRole == 'teacher'
                  ? 'Enseignant'
                  : 'Parent de ${widget.student.firstName}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messageService.getConversationMessages(
                widget.currentUserId,
                widget.otherUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Aucun message. Commencez la conversation !'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      message: message,
                      isMe: message.senderId == widget.currentUserId,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.blue),
                  onPressed: _isUploading ? null : _showAttachmentOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Tapez votre message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                    onChanged: (_) => _updateSendButtonState(),
                    onSubmitted: (_) => _onMessageSent(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor:
                      _canSendMessage ? Colors.blue : Colors.grey,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _canSendMessage && !_isUploading
                        ? _onMessageSent
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_updateSendButtonState);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
