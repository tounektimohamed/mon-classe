import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _loadUserData();
  }

  Future<void> _loadStudentData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('parentId', isEqualTo: user!.uid)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _student = Student.fromMap(snapshot.docs.first.data());
        });
      }
    } catch (e) {
      print('Erreur chargement élève: $e');
    }
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _user = userProvider.user;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _student != null
            ? Text('${_student!.firstName} ${_student!.lastName}')
            : const Text('Mon enfant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF1976D2),
        unselectedItemColor: Color(0xFF757575),
        selectedIconTheme: IconThemeData(size: 28),
        unselectedIconTheme: IconThemeData(size: 24),
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Annonces',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    if (_student == null || _user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentIndex) {
      case 0:
        return ParentAnnouncementsTab(student: _student!);
      case 1:
        return ParentMessagingTab(student: _student!);
      case 2:
        return ParentProfileTab(user: _user!, student: _student!);
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
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

class ParentProfileTab extends StatelessWidget {
  final UserModel user;
  final Student student;

  const ParentProfileTab({super.key, required this.user, required this.student});

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
        Card(
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
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Nom complet'),
                  subtitle: Text('${user.firstName} ${user.lastName}'),
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(user.email),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
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
                ListTile(
                  leading: const Icon(Icons.school),
                  title: const Text('Prénom'),
                  subtitle: Text(student.firstName),
                ),
                ListTile(
                  leading: const Icon(Icons.family_restroom),
                  title: const Text('Nom'),
                  subtitle: Text(student.lastName),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Dans la classe depuis'),
                  subtitle: Text(_formatDate(student.createdAt)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}