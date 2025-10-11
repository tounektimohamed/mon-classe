import 'package:flutter/material.dart';
import 'package:Joussour/services/fcm_service.dart';

class NotificationPermissionScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onCompleted;

  const NotificationPermissionScreen({
    super.key,
    required this.userId,
    required this.onCompleted,
  });

  @override
  State<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends State<NotificationPermissionScreen> {
  bool _isLoading = false;
  String _status = '';

  Future<void> _enableNotifications() async {
    setState(() {
      _isLoading = true;
      _status = 'Demande des permissions...';
    });

    try {
      // Réinitialiser FCM pour forcer la demande de permission
      await FCMService.initialize();
      
      setState(() {
        _status = 'Génération du token...';
      });

      // Attendre un peu pour la génération
      await Future.delayed(const Duration(seconds: 2));

      // Sauvegarder le token
      await FCMService.saveUserFCMToken(widget.userId);
      
      setState(() {
        _status = '✅ Notifications activées avec succès!';
      });

      await Future.delayed(const Duration(seconds: 1));
      
      widget.onCompleted();
      
    } catch (e) {
      setState(() {
        _status = '❌ Erreur: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_active,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Activer les notifications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Pour recevoir des notifications instantanées quand vous recevez de nouveaux messages',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sans cette activation, vous ne serez pas averti des nouveaux messages',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 32),
              
              if (_status.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _status.contains('✅') ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _status.contains('✅') ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              ElevatedButton(
                onPressed: _isLoading ? null : _enableNotifications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Activer les notifications',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: _isLoading ? null : widget.onCompleted,
                child: const Text(
                  'Configurer plus tard',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}