// screens/parent/parent_home.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/models/message_model.dart';
import 'package:mon_classe_manegment/models/user_model.dart';
import 'package:mon_classe_manegment/screens/shared/chat_screen.dart';
import 'package:provider/provider.dart';
import '../../models/announcement_model.dart';
import '../../models/student_model.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/announcement_card.dart';
import 'parent_messaging.dart';

class ParentHome extends StatefulWidget {
  const ParentHome({super.key});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  int _currentIndex = 0;
  Student? _student;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;

      if (user != null) {
        print('👤 ParentHome - Chargement données pour: ${user.email}');
        await _loadStudentData(user.uid);
      } else {
        setState(() {
          _error = 'Aucun utilisateur connecté';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ ParentHome - Erreur chargement données: $e');
      setState(() {
        _error = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentData(String parentId) async {
    try {
      print('🔍 ParentHome - Recherche élève pour parent: $parentId');

      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('parentId', isEqualTo: parentId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final studentData = snapshot.docs.first.data();
        setState(() {
          _student = Student.fromMap(studentData);
        });
        print('✅ ParentHome - Élève chargé: ${_student!.fullName}');
      } else {
        print('⚠️ ParentHome - Aucun élève trouvé pour ce parent');
        setState(() {
          _error = 'Aucun élève associé à votre compte';
        });
      }
    } catch (e) {
      print('❌ ParentHome - Erreur chargement élève: $e');
      setState(() {
        _error = 'Erreur de chargement des données élève';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              child: const Text(
                'Déconnecter',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      await AuthService().signOut();
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).signOut();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion réussie'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
      print('❌ ParentHome - Erreur déconnexion: $e');
    }
  }

  void _retryLoadData() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    // Écran de chargement
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mon compte'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Chargement de vos données...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Écran d'erreur
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mon compte'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _showLogoutDialog,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Erreur de chargement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _retryLoadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _showLogoutDialog,
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Écran principal
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mon enfant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              _student?.fullName ?? 'Chargement...',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1976D2),
        unselectedItemColor: const Color(0xFF757575),
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 24),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Annonces',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    if (_student == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucun élève associé',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    switch (_currentIndex) {
      case 0:
        return ParentAnnouncementsTab(student: _student!);
      case 1:
        return ParentMessagingTab(student: _student!);

      case 2:
        return ParentProfileTab(
          user: Provider.of<UserProvider>(context).user!,
          student: _student!,
        );
      default:
        return const SizedBox();
    }
  }
}

class ParentAnnouncementsTab extends StatelessWidget {
  final Student student;

  const ParentAnnouncementsTab({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: FirestoreService().getAnnouncements(student.classId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Chargement des annonces...',
                  style: TextStyle(color: Colors.grey),
                ),
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

        final announcements = snapshot.data ?? [];

        if (announcements.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.announcement, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucune annonce',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Les annonces de l\'enseignant apparaîtront ici',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: announcements.length,
          itemBuilder: (context, index) {
            final announcement = announcements[index];
            return AnnouncementCard(announcement: announcement);
          },
        );
      },
    );
  }
}

// Dans parent_home.dart - remplacer ParentMessagingTab
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
                final existingMessage =
                    existingConversation['lastMessage'] as Message;
                if (existingMessage.timestamp.isAfter(message.timestamp)) {
                  continue;
                }
              }
            }

            seenConversations.add(conversationKey);

            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(otherUserId)
                  .get();
              if (userDoc.exists) {
                final user = UserModel.fromMap(
                  userDoc.data() as Map<String, dynamic>,
                );

                if (user.role == 'teacher') {
                  final unreadCount = await _getUnreadCount(
                    parentId,
                    otherUserId,
                  );

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

  void _startNewConversation(BuildContext context, String parentId) async {
    try {
      // Récupérer l'enseignant de la classe de l'élève
      final classDoc = await _firestore
          .collection('classes')
          .doc(widget.student.classId)
          .get();

      if (classDoc.exists) {
        final classData = classDoc.data()!;
        final teacherId = classData['teacherId'];

        // Vérifier si une conversation existe déjà
        final existingConversation = await _firestore
            .collection('messages')
            .where('participants', arrayContains: parentId)
            .get();

        bool conversationExists = false;
        for (final doc in existingConversation.docs) {
          final message = Message.fromMap(doc.data());
          if (message.participants.contains(teacherId)) {
            conversationExists = true;
            break;
          }
        }

        if (conversationExists) {
          // Si conversation existe, trouver le teacher UserModel
          final teacherDoc = await _firestore
              .collection('users')
              .doc(teacherId)
              .get();

          if (teacherDoc.exists) {
            final teacher = UserModel.fromMap(teacherDoc.data()!);
            _openChatWithTeacher(context, teacher, parentId);
          }
        } else {
          // Créer une nouvelle conversation
          _createNewConversationWithTeacher(context, teacherId, parentId);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openChatWithTeacher(
    BuildContext context,
    UserModel teacher,
    String parentId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: teacher.uid,
          otherUserName: '${teacher.firstName} ${teacher.lastName}',
          otherUserRole: teacher.role,
          student: widget.student,
          currentUserId: parentId,
        ),
      ),
    );
  }

  void _createNewConversationWithTeacher(
    BuildContext context,
    String teacherId,
    String parentId,
  ) async {
    try {
      // Récupérer les infos du teacher
      final teacherDoc = await _firestore
          .collection('users')
          .doc(teacherId)
          .get();

      if (teacherDoc.exists) {
        final teacher = UserModel.fromMap(teacherDoc.data()!);

        // Créer un message initial
        final initialMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: parentId,
          receiverId: teacherId,
          studentId: widget.student.id,
          content: 'Bonjour, je suis le parent de ${widget.student.firstName}',
          timestamp: DateTime.now(),
          isRead: false,
          participants: [parentId, teacherId],
        );

        // Envoyer le message
        await _firestore
            .collection('messages')
            .doc(initialMessage.id)
            .set(initialMessage.toMap());

        // Ouvrir la conversation
        _openChatWithTeacher(context, teacher, parentId);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
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
        // En-tête
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Communiquez avec l\'enseignant',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.blue),
                onPressed: () => setState(() {}),
                tooltip: 'Rafraîchir',
              ),
            ],
          ),
        ),

        // Liste des conversations
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getConversations(user.uid),
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
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
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
                        'L\'enseignant peut initier une conversation\navec vous à tout moment',
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
                            otherUserName:
                                '${teacher.firstName} ${teacher.lastName}',
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
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            teacher.firstName.isNotEmpty ? teacher.firstName[0] : 'E',
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
                fontWeight: unreadCount > 0
                    ? FontWeight.w500
                    : FontWeight.normal,
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

class ParentProfileTab extends StatelessWidget {
  final UserModel user;
  final Student student;

  const ParentProfileTab({
    super.key,
    required this.user,
    required this.student,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Informations',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // Carte profil parent
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
                const Text(
                  'Votre profil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.person,
                  title: 'Nom complet',
                  value: '${user.firstName} ${user.lastName}',
                ),
                _buildInfoItem(
                  icon: Icons.email,
                  title: 'Email',
                  value: user.email,
                ),
                _buildInfoItem(
                  icon: Icons.family_restroom,
                  title: 'Rôle',
                  value: 'Parent',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Carte informations enfant
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
                const Text(
                  'Votre enfant',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.school,
                  title: 'Prénom',
                  value: student.firstName,
                ),
                _buildInfoItem(
                  icon: Icons.badge,
                  title: 'Nom',
                  value: student.lastName,
                ),
                _buildInfoItem(
                  icon: Icons.calendar_today,
                  title: 'Dans la classe depuis',
                  value: _formatDate(student.createdAt),
                ),
                _buildInfoItem(
                  icon: Icons.class_,
                  title: 'ID de la classe',
                  value: student.classId,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Carte actions
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
                const Text(
                  'Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.blue),
                  title: const Text('Paramètres'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fonctionnalité à venir')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help, color: Colors.blue),
                  title: const Text('Aide et support'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fonctionnalité à venir')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
