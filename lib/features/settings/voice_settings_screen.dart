import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/languages.dart';

/// Voice settings screen - ElevenLabs voice selection
class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final selectedVoice = settings.voiceAssistantLanguage;

    // Voice options (ElevenLabs voices)
    final voices = [
      const VoiceOption(
        id: 'en_us_male',
        name: 'English (US) - Male',
        language: 'en',
      ),
      const VoiceOption(
        id: 'en_us_female',
        name: 'English (US) - Female',
        language: 'en',
      ),
      const VoiceOption(
        id: 'en_uk_male',
        name: 'English (UK) - Male',
        language: 'en',
      ),
      const VoiceOption(
        id: 'de_male',
        name: 'German - Male',
        language: 'de',
      ),
      const VoiceOption(
        id: 'es_male',
        name: 'Spanish - Male',
        language: 'es',
      ),
      const VoiceOption(
        id: 'fr_male',
        name: 'French - Male',
        language: 'fr',
      ),
      const VoiceOption(
        id: 'ja_male',
        name: 'Japanese - Male',
        language: 'ja',
      ),
      const VoiceOption(
        id: 'pt_male',
        name: 'Portuguese - Male',
        language: 'pt',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Select a voice for text-to-speech. Voice settings are provided by ElevenLabs.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          // None option (disabled)
          Card(
            child: ListTile(
              title: const Text('None'),
              subtitle: const Text('Disable voice output'),
              onTap: () {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('voiceAssistantLanguage', null);
              },
            ),
          ),
          const SizedBox(height: 8),
          // Voice options
          ...voices.map((voice) {
            final isSelected = selectedVoice == voice.id;
            return Column(
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.record_voice_over,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(voice.name),
                    subtitle: Text('Language: ${voice.language.toUpperCase()}'),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateSetting('voiceAssistantLanguage', voice.id);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class VoiceOption {
  final String id;
  final String name;
  final String language;

  const VoiceOption({
    required this.id,
    required this.name,
    required this.language,
  });
}
