import 'package:flutter/material.dart';
import '../models/student_model.dart';

class StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const StudentCard({
    super.key,
    required this.student,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            student.firstName[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(student.fullName),
        subtitle: Text(
          'Ajouté le ${_formatDate(student.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: onTap, // Ajout du onTap
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}