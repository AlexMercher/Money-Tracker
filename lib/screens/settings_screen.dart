import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/hive_service.dart';
import '../utils/page_transitions.dart';
import 'pdf_manager_screen.dart';
import 'month_history_screen.dart';
import 'manage_categories_screen.dart';
import 'package:flutter/foundation.dart';


/// Screen for app settings and preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _authEnabled = false;
  bool _requireInitialAuth = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await AuthService.isAuthEnabled();
    final requireInitial = await AuthService.requiresInitialAuth();
    setState(() {
      _authEnabled = enabled;
      _requireInitialAuth = requireInitial;
      _isLoading = false;
    });
  }

  Future<void> _toggleAuth(bool value) async {
    if (value) {
      // Enabling authentication
      // Check what authentication methods are available
      final isBiometricAvailable = await AuthService.isBiometricAvailable();
      final hasAnyAuth = await AuthService.hasAnyAuthMethod();
      final availableBiometrics = await AuthService.getAvailableBiometrics();
      
      print('Auth Debug: isBiometricAvailable=$isBiometricAvailable, hasAnyAuth=$hasAnyAuth, availableBiometrics=$availableBiometrics');
      
      if (!hasAnyAuth && !isBiometricAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No authentication method available. Please set up a screen lock (PIN, pattern, password, or fingerprint) in your device security settings first.'),
              duration: const Duration(seconds: 6),
              backgroundColor: Theme.of(context).colorScheme.error,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
        return;
      }
      
      // Show information about what will happen
      final authMethod = availableBiometrics.isNotEmpty 
          ? 'fingerprint/biometric' 
          : 'device PIN/password';
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Authentication'),
          content: Text(
            'You will be asked to authenticate using your $authMethod. This will be required every time you open the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) {
        return;
      }
      
      // Test authentication before enabling
      try {
        final authenticated = await AuthService.authenticate();
        
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Authentication was cancelled or failed. Authentication was not enabled.'),
                duration: const Duration(seconds: 4),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during authentication: ${e.toString()}'),
              duration: const Duration(seconds: 5),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
    } else {
      // Disabling authentication - require authentication first
      final authenticated = await AuthService.authenticate();
      
      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required to disable security.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        // Revert the switch
        setState(() {
          _authEnabled = true;
        });
        return;
      }
    }
    
    await AuthService.setAuthEnabled(value);
    setState(() {
      _authEnabled = value;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value 
              ? 'Authentication enabled successfully! App will require unlock on startup.' 
              : 'Authentication disabled.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showClearDataDialog() async {
    // Require authentication
    final authenticated = await AuthService.authenticate();
    if (!authenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication required to clear data.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all friends and transactions. This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Haptic feedback for destructive action - must await to ensure execution
      await HapticFeedback.mediumImpact();
      
      await HiveService.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been cleared'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Security Section
                _buildSectionHeader('Security'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Require Authentication'),
                        subtitle: const Text('Lock app with fingerprint or PIN'),
                        value: _authEnabled,
                        onChanged: _toggleAuth,
                        secondary: const Icon(Icons.lock_outline),
                      ),
                      
                      if (_authEnabled) ...[
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Lock on App Open'),
                          subtitle: const Text('Require authentication when opening the app'),
                          value: _requireInitialAuth,
                          onChanged: (value) async {
                            await AuthService.setRequireInitialAuth(value);
                            setState(() {
                              _requireInitialAuth = value;
                            });
                          },
                          secondary: const Icon(Icons.lock_clock),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),

                // History Section
                _buildSectionHeader('History'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Month History'),
                    subtitle: const Text('View past budget history'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final auth = await AuthService.authenticate(
                        localizedReason: 'Authenticate to view Month History',
                      );
                      if (auth && mounted) {
                        Navigator.push(
                          context,
                          PageTransitions.fadeSlide(const MonthHistoryScreen()),
                        );
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Data Section
                _buildSectionHeader('Data Management'),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.category_outlined),
                        title: const Text('Category Management'),
                        subtitle: const Text('Rename or merge expense categories'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final auth = await AuthService.authenticate(
                            localizedReason: 'Authenticate to manage categories',
                          );
                          if (auth && mounted) {
                            Navigator.push(
                              context,
                              PageTransitions.fadeSlide(const ManageCategoriesScreen()),
                            );
                          }
                        },
                      ),
                      
                      const Divider(height: 1),
                      
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf),
                        title: const Text('PDF Reports'),
                        subtitle: const Text('View and manage exported PDFs'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            PageTransitions.fadeSlide(const PdfManagerScreen()),
                          );
                        },
                      ),
                      
                      const Divider(height: 1),
                      
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About'),
                        subtitle: const Text('Version 1.0.0'),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'MoneyTrack',
                            applicationVersion: '1.0.0',
                            applicationIcon: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            children: [
                              const Text(
                                'An offline-first money tracking app for tracking who owes whom money.',
                              ),
                            ],
                          );
                        },
                      ),
                      
                      const Divider(height: 1),
                      


                      ListTile(
                        leading: Icon(
                          Icons.delete_forever,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Clear All Data',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        subtitle: const Text('Delete all friends and transactions'),
                        onTap: _showClearDataDialog,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
