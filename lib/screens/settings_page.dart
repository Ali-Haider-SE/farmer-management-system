import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import '../services/notification_center.dart';

class SettingsPage extends StatefulWidget {
  final String role;
  final Future<void> Function()? onCreateBackup;
  final Future<void> Function()? onRestoreBackup;
  final VoidCallback? onLogout;

  const SettingsPage({
    super.key,
    required this.role,
    this.onCreateBackup,
    this.onRestoreBackup,
    this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsController _settings = SettingsController.instance;

  static const _languages = ['English', 'Urdu'];
  static const _currencies = ['PKR', 'USD', 'INR'];
  static const _dateFormats = ['dd MMM yyyy', 'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'];

  late final TextEditingController _businessNameController;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController(text: _settings.businessName);
    _settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    if (_businessNameController.text != _settings.businessName) {
      _businessNameController.text = _settings.businessName;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Reset all preferences (theme, compact mode, notifications, '
          'language, currency, date format) to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _settings.resetToDefaults();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings reset successfully')),
    );
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.agriculture),
            SizedBox(width: 10),
            Expanded(child: Text('Farmer Management System')),
          ],
        ),
        content: const Text(
          'Farmer Management System\n\nVersion: 1.0.0\n\n'
          'Management for farms, parties, accounts, rice, wheat, stock, '
          'reports and business records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout from the current account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    widget.onLogout?.call();
  }

  Widget _section({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1B5E20)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 900 ? 30.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage application preferences and account options.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  _section(
                    context: context,
                    title: 'Appearance',
                    icon: Icons.palette_outlined,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 480;

                          final segmented = SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode, size: 18),
                                label: Text('Light'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode, size: 18),
                                label: Text('Dark'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.settings_suggest, size: 18),
                                label: Text('Auto'),
                              ),
                            ],
                            selected: {_settings.themeMode},
                            onSelectionChanged: (selection) {
                              _settings.setThemeMode(selection.first);
                            },
                          );

                          // A 3-segment button with icon+label is wide
                          // enough that it doesn't fit next to a ListTile's
                          // title/subtitle on a phone — stack it below
                          // instead of squeezing it into the trailing slot.
                          if (narrow) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.dark_mode_outlined),
                                    title: Text('Theme'),
                                    subtitle: Text(
                                      'Choose Light, Dark, or follow the system.',
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: segmented,
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.dark_mode_outlined),
                            title: const Text('Theme'),
                            subtitle: const Text(
                              'Choose Light, Dark, or follow the system.',
                            ),
                            trailing: segmented,
                          );
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.view_compact_outlined),
                        title: const Text('Compact Mode'),
                        subtitle: const Text(
                          'Tighter spacing and smaller controls across every screen.',
                        ),
                        value: _settings.compactMode,
                        onChanged: _settings.setCompactMode,
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: 'Notifications',
                    icon: Icons.notifications_outlined,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.notifications_active_outlined),
                        title: const Text('Enable Notifications'),
                        subtitle: const Text(
                          'Get alerts for low stock, khata dues, and other reminders.',
                        ),
                        value: _settings.notificationsEnabled,
                        onChanged: _settings.setNotificationsEnabled,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_sweep_outlined),
                        title: const Text('Clear Notification History'),
                        subtitle: const Text('Remove all read and unread notifications.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await NotificationCenter.instance.clearAll();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notifications cleared')),
                          );
                        },
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: 'Business',
                    icon: Icons.storefront_outlined,
                    children: [
                      TextField(
                        controller: _businessNameController,
                        decoration: const InputDecoration(
                          labelText: 'Business Name',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: _settings.setBusinessName,
                        onTapOutside: (_) =>
                            _settings.setBusinessName(_businessNameController.text),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _settings.language,
                              decoration: const InputDecoration(
                                labelText: 'Language',
                                border: OutlineInputBorder(),
                              ),
                              items: _languages
                                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) _settings.setLanguage(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _settings.currency,
                              decoration: const InputDecoration(
                                labelText: 'Currency',
                                border: OutlineInputBorder(),
                              ),
                              items: _currencies
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) _settings.setCurrency(value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _settings.dateFormat,
                        decoration: const InputDecoration(
                          labelText: 'Date Format',
                          border: OutlineInputBorder(),
                        ),
                        items: _dateFormats
                            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) _settings.setDateFormat(value);
                        },
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: 'Backup & Restore',
                    icon: Icons.backup_outlined,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.backup),
                        title: const Text('Create Backup'),
                        subtitle: const Text(
                          'Create a backup of your current application data.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: widget.onCreateBackup,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.restore),
                        title: const Text('Restore Backup'),
                        subtitle: const Text(
                          'Restore previously backed-up application data.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: widget.onRestoreBackup,
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: 'Account',
                    icon: Icons.person_outline,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Current Role'),
                        subtitle: Text(widget.role),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout),
                        title: const Text('Logout'),
                        subtitle: const Text(
                          'Sign out from the current account.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _logout,
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: 'Application',
                    icon: Icons.info_outline,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About'),
                        subtitle: const Text(
                          'View application information and version.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showAbout,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.restart_alt),
                        title: const Text('Reset Settings'),
                        subtitle: const Text(
                          'Restore application preferences to defaults.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _resetSettings,
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),
                  Center(
                    child: Text(
                      'Farmer Management System • Version 1.0.0',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
