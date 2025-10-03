import 'package:flutter/material.dart';

class AppColors {
  // Couleurs primaires (bleu éducatif)
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);
  
  // Palette de couleurs pour Material Color
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF1976D2,
    <int, Color>{
      50: Color(0xFFE3F2FD),
      100: Color(0xFFBBDEFB),
      200: Color(0xFF90CAF9),
      300: Color(0xFF64B5F6),
      400: Color(0xFF42A5F5),
      500: Color(0xFF2196F3),
      600: Color(0xFF1E88E5),
      700: Color(0xFF1976D2),
      800: Color(0xFF1565C0),
      900: Color(0xFF0D47A1),
    },
  );
  
  // Couleurs pour enseignants (bleu professionnel)
  static const Color teacherPrimary = Color(0xFF1565C0);
  
  // Couleurs pour parents (vert accueillant)
  static const Color parentPrimary = Color(0xFF2E7D32);
  
  // Couleurs de statut
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Couleurs de texte
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Colors.white;
  
  // Couleurs d'arrière-plan et surface
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  
  // Couleurs supplémentaires
  static const Color outline = Color(0xFFE0E0E0);
  
  // Couleurs spécifiques à l'application
  static const Color announcementColor = Color(0xFFFFF9C4);
  static const Color messageColor = Color(0xFFE3F2FD);
  static const Color studentColor = Color(0xFFE8F5E8);
  static const Color urgentColor = Color(0xFFFFEBEE);
  
  // Couleurs de matière (pour différencier les sujets)
  static const Color mathColor = Color(0xFFEF5350);
  static const Color frenchColor = Color(0xFF42A5F5);
  static const Color scienceColor = Color(0xFF66BB6A);
  static const Color historyColor = Color(0xFFFFA726);
  static const Color artColor = Color(0xFFAB47BC);
  static const Color sportColor = Color(0xFF26C6DA);
  
  // Méthodes utilitaires
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'completed':
      case 'present':
        return success;
      case 'warning':
      case 'pending':
      case 'late':
        return warning;
      case 'error':
      case 'absent':
      case 'cancelled':
        return error;
      case 'info':
      case 'in_progress':
      default:
        return info;
    }
  }
  
  static Color getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathématiques':
      case 'maths':
      case 'math':
        return mathColor;
      case 'français':
      case 'french':
        return frenchColor;
      case 'sciences':
      case 'science':
        return scienceColor;
      case 'histoire':
      case 'history':
        return historyColor;
      case 'arts':
      case 'art':
        return artColor;
      case 'sport':
      case 'pe':
        return sportColor;
      default:
        return primary;
    }
  }
}