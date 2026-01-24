import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';

/// Profiles screen - AI backend profiles (Claude, Gemini, OpenAI)
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final profiles = settings.profiles;
    final selectedProfileId = settings.lastUsedProfile;

    // Built-in profiles
    final builtInProfiles = [
      AIBackendProfile(
        id: 'anthropic',
        name: 'Claude (Anthropic)',
        description: 'Default Anthropic API configuration',
        isBuiltIn: true,
      ),
      AIBackendProfile(
        id: 'openai',
        name: 'OpenAI',
        description: 'OpenAI API configuration',
        isBuiltIn: true,
      ),
      AIBackendProfile(
        id: 'google',
        name: 'Gemini (Google)',
        description: 'Google Gemini API configuration',
        isBuiltIn: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddProfileDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // None option
          _buildProfileCard(
            context: context,
            profile: null,
            isSelected: selectedProfileId == null,
            onTap: () {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('lastUsedProfile', null);
            },
          ),
          const SizedBox(height: 8),
          // Built-in profiles
          ...builtInProfiles.map((profile) {
            final isSelected = selectedProfileId == profile.id;
            return Column(
              children: [
                _buildProfileCard(
                  context: context,
                  profile: profile,
                  isSelected: isSelected,
                  onTap: () {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .updateSetting('lastUsedProfile', profile.id);
                  },
                  onEdit: () =>
                      _showEditProfileDialog(context, ref, profile),
                ),
                const SizedBox(height: 8),
              ],
            );
          }),
          // Custom profiles
          if (profiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Custom Profiles',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...profiles.map((profile) {
              final isSelected = selectedProfileId == profile.id;
              return Column(
                children: [
                  _buildProfileCard(
                    context: context,
                    profile: profile,
                    isSelected: isSelected,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateSetting('lastUsedProfile', profile.id);
                    },
                    onEdit: () =>
                        _showEditProfileDialog(context, ref, profile),
                    onDelete: () =>
                        _confirmDeleteProfile(context, ref, profile),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required BuildContext context,
    required AIBackendProfile? profile,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: profile == null
                ? Colors.grey
                : Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            profile == null
                ? Icons.remove
                : profile.id == 'anthropic'
                    ? Icons.auto_awesome
                    : profile.id == 'openai'
                        ? Icons.smart_toy
                        : Icons.computer,
            color: Colors.white,
          ),
        ),
        title: Text(profile?.name ?? 'None'),
        subtitle: Text(profile?.description ?? 'Use default configuration'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check,
                  color: Theme.of(context).colorScheme.primary),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Profile'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Profile Name'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Name is required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final settings = ref.read(settingsNotifierProvider);
                final newProfile = AIBackendProfile(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameController.text,
                  description: 'Custom profile',
                  isBuiltIn: false,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                );
                ref.read(settingsNotifierProvider.notifier).updateSetting(
                  'profiles',
                  [...settings.profiles, newProfile],
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(
      BuildContext context, WidgetRef ref, AIBackendProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Profile Name'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Name is required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final settings = ref.read(settingsNotifierProvider);
                final updatedProfiles = settings.profiles.map((p) {
                  if (p.id == profile.id) {
                    return p.copyWith(
                      name: nameController.text,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    );
                  }
                  return p;
                }).toList();
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('profiles', updatedProfiles);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProfile(
      BuildContext context, WidgetRef ref, AIBackendProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Are you sure you want to delete "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final settings = ref.read(settingsNotifierProvider);
              final updatedProfiles =
                  settings.profiles.where((p) => p.id != profile.id).toList();
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('profiles', updatedProfiles);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
