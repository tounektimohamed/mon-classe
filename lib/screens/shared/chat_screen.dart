import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mon_classe_manegment/widgets/message_bubble.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../models/student_model.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  final Student student;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.student,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: widget.currentUserId,
      receiverId: widget.otherUser.uid,
      studentId: widget.student.id,
      content: message,
      timestamp: DateTime.now(),
      isRead: false,
      participants: [widget.currentUserId, widget.otherUser.uid],
    );

    try {
      await _firestore
          .collection('messages')
          .doc(newMessage.id)
          .set(newMessage.toMap());

      _messageController.clear();
      
      // Faire défiler vers le bas
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi message: $e')),
      );
    }
  }

  void _markMessagesAsRead() async {
    final snapshot = await _firestore
        .collection('messages')
        .where('participants', arrayContains: widget.currentUserId)
        .get();

    final batch = _firestore.batch();
    
    for (final doc in snapshot.docs) {
      final message = Message.fromMap(doc.data() as Map<String, dynamic>);
      // Marquer comme lu seulement si l'expéditeur est l'autre utilisateur ET non lu
      if (message.senderId == widget.otherUser.uid && !message.isRead) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    
    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.otherUser.firstName} ${widget.otherUser.lastName}'),
            Text(
              widget.otherUser.role == 'teacher' 
                  ? 'Enseignant'
                  : 'Parent de ${widget.student.firstName}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // En-tête avec info élève
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Élève: ${widget.student.firstName} ${widget.student.lastName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('participants', arrayContains: widget.currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs
                    .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
                    .toList();

                // Filtrage côté client pour la conversation actuelle
                final conversationMessages = messages
                    .where((message) => message.participants.contains(widget.otherUser.uid))
                    .toList();

                // Tri côté client par timestamp (plus récent en premier)
                conversationMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                if (conversationMessages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Aucun message',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Commencez la conversation !',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: conversationMessages.length,
                  itemBuilder: (context, index) {
                    final message = conversationMessages[index];
                    
                    return MessageBubble(
                      message: message,
                      isMe: message.senderId == widget.currentUserId,
                    );
                  },
                );
              },
            ),
          ),
          // Zone de saisie
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Tapez votre message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
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
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}