import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SanctionType {
  remarqueOrale,       // Remarque orale
  observationEcrite,   // Observation écrite
  travailEducatif,     // Travail éducatif léger
  avertissement,       // Avertissement
  tacheAide,           // Tâche d’aide
  detention,           // Heure de retenue
  exclusion,           // Exclusion
  autre,               // Autre
}

enum SanctionSeverity {
  low,     // Faible
  medium,  // Moyenne
  high,    // Élevée
}

class Sanction {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String teacherId;
  final String teacherName;
  final SanctionType type;
  final SanctionSeverity severity;
  final String reason;
  final String? details;
  final DateTime date;
  final DateTime? endDate; // Pour les exclusions temporaires
  final bool isActive;
  final DateTime createdAt;

  Sanction({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.teacherId,
    required this.teacherName,
    required this.type,
    required this.severity,
    required this.reason,
    this.details,
    required this.date,
    this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'type': _sanctionTypeToString(type),
      'severity': _sanctionSeverityToString(severity),
      'reason': reason,
      'details': details,
      'date': date.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Sanction.fromMap(Map<String, dynamic> map) {
    return Sanction(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      classId: map['classId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      type: _stringToSanctionType(map['type'] ?? 'remarqueOrale'),
      severity: _stringToSanctionSeverity(map['severity'] ?? 'low'),
      reason: map['reason'] ?? '',
      details: map['details'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'])
          : null,
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  // Conversion enum ↔ string
  static String _sanctionTypeToString(SanctionType type) {
    switch (type) {
      case SanctionType.remarqueOrale:
        return 'remarqueOrale';
      case SanctionType.observationEcrite:
        return 'observationEcrite';
      case SanctionType.travailEducatif:
        return 'travailEducatif';
      case SanctionType.avertissement:
        return 'avertissement';
      case SanctionType.tacheAide:
        return 'tacheAide';
      case SanctionType.detention:
        return 'detention';
      case SanctionType.exclusion:
        return 'exclusion';
      case SanctionType.autre:
        return 'autre';
    }
  }

  static SanctionType _stringToSanctionType(String type) {
    switch (type) {
      case 'remarqueOrale':
        return SanctionType.remarqueOrale;
      case 'observationEcrite':
        return SanctionType.observationEcrite;
      case 'travailEducatif':
        return SanctionType.travailEducatif;
      case 'avertissement':
        return SanctionType.avertissement;
      case 'tacheAide':
        return SanctionType.tacheAide;
      case 'detention':
        return SanctionType.detention;
      case 'exclusion':
        return SanctionType.exclusion;
      case 'autre':
        return SanctionType.autre;
      default:
        return SanctionType.remarqueOrale;
    }
  }

  static String _sanctionSeverityToString(SanctionSeverity severity) {
    switch (severity) {
      case SanctionSeverity.low:
        return 'low';
      case SanctionSeverity.medium:
        return 'medium';
      case SanctionSeverity.high:
        return 'high';
    }
  }

  static SanctionSeverity _stringToSanctionSeverity(String severity) {
    switch (severity) {
      case 'low':
        return SanctionSeverity.low;
      case 'medium':
        return SanctionSeverity.medium;
      case 'high':
        return SanctionSeverity.high;
      default:
        return SanctionSeverity.low;
    }
  }

  // ✅ Affichage bilingue (Français / Arabe)
  String get typeDisplay {
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
        return 'Tâche d’aide — مهمة مساعدة';
      case SanctionType.detention:
        return 'Retenue — احتجاز / ساعة تأديب';
      case SanctionType.exclusion:
        return 'Exclusion — إيقاف / طرد';
      case SanctionType.autre:
        return 'Autre — أخرى';
    }
  }

  String get severityDisplay {
    switch (severity) {
      case SanctionSeverity.low:
        return 'Faible — منخفضة';
      case SanctionSeverity.medium:
        return 'Moyenne — متوسطة';
      case SanctionSeverity.high:
        return 'Élevée — عالية';
    }
  }

  Color get severityColor {
    switch (severity) {
      case SanctionSeverity.low:
        return Colors.orange;
      case SanctionSeverity.medium:
        return Colors.deepOrange;
      case SanctionSeverity.high:
        return Colors.red;
    }
  }

  bool get isValid {
    if (!isActive) return false;
    if (endDate != null && DateTime.now().isAfter(endDate!)) return false;
    return true;
  }
}
