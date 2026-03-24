import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final authApi = ref.read(authApiProvider);
      await authApi.updateProfile({'displayName': _nameController.text.trim()});
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: const Text('Save'),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: user?.photoUrl != null
                      ? NetworkImage(user!.photoUrl!)
                      : null,
                  child: user?.photoUrl == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                const SizedBox(height: 8),
                if (_isEditing)
                  TextButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Change Photo'),
                    onPressed: () {},
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Name field
          TextFormField(
            controller: _nameController,
            enabled: _isEditing,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          // Email (read-only)
          TextFormField(
            initialValue: user?.email ?? '',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          // Email verified status
          if (user?.emailVerified == true)
            const ListTile(
              leading: Icon(Icons.verified, color: Colors.green),
              title: Text('Email Verified'),
              contentPadding: EdgeInsets.zero,
            )
          else
            ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.orange),
              title: const Text('Email not verified'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Verify'),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          const Divider(height: 32),
          // Danger zone
          Text(
            'DANGER ZONE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.red,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: () => _showDeleteAccountDialog(context),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              // Handle account deletion
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
