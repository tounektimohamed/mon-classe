import 'package:flutter/material.dart';
import 'package:mon_classe_manegment/widgets/student_card.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:clipboard/clipboard.dart';
import '../../models/student_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

class ClassManagementTab extends StatefulWidget {
  const ClassManagementTab({super.key});

  @override
  State<ClassManagementTab> createState() => _ClassManagementTabState();
}

class _ClassManagementTabState extends State<ClassManagementTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _parentEmailController = TextEditingController();

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un élève'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom de l\'élève',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le prénom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'élève',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _parentEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email du parent (optionnel)',
                  hintText: 'parent@exemple.com',
                  border: OutlineInputBorder(),
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
            onPressed: _addStudent,
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Provider.of<UserProvider>(context, listen: false).user;
    
    try {
      final studentId = DateTime.now().millisecondsSinceEpoch.toString();
      final student = Student(
        id: studentId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        classId: user!.classId!,
        createdAt: DateTime.now(),
      );

      await _firestoreService.addStudent(student);

      // Envoyer une invitation au parent si l'email est fourni
      if (_parentEmailController.text.trim().isNotEmpty) {
        await _sendParentInvitation(student, _parentEmailController.text.trim());
      }

      // Reset des champs
      _firstNameController.clear();
      _lastNameController.clear();
      _parentEmailController.clear();

      Navigator.pop(context);
      
      // Afficher le code élève après l'ajout
      _showStudentCode(studentId, '${student.firstName} ${student.lastName}');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _showStudentCode(String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Élève ajouté avec succès'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$studentName a été ajouté à la classe.'),
            const SizedBox(height: 16),
            const Text(
              'Code élève à donner aux parents :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Text(
                    studentId,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.content_copy, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Cliquez pour copier',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les parents utiliseront ce code pour s\'inscrire',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              FlutterClipboard.copy(studentId).then((value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copié dans le presse-papier')),
                );
                Navigator.pop(context);
              });
            },
            child: const Text('Copier le code'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendParentInvitation(Student student, String parentEmail) async {
    // Ici vous pouvez implémenter l'envoi d'email d'invitation
    print('Invitation envoyée à $parentEmail pour ${student.fullName}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invitation envoyée à $parentEmail')),
    );
  }

  Future<void> _deleteStudent(String studentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet élève ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .delete();
            
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Élève supprimé')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showStudentInfo(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Informations de ${student.firstName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Prénom', student.firstName),
            _buildInfoRow('Nom', student.lastName),
            _buildInfoRow('Date d\'ajout', _formatDate(student.createdAt)),
            const SizedBox(height: 16),
            const Text(
              'Code élève :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                FlutterClipboard.copy(student.id).then((value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copié dans le presse-papier')),
                  );
                  Navigator.pop(context);
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  children: [
                    Text(
                      student.id,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Monospace',
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.content_copy, size: 14, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Cliquer pour copier',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              FlutterClipboard.copy(student.id).then((value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copié dans le presse-papier')),
                );
                Navigator.pop(context);
              });
            },
            child: const Text('Copier le code'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Liste des élèves',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showAddStudentDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Ajouter un élève'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Student>>(
            stream: _firestoreService.getStudents(user!.classId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              final students = snapshot.data ?? [];

              if (students.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucun élève dans la classe',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ajoutez votre premier élève en cliquant sur le bouton ci-dessus',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return StudentCard(
                    student: student,
                    onDelete: () => _deleteStudent(student.id),
                    onTap: () => _showStudentInfo(student),
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