// screens/parent/parent_messaging.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../shared/chat_screen.dart';

class ParentMessagingTab extends StatefulWidget {
  final Student student;

  const ParentMessagingTab({super.key, required this.student});

  @override
  State<ParentMessagingTab> createState() => _ParentMessagingTabState();
}

class _ParentMessagingTabState extends State<ParentMessagingTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> _getConversations(String parentId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: parentId)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = <String, Map<String, dynamic>>{};
      final seenConversations = <String>{};

      for (final doc in snapshot.docs) {
        final message = Message.fromMap(doc.data() as Map<String, dynamic>);
        final otherUserId = message.senderId == parentId 
            ? message.receiverId 
            : message.senderId;

        final conversationKey = '${parentId}_$otherUserId';
        
        if (seenConversations.contains(conversationKey)) {
          final existingConversation = conversations[conversationKey];
          if (existingConversation != null) {
            final existingMessage = existingConversation['lastMessage'] as Message;
            if (existingMessage.timestamp.isAfter(message.timestamp)) {
              continue;
            }
          }
        }

        seenConversations.add(conversationKey);

        try {
          // Récupérer les infos de l'enseignant
          final userDoc = await _firestore.collection('users').doc(otherUserId).get();
          if (userDoc.exists) {
            final user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
            
            if (user.role == 'teacher') {
              final unreadCount = await _getUnreadCount(parentId, otherUserId);
              
              conversations[conversationKey] = {
                'teacher': user,
                'lastMessage': message,
                'unreadCount': unreadCount,
              };
            }
          }
        } catch (e) {
          print('Erreur chargement conversation: $e');
        }
      }

      final conversationList = conversations.values.toList();
      conversationList.sort((a, b) {
        final lastMessageA = a['lastMessage'] as Message;
        final lastMessageB = b['lastMessage'] as Message;
        return lastMessageB.timestamp.compareTo(lastMessageA.timestamp);
      });

      return conversationList;
    });
  }

  Future<int> _getUnreadCount(String currentUserId, String otherUserId) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        final message = Message.fromMap(doc.data() as Map<String, dynamic>);
        if (message.senderId == otherUserId && 
            message.participants.contains(otherUserId) && 
            !message.isRead) {
          count++;
        }
      }
      return count;
    } catch (e) {
      print('Erreur comptage messages non lus: $e');
      return 0;
    }
  }

  void _startNewConversation(BuildContext context, String parentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle conversation'),
        content: const Text('Fonctionnalité à venir : choisir un enseignant'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return Column(
      children: [
        // En-tête avec bouton nouvelle conversation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Messagerie',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Communiquez avec les enseignants',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_comment, color: Colors.blue),
                onPressed: () => _startNewConversation(context, user!.uid),
                tooltip: 'Nouvelle conversation',
              ),
            ],
          ),
        ),

        // Liste des conversations
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getConversations(user!.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Chargement des conversations...'),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Erreur de chargement',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final conversations = snapshot.data ?? [];

              if (conversations.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucune conversation',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Vos conversations avec les enseignants\napparaîtront ici',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final teacher = conversation['teacher'] as UserModel;
                  final lastMessage = conversation['lastMessage'] as Message;
                  final unreadCount = conversation['unreadCount'] as int;

                  return ParentConversationTile(
                    teacher: teacher,
                    student: widget.student,
                    lastMessage: lastMessage,
                    unreadCount: unreadCount,
                    currentUserId: user.uid,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: teacher.uid,
                            otherUserName: '${teacher.firstName} ${teacher.lastName}',
                            otherUserRole: teacher.role,
                            student: widget.student,
                            currentUserId: user.uid,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ParentConversationTile extends StatelessWidget {
  final UserModel teacher;
  final Student student;
  final Message lastMessage;
  final int unreadCount;
  final String currentUserId;
  final VoidCallback onTap;

  const ParentConversationTile({
    super.key,
    required this.teacher,
    required this.student,
    required this.lastMessage,
    required this.unreadCount,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            teacher.firstName[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          '${teacher.firstName} ${teacher.lastName}',
          style: TextStyle(
            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enseignant',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              lastMessage.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            Text(
              _formatTime(lastMessage.timestamp),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: unreadCount > 0
            ? CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red,
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Aujourd\'hui à ${_formatHour(date)}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Hier à ${_formatHour(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatHour(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}