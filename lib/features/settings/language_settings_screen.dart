import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/languages.dart';

/// Language settings screen with 40+ languages, search, and auto-detection.
///
/// Features:
/// - Automatic language detection with device language display
/// - Search/filter functionality for 45+ languages
/// - Confirmation dialog before language change
/// - Regional variants (en-US, en-GB, es-ES, etc.)
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final preferredLanguage = settings.preferredLanguage;
    final l10n = AppLocalizations.of(context);

    // Get detected device language
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final deviceLocaleString = locale.toLanguageTag();
    final detectedLanguageCode = getDeviceLanguageCode(deviceLocaleString);
    final detectedLanguageInfo = allLanguages[detectedLanguageCode];
    final detectedLanguageName = detectedLanguageInfo?.displayName ?? 'English';

    // Filter languages based on search query
    final filteredCodes = filterLanguages(_searchQuery);

    // Current selection
    final currentSelection =
        preferredLanguage?.isEmpty ?? true
            ? autoLanguageCode
            : preferredLanguage;

    Future<void> handleLanguageChange(String newLanguage) async {
      if (newLanguage == currentSelection) {
        return; // No change
      }

      // Capture context-dependent objects before async gap
      final router = GoRouter.of(context);

      // Show confirmation dialog
      final confirmed = await _showRestartDialog(context, l10n);
      if (confirmed && mounted) {
        final newPreference =
            newLanguage == autoLanguageCode ? '' : newLanguage;
        unawaited(
          ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('preferredLanguage', newPreference),
        );
        router.pop();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsLanguage),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                _searchFocusNode.unfocus();
              },
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: l10n.searchLanguages,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
              ),
              autofocus: false,
            ),
          ),
          // Language list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                // Automatic detection option
                _buildLanguageOption(
                  context: context,
                  code: autoLanguageCode,
                  title: l10n.settingsLanguageAutomatic,
                  subtitle:
                      '${l10n.settingsLanguageAutomaticSubtitle}'
                      ' ($detectedLanguageName)',
                  isSelected: currentSelection == autoLanguageCode,
                  onTap: () => handleLanguageChange(autoLanguageCode),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                // All supported languages (filtered by search)
                if (filteredCodes.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Text(
                        l10n.noLanguagesFound,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...filteredCodes.map((code) {
                    final info = allLanguages[code];
                    if (info == null) return const SizedBox.shrink();

                    return Column(
                      children: [
                        _buildLanguageOption(
                          context: context,
                          code: code,
                          title: info.nativeName,
                          subtitle: info.region != null
                              ? '${info.englishName} (${info.region})'
                              : info.englishName,
                          isSelected: currentSelection == code,
                          onTap: () => handleLanguageChange(code),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    );
                  }),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String code,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
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

  Future<bool> _showRestartDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.settingsLanguageNeedsRestart),
            content: Text(l10n.settingsLanguageNeedsRestartMessage),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: () => context.pop(true),
                child: Text(l10n.commonContinue),
              ),
            ],
          ),
        ) ??
        false;
  }
}
