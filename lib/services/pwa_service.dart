// services/pwa_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PwaService {
  static const String _pwaInstallDismissedKey = 'pwa_install_dismissed';
  static const String _pwaInstallPostponedKey = 'pwa_install_postponed';

  // Vérifier si c'est une PWA installable
  static bool get isInstallable {
    return kIsWeb;
  }

  // Vérifier si déjà installé en PWA (méthode simplifiée)
  static bool get isInstalled {
    if (!kIsWeb) return false;
    
    // Méthode alternative pour détecter PWA
    return _isRunningInStandaloneMode();
  }

  static bool _isRunningInStandaloneMode() {
    if (!kIsWeb) return false;
    
    try {
      // Vérifier via des indicateurs simples
      final isStandalone = _checkPwaIndicators();
      return isStandalone;
    } catch (e) {
      print('❌ Erreur détection PWA: $e');
      return false;
    }
  }

  static bool _checkPwaIndicators() {
    bool isStandalone = false;
    
    if (kIsWeb) {
      try {
        // Vérifier la taille de la fenêtre (approximation)
        final window = WidgetsBinding.instance.window;
        final isFullScreen = window.physicalSize.width >= 1024 && 
                            window.physicalSize.height >= 768;
        
        // Autres indicateurs possibles
        final hasNavigationBar = window.viewInsets.bottom > 0;
        
        isStandalone = isFullScreen || hasNavigationBar;
      } catch (e) {
        print('❌ Erreur vérification indicateurs PWA: $e');
      }
    }
    
    return isStandalone;
  }

  // Vérifier si le dialog a été déjà rejeté
  static Future<bool> get isInstallDismissed async {
    if (!isInstallable) return true;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pwaInstallDismissedKey) ?? false;
  }

  // Vérifier si l'installation a été reportée
  static Future<bool> get isInstallPostponed async {
    if (!isInstallable) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final postponedTime = prefs.getInt(_pwaInstallPostponedKey) ?? 0;
    
    if (postponedTime == 0) return false;
    
    // Vérifier si 24h se sont écoulées
    final now = DateTime.now().millisecondsSinceEpoch;
    final twentyFourHours = 24 * 60 * 60 * 1000;
    
    return (now - postponedTime) < twentyFourHours;
  }

  // Marquer le dialog comme rejeté
  static Future<void> dismissInstall() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pwaInstallDismissedKey, true);
  }

  // Reporter l'installation (24h)
  static Future<void> postponeInstall() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pwaInstallPostponedKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Réinitialiser les préférences (pour le debug)
  static Future<void> resetInstallPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pwaInstallDismissedKey);
    await prefs.remove(_pwaInstallPostponedKey);
  }

  // Vérifier si on doit afficher le dialog
  static Future<bool> get shouldShowInstallPrompt async {
    if (!isInstallable) return false;
    if (isInstalled) return false;
    if (await isInstallDismissed) return false;
    if (await isInstallPostponed) return false;
    
    return true;
  }

  // Vérifier les conditions d'affichage améliorées
  static Future<bool> shouldShowPromptWithConditions({
    int minSessionCount = 2,
    Duration minSessionDuration = const Duration(minutes: 5),
  }) async {
    if (!isInstallable) return false;
    if (isInstalled) return false;
    if (await isInstallDismissed) return false;
    if (await isInstallPostponed) return false;

    // Vérifications supplémentaires
    final prefs = await SharedPreferences.getInstance();
    final sessionCount = prefs.getInt('session_count') ?? 0;
    final firstVisit = prefs.getInt('first_visit_timestamp') ?? 0;

    // Si première visite ou pas assez de sessions
    if (sessionCount < minSessionCount) return false;

    // Si pas assez de temps passé sur l'app
    if (firstVisit > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeSinceFirstVisit = now - firstVisit;
      if (timeSinceFirstVisit < minSessionDuration.inMilliseconds) {
        return false;
      }
    }

    return true;
  }

  // Méthode pour tracker les sessions utilisateur
  static Future<void> trackUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Incrémenter le compteur de sessions
    final sessionCount = (prefs.getInt('session_count') ?? 0) + 1;
    await prefs.setInt('session_count', sessionCount);
    
    // Enregistrer la première visite
    if (prefs.getInt('first_visit_timestamp') == null) {
      await prefs.setInt('first_visit_timestamp', DateTime.now().millisecondsSinceEpoch);
    }
    
    // Dernière visite
    await prefs.setInt('last_visit_timestamp', DateTime.now().millisecondsSinceEpoch);
  }
}