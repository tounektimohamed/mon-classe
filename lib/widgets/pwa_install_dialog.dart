// widgets/pwa_install_dialog.dart - CORRECTION DES INSTRUCTIONS
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
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _handleInstall() async {
    _showInstallInstructions();
    widget.onInstall?.call();
  }

  void _handlePostpone() async {
    await PwaService.postponeInstall();
    if (mounted) Navigator.of(context).pop();
    widget.onDismiss?.call();
  }

  void _handleDismiss() async {
    await PwaService.dismissInstall();
    if (mounted) Navigator.of(context).pop();
    widget.onDismiss?.call();
  }

  void _showInstallInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ResponsiveInstallInstructions(
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;
    final isLargeScreen = mediaQuery.size.width > 900;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: isSmallScreen ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLargeScreen ? 500 : double.infinity,
          maxHeight: mediaQuery.size.height * 0.8,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
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
              _buildHeader(isSmallScreen),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  child: Column(
                    children: [
                      _buildFeaturesSection(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      _buildActionButtons(isSmallScreen),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isSmallScreen ? 16 : 20),
          topRight: Radius.circular(isSmallScreen ? 16 : 20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
            child: Icon(
              Icons.install_desktop,
              size: isSmallScreen ? 32 : 40,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Text(
            'Installer l\'application',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 8),
          Text(
            'Pour une meilleure expérience',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(bool isSmallScreen) {
    final features = [
      _FeatureData(
        Icons.rocket_launch,
        'Lancement rapide',
        'Démarrage instantané depuis l\'écran d\'accueil',
      ),
      _FeatureData(
        Icons.offline_bolt,
        'Mode hors ligne',
        'Fonctionne même sans connexion internet',
      ),
      _FeatureData(
        Icons.notifications_active,
        'Notifications push',
        'Recevez des alertes en temps réel',
      ),
      _FeatureData(
        Icons.security,
        'Sécurisé',
        'Données protégées et mise à jour automatique',
      ),
    ];

    return Column(
      children: features.map((feature) => _buildFeature(feature, isSmallScreen)).toList(),
    );
  }

  Widget _buildFeature(_FeatureData feature, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            feature.icon,
            size: isSmallScreen ? 20 : 24,
            color: Colors.blue,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
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

  Widget _buildActionButtons(bool isSmallScreen) {
    return Column(
      children: [
        if (isSmallScreen)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FutureBuilder(
                  future: _installFuture,
                  builder: (context, snapshot) {
                    return ElevatedButton(
                      onPressed: _handleInstall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Voir comment installer',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handlePostpone,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 14 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Plus tard'),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _handlePostpone,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 14 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Plus tard'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FutureBuilder(
                  future: _installFuture,
                  builder: (context, snapshot) {
                    return ElevatedButton(
                      onPressed: _handleInstall,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Voir comment installer',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        TextButton(
          onPressed: _handleDismiss,
          child: Text(
            'Ne plus afficher',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

class ResponsiveInstallInstructions extends StatelessWidget {
  final VoidCallback onClose;

  const ResponsiveInstallInstructions({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    return Container(
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
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.install_desktop,
                    color: Colors.blue,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: Text(
                      'Comment installer l\'application',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: isSmallScreen ? 16 : 20),
              
              // 🔥 INSTRUCTIONS CORRIGÉES ET AMÉLIORÉES
              _buildBrowserSpecificInstructions(isSmallScreen),
              
              SizedBox(height: isSmallScreen ? 16 : 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 14 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'J\'ai compris',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrowserSpecificInstructions(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Méthodes d\'installation selon votre navigateur:',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        SizedBox(height: isSmallScreen ? 12 : 16),
        
        // Chrome / Edge
        _buildBrowserSection(
          'Chrome / Edge (Android/Desktop)',
          [
            '1. Cherchez l\'icône 📥 "Télécharger" dans la barre d\'adresse',
            '2. Ou allez dans le menu ⋯ → "Installer l\'application"',
            '3. Cliquez sur "Installer" pour confirmer',
          ],
          isSmallScreen,
        ),
        
        SizedBox(height: isSmallScreen ? 12 : 16),
        
        // Safari (iOS)
        _buildBrowserSection(
          'Safari (iPhone/iPad)',
          [
            '1. Cliquez sur l\'icône 📤 "Partager" en bas de l\'écran',
            '2. Faites défiler et sélectionnez "Sur l\'écran d\'accueil"',
            '3. Cliquez sur "Ajouter" pour confirmer',
          ],
          isSmallScreen,
        ),
        
        SizedBox(height: isSmallScreen ? 12 : 16),
        
        // Firefox
        _buildBrowserSection(
          'Firefox (Android)',
          [
            '1. Allez dans le menu ⋯ en haut à droite',
            '2. Sélectionnez "Installer" ou "Ajouter à l\'écran d\'accueil"',
            '3. Confirmez l\'installation',
          ],
          isSmallScreen,
        ),
        
        SizedBox(height: isSmallScreen ? 12 : 16),
        
        // Instructions générales
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Text(
                    'Astuce',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'L\'icône d\'installation peut apparaître à différents endroits selon votre navigateur et appareil. '
                'Cherchez les icônes comme 📥, 📤, ⋯ ou "Installer".',
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 13,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrowserSection(String browserName, List<String> steps, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            browserName,
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 15,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 6),
          ...steps.map((step) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              step,
              style: TextStyle(
                fontSize: isSmallScreen ? 11 : 13,
                color: Colors.blue.shade700,
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureData(this.icon, this.title, this.description);
}