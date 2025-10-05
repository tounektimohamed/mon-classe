import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/sanction_model.dart';
import '../../models/student_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

class AddSanctionDialog extends StatefulWidget {
  final String classId;

  const AddSanctionDialog({super.key, required this.classId});

  @override
  State<AddSanctionDialog> createState() => _AddSanctionDialogState();
}

class _AddSanctionDialogState extends State<AddSanctionDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  Student? _selectedStudent;
  SanctionType _selectedType = SanctionType.remarqueOrale;
  SanctionSeverity _selectedSeverity = SanctionSeverity.low;
  final _reasonController = TextEditingController();
  final _detailsController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;

  List<Student> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await _firestoreService
          .getStudents(widget.classId)
          .first;
      setState(() {
        _students = students;
      });
    } catch (e) {
      print('❌ Erreur chargement élèves: $e');
    }
  }

  Future<void> _submitSanction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un élève')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<UserProvider>(context, listen: false).user!;

      final sanction = Sanction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentId: _selectedStudent!.id,
        studentName: _selectedStudent!.fullName,
        classId: widget.classId,
        teacherId: user.uid,
        teacherName: '${user.firstName} ${user.lastName}',
        type: _selectedType,
        severity: _selectedSeverity,
        reason: _reasonController.text.trim(),
        details: _detailsController.text.trim().isNotEmpty
            ? _detailsController.text.trim()
            : null,
        date: _selectedDate,
        endDate: _endDate,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _firestoreService.addSanction(sanction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sanction ajoutée avec succès'),
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

  Future<void> _selectDate(BuildContext context, bool isEndDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isEndDate ? (_endDate ?? DateTime.now()) : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isEndDate) {
          _endDate = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 500,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  const Icon(Icons.gavel, color: Colors.blue, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Nouvelle Sanction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contenu avec scroll
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sélection de l'élève
                        _buildStudentDropdown(),
                        const SizedBox(height: 16),

                        // Type de sanction
                        _buildTypeDropdown(),
                        const SizedBox(height: 16),

                        // Sévérité
                        _buildSeverityDropdown(),
                        const SizedBox(height: 16),

                        // Dates
                        _buildDateSection(),
                        const SizedBox(height: 16),

                        // Raison
                        _buildReasonField(),
                        const SizedBox(height: 16),

                        // Détails supplémentaires
                        _buildDetailsField(),
                      ],
                    ),
                  ),
                ),
              ),

              // Actions
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Élève *',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<Student>(
          value: _selectedStudent,
          isExpanded: true,
          items: _students.map((student) {
            return DropdownMenuItem(
              value: student,
              child: Text(
                student.fullName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (student) {
            setState(() {
              _selectedStudent = student;
            });
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
          style: const TextStyle(fontSize: 14),
          validator: (value) {
            if (value == null) return 'Veuillez sélectionner un élève';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de sanction *',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<SanctionType>(
          value: _selectedType,
          isExpanded: true,
          items: SanctionType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(
                _getTypeDisplay(type),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (type) {
            setState(() {
              _selectedType = type!;
              _adjustSeverityByType(type);
            });
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSeverityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sévérité *',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<SanctionSeverity>(
          value: _selectedSeverity,
          isExpanded: true,
          items: SanctionSeverity.values.map((severity) {
            return DropdownMenuItem(
              value: severity,
              child: Text(
                _getSeverityDisplay(severity),
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (severity) {
            setState(() {
              _selectedSeverity = severity!;
            });
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dates',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        // Date de la sanction
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date de la sanction',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _selectDate(context, false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        
        // Date de fin pour les exclusions
        if (_selectedType == SanctionType.exclusion) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, size: 18, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date de fin (optionnel)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _endDate != null ? _formatDate(_endDate!) : 'Non définie',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _endDate != null ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _selectDate(context, true),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Raison *',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _reasonController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Description de la sanction...',
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
          style: const TextStyle(fontSize: 14),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez saisir une raison';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDetailsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Détails supplémentaires',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _detailsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Informations complémentaires...',
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 300;
        
        if (isCompact) {
          // Mode compact - boutons empilés
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitSanction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ajouter la sanction'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          );
        } else {
          // Mode normal - boutons côte à côte
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitSanction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Ajouter'),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  void _adjustSeverityByType(SanctionType type) {
    switch (type) {
      case SanctionType.remarqueOrale:
      case SanctionType.observationEcrite:
      case SanctionType.travailEducatif:
      case SanctionType.tacheAide:
        _selectedSeverity = SanctionSeverity.low;
        break;
      case SanctionType.avertissement:
      case SanctionType.detention:
        _selectedSeverity = SanctionSeverity.medium;
        break;
      case SanctionType.exclusion:
      case SanctionType.autre:
        _selectedSeverity = SanctionSeverity.high;
        break;
    }
  }

  String _getTypeDisplay(SanctionType type) {
    switch (type) {
      case SanctionType.remarqueOrale:
        return 'Remarque orale — ملاحظة شفهية';
      case SanctionType.observationEcrite:
        return 'Observation écrite — ملاحظة كتابية';
      case SanctionType.travailEducatif:
        return 'Travail éducatif léger — عمل تربوي بسيط';
      case SanctionType.avertissement:
        return 'Avertissement — إنذار';
      case SanctionType.tacheAide:
        return 'Tâche d\'aide — مهمة مساعدة';
      case SanctionType.detention:
        return 'Retenue — احتجاز / ساعة تأديب';
      case SanctionType.exclusion:
        return 'Exclusion — إيقاف / طرد';
      case SanctionType.autre:
        return 'Autre — أخرى';
    }
  }

  String _getSeverityDisplay(SanctionSeverity severity) {
    switch (severity) {
      case SanctionSeverity.low:
        return 'Faible';
      case SanctionSeverity.medium:
        return 'Moyenne';
      case SanctionSeverity.high:
        return 'Élevée';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _detailsController.dispose();
    super.dispose();
  }
}