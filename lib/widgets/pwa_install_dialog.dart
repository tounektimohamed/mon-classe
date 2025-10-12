// widgets/pwa_install_dialog.dart
import 'package:flutter/material.dart';
import 'package:Joussour/services/pwa_service.dart';

class PwaInstallDialog extends StatefulWidget {
  final VoidCallback? onInstall;
  final VoidCallback? onDismiss;

  const PwaInstallDialog({
    super.key,
    this.onInstall,
    this.onDismiss,
  });

  @override
  State<PwaInstallDialog> createState() => _PwaInstallDialogState();
}

class _PwaInstallDialogState extends State<PwaInstallDialog> {
  late Future<void> _installFuture;

  @override
  void initState() {
    super.initState();
    _installFuture = _triggerInstall();
  }

  Future<void> _triggerInstall() async {
    // Attendre un peu pour que l'animation se termine
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _handleInstall() async {
    // Logique d'installation PWA
    _showInstallInstructions();
    
    if (widget.onInstall != null) {
      widget.onInstall!();
    }
  }

  void _handlePostpone() async {
    await PwaService.postponeInstall();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  void _handleDismiss() async {
    await PwaService.dismissInstall();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  void _showInstallInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête
                Row(
                  children: [
                    const Icon(Icons.install_desktop, 
                      color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Installer l\'application',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Instructions selon le navigateur
                _buildInstructionsForBrowser(),
                
                const SizedBox(height: 24),
                
                // Bouton compris
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'J\'ai compris',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsForBrowser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pour installer l\'application:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Instructions génériques
        _buildInstructionStep(
          '1. Cliquez sur le menu (⋯) en haut à droite',
          Icons.more_vert,
        ),
        
        _buildInstructionStep(
          '2. Sélectionnez "Installer l\'application"',
          Icons.add_to_home_screen,
        ),
        
        _buildInstructionStep(
          '3. Confirmez l\'installation',
          Icons.check_circle,
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'L\'application sera ajoutée à votre écran d\'accueil '
            'et fonctionnera comme une application native.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête avec image
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Icône
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.install_desktop,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Titre
                  const Text(
                    'Installer l\'application',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Sous-titre
                  const Text(
                    'Pour une meilleure expérience',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Contenu
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avantages
                  _buildFeature(
                    Icons.rocket_launch,
                    'Lancement rapide',
                    'Démarrage instantané depuis l\'écran d\'accueil',
                  ),
                  
                  _buildFeature(
                    Icons.offline_bolt,
                    'Mode hors ligne',
                    'Fonctionne même sans connexion internet',
                  ),
                  
                  _buildFeature(
                    Icons.notifications_active,
                    'Notifications push',
                    'Recevez des alertes en temps réel',
                  ),
                  
                  _buildFeature(
                    Icons.security,
                    'Sécurisé',
                    'Données protégées et mise à jour automatique',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Boutons d'action
                  Row(
                    children: [
                      // Reporter
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handlePostpone,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('Plus tard'),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Installer
                      Expanded(
                        child: FutureBuilder(
                          future: _installFuture,
                          builder: (context, snapshot) {
                            return ElevatedButton(
                              onPressed: _handleInstall,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Installer',
                                style: TextStyle(fontSize: 16),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Ne plus afficher
                  TextButton(
                    onPressed: _handleDismiss,
                    child: const Text(
                      'Ne plus afficher',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
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