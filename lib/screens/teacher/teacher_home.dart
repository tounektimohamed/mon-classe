import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/models/announcement_model.dart';
import 'package:mon_classe_manegment/services/auth_service.dart';
import 'package:mon_classe_manegment/services/firestore_service.dart';
import 'package:mon_classe_manegment/widgets/announcement_card.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'class_management.dart';
import 'create_announcement.dart';
import 'teacher_messaging.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AnnouncementsTab(),
    const ClassManagementTab(),
    const TeacherMessagingTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenue, ${user?.firstName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                // Déconnecter d'abord de Firebase
                await AuthService().signOut();

                // Puis nettoyer le provider
                if (mounted) {
                  Provider.of<UserProvider>(context, listen: false).signOut();
                }

                // Message de confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Déconnexion réussie'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                print('Erreur déconnexion: $e');
              }
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white, // Couleur de fond
        selectedItemColor: Colors.blue[800], // Couleur de l'item sélectionné
        unselectedItemColor:
            Colors.grey[600], // Couleur des items non sélectionnés
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.announcement),
            label: 'Annonces',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Élèves'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateAnnouncementScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class AnnouncementsTab extends StatelessWidget {
  const AnnouncementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return StreamBuilder<List<Announcement>>(
      stream: FirestoreService().getAnnouncements(user!.classId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final announcements = snapshot.data ?? [];

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

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profil Enseignant',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Nom complet'),
            subtitle: Text('${user?.firstName} ${user?.lastName}'),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            subtitle: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Rôle'),
            subtitle: Text(user?.role == 'teacher' ? 'Enseignant' : 'Parent'),
          ),
        ],
      ),
    );
  }
}
