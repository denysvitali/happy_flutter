import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/voice_languages.dart';

/// Voice settings screen - ElevenLabs voice language selection
class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final selectedLanguageCode =
        settings.voiceAssistantLanguage ?? '';
    final selectedLanguage =
        findVoiceLanguageByCode(selectedLanguageCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voiceTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              'Select the language for voice assistant output. '
              'Language settings are provided by ElevenLabs.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Auto-detect option
          _buildLanguageTile(
            context: context,
            language: voiceLanguages[0],
            isSelected: selectedLanguageCode.isEmpty,
            onTap: () {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('voiceAssistantLanguage', null);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          // Navigate to language selection
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.language,
                color: AppColors.iosBlue,
              ),
              title: const Text('Voice Language'),
              subtitle: Text(selectedLanguage?.displayName ?? 'Auto-detect'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.pushNamed('voice-language');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile({
    required BuildContext context,
    required VoiceLanguage language,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.record_voice_over,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        title: Text(language.name),
        subtitle: Text(language.region ?? language.nativeName),
        trailing: isSelected
            ? Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// Voice language selection screen with search functionality
class VoiceLanguageSelectionScreen extends ConsumerStatefulWidget {
  const VoiceLanguageSelectionScreen({super.key});

  @override
  ConsumerState<VoiceLanguageSelectionScreen> createState() =>
      _VoiceLanguageSelectionScreenState();
}

class _VoiceLanguageSelectionScreenState
    extends ConsumerState<VoiceLanguageSelectionScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredLanguages = searchVoiceLanguages(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Language'),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: Theme.of(context).colorScheme.surface,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search languages...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Language count footer
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              '${filteredLanguages.length} languages available',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          // Language list
          Expanded(
            child: ListView.builder(
              itemCount: filteredLanguages.length,
              itemBuilder: (context, index) {
                final language = filteredLanguages[index];
                final isSelected = _isLanguageSelected(language);

                return Card(
                  key: ValueKey(language.code),
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.language,
                      color: AppColors.iosBlue,
                    ),
                    title: Text(language.displayName),
                    subtitle: Text(language.subtitle),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => _selectLanguage(language),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isLanguageSelected(VoiceLanguage language) {
    final currentState = ref.read(settingsNotifierProvider);
    final currentCode = currentState.voiceAssistantLanguage ?? '';
    return currentCode == language.code;
  }

  void _selectLanguage(VoiceLanguage language) {
    ref.read(settingsNotifierProvider.notifier).updateSetting(
      'voiceAssistantLanguage',
      language.code.isEmpty ? null : language.code,
    );
    Navigator.pop(context);
  }
}
