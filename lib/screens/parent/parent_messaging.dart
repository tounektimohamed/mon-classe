import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/models/message_model.dart';
import 'package:mon_classe_manegment/widgets/message_bubble.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/student_model.dart';
import '../../providers/user_provider.dart';
import '../shared/chat_screen.dart';

class ParentMessagingTab extends StatelessWidget {
  final Student student;

  const ParentMessagingTab({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('classes')
          .doc(student.classId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Classe non trouvée'));
        }

        final classData = snapshot.data!.data() as Map<String, dynamic>;
        final teacherId = classData['teacherId'];

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(teacherId)
              .get(),
          builder: (context, teacherSnapshot) {
            if (teacherSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!teacherSnapshot.hasData || !teacherSnapshot.data!.exists) {
              return const Center(child: Text('Enseignant non trouvé'));
            }

            final teacher = UserModel.fromMap(
                teacherSnapshot.data!.data() as Map<String, dynamic>);

            return Column(
              children: [
                // Carte de conversation avec l'enseignant
                Card(
                  margin: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.school),
                    ),
                    title: Text('${teacher.firstName} ${teacher.lastName}'),
                    subtitle: const Text('Enseignant de la classe'),
                    trailing: const Icon(Icons.chat),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUser: teacher,
                            student: student,
                            currentUserId: user!.uid,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Vous pouvez échanger en privé avec l\'enseignant de votre enfant',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: _buildMessageHistory(user!.uid, teacherId),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessageHistory(String parentId, String teacherId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('participants', arrayContains: parentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!.docs
            .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        // Filtrage côté client pour le deuxième participant
        final conversationMessages = messages
            .where((message) => message.participants.contains(teacherId))
            .toList();

        // Tri côté client par timestamp (plus récent en premier)
        conversationMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Limite côté client
        final limitedMessages = conversationMessages.take(10).toList();

        if (limitedMessages.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucun message',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Envoyez votre premier message à l\'enseignant',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          reverse: true, // Pour afficher les plus récents en bas
          itemCount: limitedMessages.length,
          itemBuilder: (context, index) {
            final message = limitedMessages[index];
            
            return MessageBubble(
              message: message,
              isMe: message.senderId == parentId,
            );
          },
        );
      },
    );
  }
}