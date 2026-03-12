import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _matchNotifications = true;
  bool _messageNotifications = true;
  bool _profileVisibility = true;
  bool _showOnlineStatus = false;
  String _language = 'English';
  String _theme = 'System';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              subtitle: 'Update your personal information',
              onTap: () {
                context.push('/edit-profile');
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: 'alex.johnson@stanford.edu',
              onTap: () {
                _showChangeEmailDialog();
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update your password',
              onTap: () {
                _showChangePasswordDialog();
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.workspace_premium,
              title: 'Premium Subscription',
              subtitle: 'Free Plan',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Upgrade',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () {
                context.push(AppRoutes.premium);
              },
            ),
          ]),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.notifications_outlined,
              title: 'Push Notifications',
              subtitle: 'Receive push notifications',
              value: _pushNotifications,
              onChanged: (value) {
                setState(() => _pushNotifications = value);
              },
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.email_outlined,
              title: 'Email Notifications',
              subtitle: 'Receive email updates',
              value: _emailNotifications,
              onChanged: (value) {
                setState(() => _emailNotifications = value);
              },
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.favorite_outline,
              title: 'Match Notifications',
              subtitle: 'Get notified when you match',
              value: _matchNotifications,
              onChanged: (value) {
                setState(() => _matchNotifications = value);
              },
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.chat_bubble_outline,
              title: 'Message Notifications',
              subtitle: 'Get notified of new messages',
              value: _messageNotifications,
              onChanged: (value) {
                setState(() => _messageNotifications = value);
              },
            ),
          ]),

          const SizedBox(height: 24),

          // Privacy Section
          _buildSectionHeader('Privacy'),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.visibility_outlined,
              title: 'Profile Visibility',
              subtitle: 'Show your profile to companies',
              value: _profileVisibility,
              onChanged: (value) {
                setState(() => _profileVisibility = value);
              },
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.circle,
              title: 'Show Online Status',
              subtitle: 'Let others see when you\'re active',
              value: _showOnlineStatus,
              onChanged: (value) {
                setState(() => _showOnlineStatus = value);
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.block,
              title: 'Blocked Companies',
              subtitle: 'Manage blocked accounts',
              onTap: () {
                _showBlockedCompanies();
              },
            ),
          ]),

          const SizedBox(height: 24),

          // Preferences Section
          _buildSectionHeader('Preferences'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: _language,
              onTap: () {
                _showLanguageDialog();
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'Theme',
              subtitle: _theme,
              onTap: () {
                _showThemeDialog();
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.location_on_outlined,
              title: 'Location Preferences',
              subtitle: 'Set your preferred work locations',
              onTap: () {
                _showLocationPreferences();
              },
            ),
          ]),

          const SizedBox(height: 24),

          // Support Section
          _buildSectionHeader('Support & About'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Get help and support',
              onTap: () {
                // TODO: Open help center
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Read our terms and conditions',
              onTap: () {
                // TODO: Open terms
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Learn how we protect your data',
              onTap: () {
                // TODO: Open privacy policy
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Version 1.0.0',
              onTap: () {
                _showAboutDialog();
              },
            ),
          ]),

          const SizedBox(height: 24),

          // Danger Zone
          _buildSectionHeader('Danger Zone'),
          _buildSettingsCard([
            _buildSettingsTile(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              titleColor: AppColors.error,
              onTap: () {
                _handleLogout();
              },
            ),
            const Divider(height: 1),
            _buildSettingsTile(
              icon: Icons.delete_forever,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              titleColor: AppColors.error,
              onTap: () {
                _handleDeleteAccount();
              },
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title,
        style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (titleColor ?? AppColors.primaryPurple).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: titleColor ?? AppColors.primaryPurple,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
          ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: AppColors.primaryPurple,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryPurple,
      ),
    );
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'New Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = ['English', 'Español', 'Français', 'Deutsch', '中文'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            return RadioListTile<String>(
              title: Text(lang),
              value: lang,
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showThemeDialog() {
    final themes = ['Light', 'Dark', 'System'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themes.map((theme) {
            return RadioListTile<String>(
              title: Text(theme),
              value: theme,
              groupValue: _theme,
              onChanged: (value) {
                setState(() => _theme = value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLocationPreferences() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Preferences'),
        content: const Text(
          'Set your preferred work locations to get better job matches.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBlockedCompanies() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blocked Companies'),
        content: const Text('You haven\'t blocked any companies yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'JobMatch',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppColors.purpleGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.work_outline,
          color: Colors.white,
          size: 30,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        Text(
          'JobMatch helps students and recent graduates connect with their dream opportunities through an intuitive swipe-based interface.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text(
          '© 2024 JobMatch. All rights reserved.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              authProvider.logout();
              Navigator.pop(context);
              context.go(AppRoutes.welcome);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your password to confirm account deletion:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(AppRoutes.welcome);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }
}