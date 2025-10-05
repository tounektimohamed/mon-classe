import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StudentSanctionBadge extends StatefulWidget {
  final String studentId;
  final double size;

  const StudentSanctionBadge({
    super.key,
    required this.studentId,
    this.size = 16.0,
  });

  @override
  State<StudentSanctionBadge> createState() => _StudentSanctionBadgeState();
}

class _StudentSanctionBadgeState extends State<StudentSanctionBadge> {
  int _activeSanctionsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSanctionsCount();
  }

  Future<void> _loadSanctionsCount() async {
    final count = await FirestoreService().getStudentActiveSanctionsCount(widget.studentId);
    if (mounted) {
      setState(() {
        _activeSanctionsCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSanctionsCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(widget.size / 2),
      ),
      child: Center(
        child: Text(
          _activeSanctionsCount > 9 ? '9+' : _activeSanctionsCount.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}