import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import '../services/notification_center.dart';
import '../core/localization/app_localizations.dart';

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
    final t = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.get('resetSettingsDialogTitle')),
        content: Text(t.get('resetSettingsDialogBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.get('resetSettings')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _settings.resetToDefaults();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.get('settingsResetSuccess'))),
    );
  }

  Future<void> _showAbout() async {
    final t = AppLocalizations.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.agriculture),
            const SizedBox(width: 10),
            Expanded(child: Text(t.get('appName'))),
          ],
        ),
        content: Text(t.get('appAboutBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.get('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final t = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.get('logoutConfirmTitle')),
        content: Text(t.get('logoutConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.get('logout')),
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
    final t = AppLocalizations.of(context);

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
                    t.get('settings'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.get('settingsSubtitle'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  _section(
                    context: context,
                    title: t.get('appearance'),
                    icon: Icons.palette_outlined,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 480;

                          final segmented = SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: const Icon(Icons.light_mode, size: 18),
                                label: Text(t.get('light')),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: const Icon(Icons.dark_mode, size: 18),
                                label: Text(t.get('dark')),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: const Icon(Icons.settings_suggest, size: 18),
                                label: Text(t.get('auto')),
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
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.dark_mode_outlined),
                                    title: Text(t.get('theme')),
                                    subtitle: Text(t.get('themeSubtitle')),
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
                            title: Text(t.get('theme')),
                            subtitle: Text(t.get('themeSubtitle')),
                            trailing: segmented,
                          );
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.view_compact_outlined),
                        title: Text(t.get('compactMode')),
                        subtitle: Text(t.get('compactModeSubtitle')),
                        value: _settings.compactMode,
                        onChanged: _settings.setCompactMode,
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: t.get('notifications'),
                    icon: Icons.notifications_outlined,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.notifications_active_outlined),
                        title: Text(t.get('enableNotifications')),
                        subtitle: Text(t.get('enableNotificationsSubtitle')),
                        value: _settings.notificationsEnabled,
                        onChanged: _settings.setNotificationsEnabled,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_sweep_outlined),
                        title: Text(t.get('clearNotificationHistory')),
                        subtitle: Text(t.get('clearNotificationHistorySubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await NotificationCenter.instance.clearAll();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.get('notificationsCleared'))),
                          );
                        },
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: t.get('business'),
                    icon: Icons.storefront_outlined,
                    children: [
                      TextField(
                        controller: _businessNameController,
                        decoration: InputDecoration(
                          labelText: t.get('businessName'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: const OutlineInputBorder(),
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
                              decoration: InputDecoration(
                                labelText: t.get('language'),
                                border: const OutlineInputBorder(),
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
                              decoration: InputDecoration(
                                labelText: t.get('currency'),
                                border: const OutlineInputBorder(),
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
                        decoration: InputDecoration(
                          labelText: t.get('dateFormat'),
                          border: const OutlineInputBorder(),
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
                    title: t.get('backupRestore'),
                    icon: Icons.backup_outlined,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.backup),
                        title: Text(t.get('createBackup')),
                        subtitle: Text(t.get('createBackupSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: widget.onCreateBackup,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.restore),
                        title: Text(t.get('restoreBackup')),
                        subtitle: Text(t.get('restoreBackupSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: widget.onRestoreBackup,
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: t.get('account'),
                    icon: Icons.person_outline,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(t.get('currentRole')),
                        subtitle: Text(widget.role),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout),
                        title: Text(t.get('logout')),
                        subtitle: Text(t.get('signOutSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _logout,
                      ),
                    ],
                  ),

                  _section(
                    context: context,
                    title: t.get('application'),
                    icon: Icons.info_outline,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline),
                        title: Text(t.get('about')),
                        subtitle: Text(t.get('aboutSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showAbout,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.restart_alt),
                        title: Text(t.get('resetSettings')),
                        subtitle: Text(t.get('resetSettingsSubtitle')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _resetSettings,
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),
                  Center(
                    child: Text(
                      t.get('appVersionFooter'),
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