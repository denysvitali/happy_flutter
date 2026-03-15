import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/languages.dart';

class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  final TextEditingController _searchController =
      TextEditingController();
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
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final preferredLanguage = settings.preferredLanguage;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final locale =
        WidgetsBinding.instance.platformDispatcher.locale;
    final deviceLocaleString = locale.toLanguageTag();
    final detectedLanguageCode =
        getDeviceLanguageCode(deviceLocaleString);
    final detectedLanguageInfo =
        allLanguages[detectedLanguageCode];
    final detectedLanguageName =
        detectedLanguageInfo?.displayName ?? 'English';

    final filteredCodes = filterLanguages(_searchQuery);

    final currentSelection =
        preferredLanguage?.isEmpty ?? true
            ? autoLanguageCode
            : preferredLanguage;

    Future<void> handleLanguageChange(
      String newLanguage,
    ) async {
      if (newLanguage == currentSelection) {
        return;
      }

      final router = GoRouter.of(context);

      final confirmed =
          await _showRestartDialog(context, l10n);
      if (confirmed && mounted) {
        final newPreference = newLanguage == autoLanguageCode
            ? ''
            : newLanguage;
        unawaited(
          ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting(
                'preferredLanguage',
                newPreference,
              ),
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: l10n.searchLanguages,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.smd),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
              ),
              autofocus: false,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _buildLanguageRow(
                    context: context,
                    title: l10n.settingsLanguageAutomatic,
                    subtitle:
                        '${l10n.settingsLanguageAutomaticSubtitle}'
                        ' ($detectedLanguageName)',
                    isSelected:
                        currentSelection == autoLanguageCode,
                    onTap: () => handleLanguageChange(
                      autoLanguageCode,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (filteredCodes.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        AppSpacing.xxxl,
                      ),
                      child: Text(
                        l10n.noLanguagesFound,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: _buildLanguageList(
                        context: context,
                        codes: filteredCodes,
                        currentSelection: currentSelection,
                        onSelect: handleLanguageChange,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLanguageList({
    required BuildContext context,
    required List<String> codes,
    required String? currentSelection,
    required Future<void> Function(String) onSelect,
  }) {
    final widgets = <Widget>[];
    final cs = Theme.of(context).colorScheme;

    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];
      final info = allLanguages[code];
      if (info == null) continue;

      if (widgets.isNotEmpty) {
        widgets.add(
          Divider(
            height: 1,
            thickness: AppBorder.hairline,
            indent: AppSpacing.lg,
            endIndent: 0,
            color: cs.outlineVariant,
          ),
        );
      }
      widgets.add(
        _buildLanguageRow(
          context: context,
          title: info.nativeName,
          subtitle: info.region != null
              ? '${info.englishName} (${info.region})'
              : info.englishName,
          isSelected: currentSelection == code,
          onTap: () => onSelect(code),
        ),
      );
    }
    return widgets;
  }

  Widget _buildLanguageRow({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? cs.primary.withValues(
                alpha: AppOpacity.faint,
              )
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: cs.primary,
                size: AppSpacing.xl,
              )
            else
              Icon(
                Icons.chevron_right,
                color: cs.onSurface.withValues(
                  alpha: AppOpacity.medium,
                ),
                size: AppSpacing.xl,
              ),
          ],
        ),
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
            title: Text(
              l10n.settingsLanguageNeedsRestart,
            ),
            content: Text(
              l10n.settingsLanguageNeedsRestartMessage,
            ),
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
