// screens/teacher/teacher_home.dart
import 'package:Joussour/widgets/pwa_install_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:Joussour/models/announcement_model.dart';
import 'package:Joussour/models/class_model.dart';
import 'package:Joussour/models/message_model.dart';
import 'package:Joussour/models/student_model.dart';
import 'package:Joussour/models/user_model.dart';
import 'package:Joussour/screens/shared/chat_screen.dart';
import 'package:Joussour/screens/teacher/add_student_screen.dart';
import 'package:Joussour/screens/teacher/sanction_management.dart';
import 'package:Joussour/services/auth_service.dart';
import 'package:Joussour/services/firestore_service.dart';
import 'package:Joussour/widgets/student_sanction_badge.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'create_announcement.dart';
import 'teacher_messaging.dart';
import '../../widgets/announcement_card.dart';
import 'class_creation_screen.dart';
import 'class_selection_screen.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectDefaultClass();
    });
  }

  void _selectDefaultClass() {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null && user.classIds.isNotEmpty) {
      setState(() {
        _selectedClassId = user.classIds.first;
      });
      print('🎯 Classe sélectionnée par défaut: $_selectedClassId');
    } else {
      print('⚠️ Aucune classe disponible pour cet utilisateur');
    }
  }

  // ÉCOUTER LES CHANGEMENTS DANS LE USER PROVIDER
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<UserProvider>(context).user;

    // Si l'utilisateur a des classes mais aucune n'est sélectionnée
    if (user != null && user.classIds.isNotEmpty && _selectedClassId == null) {
      print('🔄 Mise à jour: Sélection d\'une classe par défaut');
      _selectDefaultClass();
    }

    // Si la classe sélectionnée n'existe plus dans la liste
    if (user != null &&
        _selectedClassId != null &&
        !user.classIds.contains(_selectedClassId)) {
      print('🔄 Mise à jour: Classe sélectionnée n\'existe plus, resélection');
      _selectDefaultClass();
    }
  }

  void _showClassSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClassSelectionBottomSheet(
        onClassSelected: (classId) {
          setState(() {
            _selectedClassId = classId;
          });
          print('🎯 Classe sélectionnée: $classId');
          Navigator.pop(context);
        },
      ),
    );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    // AFFICHER LE NOMBRE DE CLASSES POUR DÉBOGUAGE
    print('📊 TeacherHome - User: ${user?.email}');
    print('📊 TeacherHome - Classes: ${user?.classIds}');
    print('📊 TeacherHome - Classe sélectionnée: $_selectedClassId');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue, ${user?.firstName ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            if (_selectedClassId != null)
              StreamBuilder<ClassModel?>(
                stream: FirestoreService().getClassStream(_selectedClassId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text(
                      'Chargement...',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Text(
                      'Erreur de chargement',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    );
                  }

                  final className = snapshot.data?.name ?? 'Classe non trouvée';
                  return Text(
                    className,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  );
                },
              ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          // Bouton de sélection de classe
          if (user != null && user.classIds.length > 1)
            IconButton(
              icon: const Icon(Icons.class_),
              onPressed: _showClassSelection,
              tooltip: 'Changer de classe',
            ),
          // Bouton pour créer une nouvelle classe
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              // ATTENDRE LE RETOUR AVEC RAFRAÎCHISSEMENT
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClassCreationScreen(),
                ),
              );

              // RAFRAÎCHIR APRÈS RETOUR
              if (mounted) {
                final updatedUser = Provider.of<UserProvider>(
                  context,
                  listen: false,
                ).user;
                print(
                  '🔄 Retour création classe - Classes: ${updatedUser?.classIds}',
                );

                if (updatedUser != null && updatedUser.classIds.isNotEmpty) {
                  if (_selectedClassId == null) {
                    setState(() {
                      _selectedClassId = updatedUser.classIds.first;
                    });
                    print('🎯 Nouvelle classe sélectionnée: $_selectedClassId');
                  }
                }
              }
            },
            tooltip: 'Créer une classe',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.blue, size: 30),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Enseignant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tableau de bord',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // 🔥 BOUTON D'INSTALLATION PWA
            const PwaInstallButton(),
            const Divider(),

            // Menu principal
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.blue),
              title: const Text('Tableau de bord'),
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group, color: Colors.green),
              title: const Text('Gestion des élèves'),
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.gavel, color: Colors.orange),
              title: const Text('Sanctions'),
              onTap: () {
                setState(() => _currentIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.purple),
              title: const Text('Messagerie'),
              onTap: () {
                setState(() => _currentIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.teal),
              title: const Text('Profil'),
              onTap: () {
                setState(() => _currentIndex = 4);
                Navigator.pop(context);
              },
            ),
            const Divider(),

            // Section paramètres
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Paramètres',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paramètres - Fonctionnalité à venir'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help, color: Colors.grey),
              title: const Text('Aide & Support'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Aide & Support - Fonctionnalité à venir'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.grey),
              title: const Text('À propos'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('À propos - Fonctionnalité à venir'),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      body: _selectedClassId != null
          ? _buildScreenWithClass()
          : const NoClassScreen(),
      bottomNavigationBar: _selectedClassId != null
          ? BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF1976D2),
              unselectedItemColor: const Color(0xFF757575),
              selectedIconTheme: const IconThemeData(size: 24),
              unselectedIconTheme: const IconThemeData(size: 22),
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              type: BottomNavigationBarType.fixed,
              elevation: 8,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.announcement_outlined),
                  activeIcon: Icon(Icons.announcement),
                  label: 'Annonces',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_outlined),
                  activeIcon: Icon(Icons.group),
                  label: 'Élèves',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.gavel_outlined),
                  activeIcon: Icon(Icons.gavel),
                  label: 'Sanctions',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.message_outlined),
                  activeIcon: Icon(Icons.message),
                  label: 'Messages',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outlined),
                  activeIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            )
          : null,
      floatingActionButton: _currentIndex == 0 && _selectedClassId != null
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateAnnouncementScreen(classId: _selectedClassId!),
                  ),
                );
              },
              backgroundColor: const Color(0xFF1976D2),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildScreenWithClass() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        AnnouncementsTab(classId: _selectedClassId!),
        ClassManagementTab(classId: _selectedClassId!),
        SanctionsTab(classId: _selectedClassId!),

        TeacherMessagingTab(classId: _selectedClassId!),
        const ProfileTab(),
      ],
    );
  }
}

class SanctionsTab extends StatelessWidget {
  final String classId;

  const SanctionsTab({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SanctionManagementScreen(classId: classId));
  }
}

class NoClassScreen extends StatelessWidget {
  const NoClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.class_, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'Aucune classe',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Créez votre première classe pour commencer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClassCreationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer une classe'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// screens/teacher/teacher_home.dart - CORRECTION de AnnouncementsTab
class AnnouncementsTab extends StatefulWidget {
  final String classId;

  const AnnouncementsTab({super.key, required this.classId});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  void _refreshAnnouncements() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: () async {
        setState(() {});
      },
      child: StreamBuilder<List<Announcement>>(
        stream: FirestoreService().getAnnouncementsStream(
          widget.classId,
        ), // CHANGÉ: getAnnouncementsStream au lieu de getAnnouncements
        builder: (context, snapshot) {
          // DEBUG: Afficher l'état du stream
          print(
            '📊 AnnouncementsTab - ConnectionState: ${snapshot.connectionState}',
          );
          print('📊 AnnouncementsTab - HasError: ${snapshot.hasError}');
          print('📊 AnnouncementsTab - HasData: ${snapshot.hasData}');
          if (snapshot.hasData) {
            print(
              '📊 AnnouncementsTab - Nombre d\'annonces: ${snapshot.data!.length}',
            );
            for (var announcement in snapshot.data!) {
              print(
                '📊 Announcement: ${announcement.title} - Base64: ${announcement.base64Images.length} - Attachments: ${announcement.attachments.length}',
              );
            }
          }

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
            print('❌ AnnouncementsTab - Erreur: ${snapshot.error}');
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshAnnouncements,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final announcements = snapshot.data ?? [];

          if (announcements.isEmpty) {
            print('ℹ️ AnnouncementsTab - Aucune annonce trouvée');
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.announcement_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune annonce',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          'Les annonces de cette classe apparaîtront ici dès qu\'elles seront publiées',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateAnnouncementScreen(
                                classId: widget.classId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Créer la première annonce'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          print(
            '✅ AnnouncementsTab - ${announcements.length} annonces affichées',
          );
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return AnnouncementCard(
                announcement: announcement,
                onAnnouncementDeleted: _refreshAnnouncements,
              );
            },
          );
        },
      ),
    );
  }
}

class ClassManagementTab extends StatefulWidget {
  final String classId;

  const ClassManagementTab({super.key, required this.classId});

  @override
  State<ClassManagementTab> createState() => _ClassManagementTabState();
}

class _ClassManagementTabState extends State<ClassManagementTab> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un élève'),
        content: const Text('Comment souhaitez-vous ajouter un élève ?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _addSingleStudent();
            },
            child: const Text('Ajouter un seul élève'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showBulkAddInfo();
            },
            child: const Text('Ajouter plusieurs élèves'),
          ),
        ],
      ),
    );
  }

  void _addSingleStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentScreen(classId: widget.classId),
      ),
    );
  }

  void _showBulkAddInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajout multiple'),
        content: const Text(
          'Pour ajouter plusieurs élèves à la fois, utilisez le format CSV avec les colonnes: Prénom, Nom',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showStudentOptions(Student student) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                _editStudent(student);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Générer code parent'),
              onTap: () {
                Navigator.pop(context);
                _generateParentCode(student);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteStudent(student);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editStudent(Student student) {
    showDialog(
      context: context,
      builder: (context) => _StudentEditDialog(student: student),
    );
  }

  // Dans _ClassManagementTabState - modifiez la méthode _generateParentCode
  void _generateParentCode(Student student) async {
    try {
      final code = await _firestoreService.generateStudentCode(student.id);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _ParentCodeDialog(student: student, code: code),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _deleteStudent(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'élève'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer ${student.fullName} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.deleteStudent(
                  student.id,
                  widget.classId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Élève supprimé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // En-tête avec bouton d'ajout
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Liste des élèves',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FloatingActionButton(
                onPressed: _showAddStudentDialog,
                mini: true,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),

        // Liste des élèves
        Expanded(
          child: StreamBuilder<List<Student>>(
            stream: _firestoreService.getStudents(widget.classId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final students = snapshot.data ?? [];

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun élève',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ajoutez votre premier élève',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showAddStudentDialog,
                        child: const Text('Ajouter un élève'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              student.firstName.isNotEmpty
                                  ? student.firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: StudentSanctionBadge(studentId: student.id),
                          ),
                        ],
                      ),
                      title: Text(student.fullName),
                      subtitle: Text(
                        student.parentId != null
                            ? 'Lien parent activé'
                            : 'En attente de lien parent',
                        style: TextStyle(
                          color: student.parentId != null
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => _showStudentOptions(student),
                      ),
                    ),
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

// Dialogue pour modifier un élève
class _StudentEditDialog extends StatefulWidget {
  final Student student;

  const _StudentEditDialog({required this.student});

  @override
  State<_StudentEditDialog> createState() => _StudentEditDialogState();
}

class _StudentEditDialogState extends State<_StudentEditDialog> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController.text = widget.student.firstName;
    _lastNameController.text = widget.student.lastName;
  }

  Future<void> _updateStudent() async {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.updateStudent(
        studentId: widget.student.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        classId: widget.student.classId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Élève modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier l\'élève'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'Prénom'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateStudent,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Modifier'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}

// Dans teacher_home.dart - remplacer TeacherMessagingTab
class TeacherMessagingTab extends StatefulWidget {
  final String classId;

  const TeacherMessagingTab({super.key, required this.classId});

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

                // Vérifier que c'est un parent
                if (user.role == 'parent') {
                  // Récupérer l'élève associé à ce parent
                  final studentQuery = await _firestore
                      .collection('students')
                      .where('parentId', isEqualTo: otherUserId)
                      .get();

                  if (studentQuery.docs.isNotEmpty) {
                    final student = Student.fromMap(
                      studentQuery.docs.first.data(),
                    );

                    // Vérifier que l'élève appartient à la classe actuelle
                    if (student.classId == widget.classId) {
                      final unreadCount = await _getUnreadCount(
                        teacherId,
                        otherUserId,
                      );

                      conversations[conversationKey] = {
                        'parent': user,
                        'student': student,
                        'lastMessage': message,
                        'unreadCount': unreadCount,
                      };
                    }
                  }
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

  void _startNewConversation(BuildContext context, String teacherId) {
    showDialog(
      context: context,
      builder: (context) => _NewConversationDialog(
        classId: widget.classId,
        teacherId: teacherId,
        onConversationStarted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation démarrée !')),
          );
        },
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    if (user == null) {
      return const Center(child: Text('Utilisateur non connecté'));
    }

    return Column(
      children: [
        // En-tête
        // Dans _TeacherMessagingTabState - ajoutez cette méthode

        // Ajoutez ce bouton dans l'en-tête du TeacherMessagingTab
        // Remplacez la Row dans l'en-tête par :
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
                    'Communiquez avec les parents',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_comment, color: Colors.blue),
                onPressed: () => _startNewConversation(context, user.uid),
                tooltip: 'Nouvelle conversation',
              ),
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
                        'Vos conversations avec les parents\napparaîtront ici',
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
                  final parent = conversation['parent'] as UserModel;
                  final student = conversation['student'] as Student;
                  final lastMessage = conversation['lastMessage'] as Message;
                  final unreadCount = conversation['unreadCount'] as int;

                  return TeacherConversationTile(
                    parent: parent,
                    student: student,
                    lastMessage: lastMessage,
                    unreadCount: unreadCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: parent.uid,
                            otherUserName:
                                '${parent.firstName} ${parent.lastName}',
                            otherUserRole: parent.role,
                            student: student,
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

class TeacherConversationTile extends StatelessWidget {
  final UserModel parent;
  final Student student;
  final Message lastMessage;
  final int unreadCount;
  final VoidCallback onTap;

  const TeacherConversationTile({
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
          backgroundColor: Colors.blue,
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

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Profil Enseignant',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
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
                  'Informations personnelles',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.person,
                  title: 'Nom complet',
                  value: '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                ),
                _buildInfoItem(
                  icon: Icons.email,
                  title: 'Email',
                  value: user?.email ?? '',
                ),
                _buildInfoItem(
                  icon: Icons.school,
                  title: 'Rôle',
                  value: user?.role == 'teacher' ? 'Enseignant' : 'Parent',
                ),
                if (user?.classIds.isNotEmpty ?? false) ...[
                  _buildInfoItem(
                    icon: Icons.class_,
                    title: 'Nombre de classes',
                    value: '${user!.classIds.length} classe(s)',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.add, color: Colors.blue),
                  title: const Text('Créer une nouvelle classe'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ClassCreationScreen(),
                      ),
                    );
                  },
                ),
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

// Ajoutez cette classe dans le même fichier teacher_home.dart
class _ParentCodeDialog extends StatefulWidget {
  final Student student;
  final String code;

  const _ParentCodeDialog({required this.student, required this.code});

  @override
  State<_ParentCodeDialog> createState() => _ParentCodeDialogState();
}

class _ParentCodeDialogState extends State<_ParentCodeDialog> {
  bool _isCopied = false;

  Future<void> _copyToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      setState(() {
        _isCopied = true;
      });

      // Réinitialiser l'état après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code copié dans le presse-papiers !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la copie: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Code d\'invitation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informations de l'élève
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.student.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Code généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Code d'invitation
          const Text(
            'Code d\'invitation pour les parents:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),

          // Container avec le code
          GestureDetector(
            onTap: _copyToClipboard,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    widget.code,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isCopied ? Icons.check : Icons.content_copy,
                        size: 16,
                        color: _isCopied ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isCopied ? 'Copié !' : 'Cliquer pour copier',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isCopied ? Colors.green : Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[700],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Donnez ce code aux parents pour qu\'ils puissent s\'inscrire et se connecter à l\'application.',
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Le code est valable pour cet élève uniquement.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        ElevatedButton.icon(
          onPressed: _copyToClipboard,
          icon: Icon(_isCopied ? Icons.check : Icons.content_copy, size: 18),
          label: Text(_isCopied ? 'Copié !' : 'Copier'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCopied ? Colors.green : Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Ajoutez cette classe dans teacher_home.dart
class _NewConversationDialog extends StatefulWidget {
  final String classId;
  final String teacherId;
  final VoidCallback onConversationStarted;

  const _NewConversationDialog({
    required this.classId,
    required this.teacherId,
    required this.onConversationStarted,
  });

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Student> _students = [];
  Student? _selectedStudent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: widget.classId)
          .where(
            'parentId',
            isNotEqualTo: null,
          ) // Seulement les élèves avec parent
          .get();

      setState(() {
        _students = snapshot.docs
            .map((doc) => Student.fromMap(doc.data()))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startConversation() async {
    if (_selectedStudent == null) return;

    try {
      // Récupérer le parent de l'élève
      final parentDoc = await _firestore
          .collection('users')
          .doc(_selectedStudent!.parentId!)
          .get();

      if (parentDoc.exists) {
        final parent = UserModel.fromMap(parentDoc.data()!);

        // Créer un message initial
        final initialMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: widget.teacherId,
          receiverId: parent.uid,
          studentId: _selectedStudent!.id,
          content:
              'Bonjour, je suis l\'enseignant de ${_selectedStudent!.firstName}',
          timestamp: DateTime.now(),
          isRead: false,
          participants: [widget.teacherId, parent.uid],
        );

        // Envoyer le message
        await _firestore
            .collection('messages')
            .doc(initialMessage.id)
            .set(initialMessage.toMap());

        if (mounted) {
          Navigator.pop(context);
          widget.onConversationStarted();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle conversation'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Text(_error!)
            : _students.isEmpty
            ? const Text('Aucun parent disponible pour cette classe')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sélectionnez un élève :'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Student>(
                    value: _selectedStudent,
                    items: _students.map((student) {
                      return DropdownMenuItem(
                        value: student,
                        child: Text(student.fullName),
                      );
                    }).toList(),
                    onChanged: (student) {
                      setState(() {
                        _selectedStudent = student;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Élève',
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _selectedStudent != null ? _startConversation : null,
          child: const Text('Démarrer la conversation'),
        ),
      ],
    );
  }
}
