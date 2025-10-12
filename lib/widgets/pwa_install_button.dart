// widgets/pwa_install_button.dart
import 'package:flutter/material.dart';
import 'package:Joussour/services/pwa_service.dart';
import 'package:Joussour/widgets/pwa_install_dialog.dart';

class PwaInstallButton extends StatefulWidget {
  final bool showAsFloatingButton;
  final Color? backgroundColor;
  final Color? textColor;

  const PwaInstallButton({
    super.key,
    this.showAsFloatingButton = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<PwaInstallButton> createState() => _PwaInstallButtonState();
}

class _PwaInstallButtonState extends State<PwaInstallButton> {
  bool _isVisible = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkPwaStatus();
  }

  Future<void> _checkPwaStatus() async {
    if (_isChecking) return;
    
    setState(() {
      _isChecking = true;
    });

    try {
      final shouldShow = await PwaService.shouldShowInstallPrompt;
      if (mounted) {
        setState(() {
          _isVisible = shouldShow;
          _isChecking = false;
        });
      }
    } catch (e) {
      print('❌ Erreur vérification PWA: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _showInstallDialog() {
    showDialog(
      context: context,
      builder: (context) => PwaInstallDialog(
        onInstall: () {
          print('✅ Installation PWA confirmée');
          setState(() {
            _isVisible = false;
          });
        },
        onDismiss: () {
          print('📅 Installation PWA reportée');
          setState(() {
            _isVisible = false;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _isChecking) {
      return const SizedBox.shrink();
    }

    if (widget.showAsFloatingButton) {
      return _buildFloatingButton();
    } else {
      return _buildListTile();
    }
  }

  Widget _buildFloatingButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: FloatingActionButton.extended(
        onPressed: _showInstallDialog,
        icon: const Icon(Icons.install_desktop, size: 20),
        label: const Text(
          'Installer l\'app',
          style: TextStyle(fontSize: 14),
        ),
        backgroundColor: widget.backgroundColor ?? Colors.blue,
        foregroundColor: widget.textColor ?? Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }

  Widget _buildListTile() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.install_desktop,
            color: Colors.blue,
            size: 24,
          ),
        ),
        title: const Text(
          'Installer l\'application',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: const Text(
          'Pour une meilleure expérience',
          style: TextStyle(fontSize: 14),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: _showInstallDialog,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}