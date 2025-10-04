import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/models/student_model.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../shared/chat_screen.dart';

class TeacherMessagingTab extends StatefulWidget {
  const TeacherMessagingTab({super.key});

  @override
  State<TeacherMessagingTab> createState() => _TeacherMessagingTabState();
}

class _TeacherMessagingTabState extends State<TeacherMessagingTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> _getConversations(String teacherId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: teacherId)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = <String, Map<String, dynamic>>{};
      final seenConversations = <String>{};

      for (final doc in snapshot.docs) {
        final message = Message.fromMap(doc.data() as Map<String, dynamic>);
        final otherUserId = message.senderId == teacherId 
            ? message.receiverId 
            : message.senderId;

        final conversationKey = '${teacherId}_$otherUserId';
        
        // Si on a déjà une conversation plus récente, on skip
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

        // Récupérer les infos du parent et de l'élève
        try {
          final userDoc = await _firestore.collection('users').doc(otherUserId).get();
          if (userDoc.exists) {
            final user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
            
            // Vérifier que c'est un parent
            if (user.role == 'parent') {
              // Récupérer l'élève associé à ce parent
              final studentQuery = await _firestore
                  .collection('students')
                  .where('parentId', isEqualTo: otherUserId)
                  .get();
              
              if (studentQuery.docs.isNotEmpty) {
                final student = Student.fromMap(studentQuery.docs.first.data());
                
                final unreadCount = await _getUnreadCount(teacherId, otherUserId);
                
                conversations[conversationKey] = {
                  'parent': user,
                  'student': student,
                  'lastMessage': message,
                  'unreadCount': unreadCount,
                };
              }
            }
          }
        } catch (e) {
          print('Erreur chargement conversation: $e');
        }
      }

      // Convertir en liste et trier par timestamp du dernier message
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

      // Filtrage côté client
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    if (user == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text(
                'Messages',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Future: Filtrer les messages non lus
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getConversations(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: ${snapshot.error}',
                        textAlign: TextAlign.center,
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
                        'Aucun message',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Les messages des parents apparaîtront ici',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  final parent = conversation['parent'] as UserModel;
                  final student = conversation['student'] as Student;
                  final lastMessage = conversation['lastMessage'] as Message;
                  final unreadCount = conversation['unreadCount'] as int;

                  return ConversationTile(
                    parent: parent,
                    student: student,
                    lastMessage: lastMessage,
                    unreadCount: unreadCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: parent.uid, // ← CORRECTION ICI
                            otherUserName: '${parent.firstName} ${parent.lastName}',
                            otherUserRole: parent.role,
                            student: student, // ← CORRECTION ICI
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

class ConversationTile extends StatelessWidget {
  final UserModel parent;
  final Student student;
  final Message lastMessage;
  final int unreadCount;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.parent,
    required this.student,
    required this.lastMessage,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            parent.firstName.isNotEmpty ? parent.firstName[0] : 'P',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          '${parent.firstName} ${parent.lastName}',
          style: TextStyle(
            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Élève: ${student.firstName} ${student.lastName}',
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
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
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
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}