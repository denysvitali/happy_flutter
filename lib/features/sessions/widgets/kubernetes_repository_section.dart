import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dialogs/confirm_dialog.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/rpc/rpc_types.dart';
import '../../../core/services/repo_history_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import 'new_session_form_group.dart';

/// Asks the selected machine what GitHub knows about a repository and ref.
typedef RepoBranchLookup =
    Future<RepoBranchesResponse> Function(String repoUrl, String ref);

/// What the Kubernetes repository fields currently describe.
@immutable
class KubernetesRepositorySelection {
  const KubernetesRepositorySelection({
    this.repoUrl = '',
    this.repoRef = '',
    this.additionalRepos = const [],
    this.refMissing = false,
  });

  final String repoUrl;
  final String repoRef;
  final List<String> additionalRepos;

  /// GitHub was asked and [repoRef] does not exist in [repoUrl].
  final bool refMissing;
}

/// A ref the machine refused at spawn time, with the branch it suggested.
typedef RejectedRepoRef = ({String ref, String defaultBranch});

/// Parses the daemon's spawn refusal for a ref that does not exist:
/// `branch "main" does not exist in acme/widgets; its default branch is
/// "master"`. Null for every other error.
RejectedRepoRef? parseRejectedRepoRef(String error) {
  final match = RegExp(
    r'branch "([^"]+)" does not exist in \S+?'
    r'(?:; its default branch is "([^"]+)")?(?:$|[\s.,;])',
  ).firstMatch(error);
  if (match == null) return null;
  return (ref: match.group(1)!, defaultBranch: match.group(2) ?? '');
}

final _ownerRepo = RegExp(r'^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$');

/// Whether [repository] names a complete GitHub repository: a github.com URL
/// in any spelling, or a bare `owner/repo`.
bool isGitHubRepository(String repository) {
  final value = repository.trim();
  final bare = !value.contains(':') && !value.contains('@');
  if (!bare && !value.toLowerCase().contains('github.com')) return false;
  return _ownerRepo.hasMatch(repoHistoryKey(value));
}

/// The repository part of the new-session dialog for Kubernetes: the
/// repository to work in, its branch, further repositories cloned beside it,
/// and saved sets of all three.
///
/// Repositories and branches used before are offered as one-tap chips, and
/// the branch is checked against GitHub through the selected machine while
/// the dialog is still open, so a wrong branch ("main" where the repository
/// uses "master") is fixed with one tap before any pod exists.
class KubernetesRepositorySection extends ConsumerStatefulWidget {
  const KubernetesRepositorySection({
    required this.onChanged,
    super.key,
    this.initialRepoUrl,
    this.initialRepoRef,
    this.suggestedRepoUrls = const [],
    this.lookupBranches,
    this.rejectedRef,
    this.enabled = true,
    this.lookupDebounce = const Duration(milliseconds: 450),
    this.header,
    this.optionsHeader,
    this.extraOptions = const [],
  });

  /// Title above the repository and branch group.
  final String? header;

  /// Title above the folded options group.
  final String? optionsHeader;

  /// Further folded rows shown in the options group after "More
  /// repositories" (the dialog adds its MCP server choice here).
  final List<Widget> extraOptions;

  final String? initialRepoUrl;

  /// Null means "not chosen": the last branch used for the repository, then
  /// its default branch, then `main`.
  final String? initialRepoRef;

  /// Repositories seen on existing sessions of the selected machine.
  final List<String> suggestedRepoUrls;

  /// Null when no machine is selected; the branch is then not checked.
  final RepoBranchLookup? lookupBranches;

  /// Set after the machine refused a spawn for a missing ref.
  final RejectedRepoRef? rejectedRef;
  final bool enabled;
  final Duration lookupDebounce;
  final ValueChanged<KubernetesRepositorySelection> onChanged;

  @override
  ConsumerState<KubernetesRepositorySection> createState() =>
      _KubernetesRepositorySectionState();
}

class _KubernetesRepositorySectionState
    extends ConsumerState<KubernetesRepositorySection> {
  static const _fallbackRef = 'main';
  static const _maxAdditional = 16;

  late final TextEditingController _url;
  late final TextEditingController _ref;
  final _extra = TextEditingController();
  final _additional = <String>[];

  /// False until the user picks or types a branch; until then the branch
  /// follows the repository (history, then its default branch).
  bool _refChosen = false;
  Timer? _debounce;
  int _lookupGeneration = 0;
  RepoBranchesResponse? _lookup;
  String _lookupRepoKey = '';
  String _lookupRef = '';

  @override
  void initState() {
    super.initState();
    final url = widget.initialRepoUrl?.trim() ?? '';
    _refChosen = widget.initialRepoRef != null;
    _url = TextEditingController(text: url);
    _ref = TextEditingController(
      text:
          widget.initialRepoRef ??
          ref.read(repoHistoryProvider).lastBranchFor(url) ??
          _fallbackRef,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _emit();
      _scheduleLookup(immediate: true);
    });
  }

  @override
  void didUpdateWidget(KubernetesRepositorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.lookupBranches == null) != (widget.lookupBranches == null)) {
      _scheduleLookup(immediate: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _url.dispose();
    _ref.dispose();
    _extra.dispose();
    super.dispose();
  }

  String get _repoUrl => _url.text.trim();
  String get _repoRef => _ref.text.trim();

  /// The lookup result, when it still describes the repository in the field.
  RepoBranchesResponse? get _currentLookup =>
      _lookup != null && _lookupRepoKey == repoHistoryKey(_repoUrl)
      ? _lookup
      : null;

  bool get _refMissing {
    final ref = _repoRef;
    if (ref.isEmpty) return false;
    final lookup = _currentLookup;
    if (lookup != null && lookup.success) {
      if (lookup.branches.contains(ref)) return false;
      if (_lookupRef == ref && lookup.refExists != null) {
        return !lookup.refExists!;
      }
    }
    return widget.rejectedRef?.ref == ref;
  }

  void _emit() {
    widget.onChanged(
      KubernetesRepositorySelection(
        repoUrl: _repoUrl,
        repoRef: _repoRef,
        additionalRepos: List.unmodifiable(_additional),
        refMissing: _refMissing,
      ),
    );
  }

  void _setRef(String value, {required bool chosen}) {
    _ref.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _refChosen = chosen;
  }

  void _onUrlChanged() {
    if (!_refChosen) {
      final remembered = ref.read(repoHistoryProvider).lastBranchFor(_repoUrl);
      _setRef(remembered ?? _fallbackRef, chosen: false);
    }
    setState(() {});
    _emit();
    _scheduleLookup();
  }

  void _onRefTyped() {
    _refChosen = true;
    setState(() {});
    _emit();
    _scheduleLookup();
  }

  void _pickRepo(String url) {
    _url.value = TextEditingValue(
      text: url,
      selection: TextSelection.collapsed(offset: url.length),
    );
    _onUrlChanged();
  }

  void _pickRef(String branch) {
    setState(() => _setRef(branch, chosen: true));
    _emit();
    _scheduleLookup(immediate: true);
  }

  void _scheduleLookup({bool immediate = false}) {
    _debounce?.cancel();
    final lookup = widget.lookupBranches;
    // Only a complete GitHub `owner/repo` can be looked up; a half-typed URL
    // or another host is not asked about.
    if (lookup == null || !isGitHubRepository(_repoUrl)) {
      _lookupGeneration++;
      return;
    }
    if (immediate) {
      unawaited(_runLookup(lookup));
    } else {
      _debounce = Timer(
        widget.lookupDebounce,
        () => unawaited(_runLookup(lookup)),
      );
    }
  }

  Future<void> _runLookup(RepoBranchLookup lookup) async {
    final generation = ++_lookupGeneration;
    final url = _repoUrl;
    final askedRef = _repoRef;
    final RepoBranchesResponse result;
    try {
      result = await lookup(url, askedRef);
    } catch (_) {
      return;
    }
    if (!mounted || generation != _lookupGeneration) return;
    setState(() {
      _lookup = result;
      _lookupRepoKey = repoHistoryKey(url);
      _lookupRef = askedRef;
      // An untouched branch is only a guess: follow the repository's real
      // default instead of asking the user to fix a mistake they never made.
      final fallback = result.defaultBranch;
      if (result.success &&
          !_refChosen &&
          fallback.isNotEmpty &&
          fallback != askedRef &&
          result.refExists == false) {
        _setRef(fallback, chosen: false);
      }
    });
    _emit();
  }

  void _addAdditional([String? value]) {
    final repo = (value ?? _extra.text).trim();
    final key = repoHistoryKey(repo);
    if (key.isEmpty || _additional.length >= _maxAdditional) return;
    final taken = {
      repoHistoryKey(_repoUrl),
      for (final existing in _additional) repoHistoryKey(existing),
    };
    setState(() {
      if (!taken.contains(key)) _additional.add(repo);
      if (value == null) _extra.clear();
    });
    _emit();
  }

  void _removeAdditional(String repo) {
    setState(() => _additional.remove(repo));
    _emit();
  }

  void _applySet(RepoSet set) {
    setState(() {
      _url.text = set.repoUrl;
      _setRef(
        set.repoRef.isEmpty ? _fallbackRef : set.repoRef,
        chosen: set.repoRef.isNotEmpty,
      );
      _additional
        ..clear()
        ..addAll(set.additionalRepos);
    });
    _emit();
    _scheduleLookup(immediate: true);
  }

  Future<void> _saveSet() async {
    final l10n = context.l10n;
    final suggested = repoDisplayName(_repoUrl).split('/').last;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RepoSetNameDialog(initialName: suggested),
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    ref
        .read(repoHistoryProvider.notifier)
        .saveSet(
          RepoSet(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name.trim(),
            repoUrl: _repoUrl,
            repoRef: _repoRef,
            additionalRepos: List.of(_additional),
          ),
        );
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(l10n.newSessionRepoSetSaved(name.trim()))),
    );
  }

  Future<void> _deleteSet(RepoSet set) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.newSessionRepoSetDeleteTitle,
      content: l10n.newSessionRepoSetDeleteMessage(set.name),
      confirmLabel: l10n.commonDelete,
      isDestructive: true,
    );
    if (!mounted || !confirmed) return;
    ref.read(repoHistoryProvider.notifier).deleteSet(set.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final history = ref.watch(repoHistoryProvider);
    final enabled = widget.enabled;
    final urlKey = repoHistoryKey(_repoUrl);
    final lookup = _currentLookup;
    final refMissing = _refMissing;

    final query = _repoUrl.toLowerCase();
    final seenRepos = <String>{urlKey};
    final repoSuggestions = <String>[
      for (final repo in [...history.recentRepos, ...widget.suggestedRepoUrls])
        if (seenRepos.add(repoHistoryKey(repo)) &&
            (query.isEmpty || repo.toLowerCase().contains(query)))
          repo,
    ].take(4).toList(growable: false);

    final seenBranches = <String>{_repoRef};
    final rejectedDefault = widget.rejectedRef?.ref == _repoRef
        ? widget.rejectedRef!.defaultBranch
        : '';
    final branchSuggestions = <String>[
      for (final branch in [
        // After a refusal the fix comes first.
        if (refMissing && (lookup?.defaultBranch.isNotEmpty ?? false))
          lookup!.defaultBranch,
        if (refMissing && rejectedDefault.isNotEmpty) rejectedDefault,
        ...history.branchesFor(_repoUrl),
        ...?lookup?.branches,
      ])
        if (branch.isNotEmpty && seenBranches.add(branch)) branch,
    ].take(4).toList(growable: false);

    final extraSeen = <String>{
      urlKey,
      for (final repo in _additional) repoHistoryKey(repo),
    };
    final extraSuggestions = <String>[
      for (final repo in history.recentRepos)
        if (extraSeen.add(repoHistoryKey(repo))) repo,
    ].take(3).toList(growable: false);

    // Recent repositories are labelled by name; the owner is only shown
    // when two suggestions share a name.
    final names = [
      for (final repo in repoSuggestions) repoDisplayName(repo).split('/').last,
    ];
    String shortName(int index) =>
        names.where((name) => name == names[index]).length > 1
        ? repoDisplayName(repoSuggestions[index])
        : names[index];

    final errorStyle = AppText.secondary(
      theme,
    ).copyWith(color: AppColors.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        NewSessionGroup(
          header: widget.header,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('k8s-repo-url'),
                  controller: _url,
                  enabled: enabled,
                  decoration: newSessionRowDecoration(
                    label: l10n.newSessionRepositoryUrl,
                    hint: l10n.newSessionRepositoryUrlHint,
                    icon: Icons.source_outlined,
                    suffixIcon: IconButton(
                      key: const Key('k8s-save-repo-set'),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      tooltip: l10n.newSessionRepoSetSave,
                      onPressed: enabled && urlKey.isNotEmpty ? _saveSet : null,
                    ),
                    errorText: lookup != null && lookup.notFound
                        ? l10n.newSessionRepositoryNotFound
                        : null,
                    errorStyle: errorStyle,
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _onUrlChanged(),
                ),
                if (history.sets.isNotEmpty || repoSuggestions.isNotEmpty)
                  NewSessionRowChips(
                    children: [
                      for (final set in history.sets)
                        InputChip(
                          key: ValueKey('repo-set-${set.id}'),
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            Icons.bookmark_rounded,
                            color: cs.primary,
                          ),
                          label: Text(set.name),
                          tooltip: [
                            '${repoDisplayName(set.repoUrl)} · ${set.repoRef}',
                            for (final repo in set.additionalRepos)
                              repoDisplayName(repo),
                          ].join('\n'),
                          onPressed: enabled ? () => _applySet(set) : null,
                          onDeleted: enabled ? () => _deleteSet(set) : null,
                          deleteButtonTooltipMessage: l10n.commonDelete,
                        ),
                      for (final (index, repo) in repoSuggestions.indexed)
                        ActionChip(
                          key: ValueKey(
                            'repo-suggestion-${repoHistoryKey(repo)}',
                          ),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.history_rounded),
                          label: Text(shortName(index)),
                          tooltip: repoDisplayName(repo),
                          onPressed: enabled ? () => _pickRepo(repo) : null,
                        ),
                    ],
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('k8s-repo-ref'),
                  controller: _ref,
                  enabled: enabled,
                  decoration: newSessionRowDecoration(
                    label: l10n.newSessionGitRef,
                    hint: lookup?.defaultBranch.isNotEmpty ?? false
                        ? lookup!.defaultBranch
                        : l10n.newSessionGitRefHint,
                    icon: Icons.account_tree_outlined,
                    errorText: refMissing
                        ? l10n.newSessionBranchNotFound(
                            _repoRef,
                            repoDisplayName(_repoUrl),
                          )
                        : null,
                    errorStyle: errorStyle,
                  ),
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _onRefTyped(),
                ),
                if (branchSuggestions.isNotEmpty)
                  NewSessionRowChips(
                    children: [
                      for (final (index, branch) in branchSuggestions.indexed)
                        ActionChip(
                          key: ValueKey('branch-suggestion-$branch'),
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            refMissing && index == 0
                                ? Icons.auto_fix_high_rounded
                                : Icons.account_tree_outlined,
                            color: refMissing && index == 0 ? cs.primary : null,
                          ),
                          label: Text(
                            refMissing && index == 0
                                ? l10n.newSessionUseBranch(branch)
                                : branch,
                          ),
                          onPressed: enabled ? () => _pickRef(branch) : null,
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Occasional setup: folded away, with the current choice in each
        // summary line.
        NewSessionGroup(
          header: widget.optionsHeader,
          children: [
            ExpansionTile(
              key: const Key('k8s-additional-repos'),
              tilePadding: kNewSessionTilePadding,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.add_link_rounded),
              title: Text(l10n.newSessionAdditionalRepos),
              subtitle: Text(
                _additional.isEmpty
                    ? l10n.newSessionAdditionalReposNone
                    : _additional.map(repoDisplayName).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.secondary(theme),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.newSessionAdditionalReposHelp,
                  style: AppText.secondary(theme),
                ),
                if (_additional.isNotEmpty)
                  _ChipRow(
                    children: [
                      for (final repo in _additional)
                        InputChip(
                          key: ValueKey(
                            'additional-repo-${repoHistoryKey(repo)}',
                          ),
                          visualDensity: VisualDensity.compact,
                          label: Text(repoDisplayName(repo)),
                          onDeleted: enabled
                              ? () => _removeAdditional(repo)
                              : null,
                          deleteButtonTooltipMessage: l10n.commonRemove,
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('k8s-additional-repo'),
                  controller: _extra,
                  enabled: enabled && _additional.length < _maxAdditional,
                  decoration: InputDecoration(
                    hintText: l10n.newSessionAdditionalRepoHint,
                    prefixIcon: const Icon(Icons.source_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_rounded),
                      tooltip: l10n.newSessionAdditionalRepoAdd,
                      onPressed: enabled ? _addAdditional : null,
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addAdditional(),
                ),
                if (extraSuggestions.isNotEmpty)
                  _ChipRow(
                    children: [
                      for (final repo in extraSuggestions)
                        ActionChip(
                          key: ValueKey(
                            'additional-suggestion-${repoHistoryKey(repo)}',
                          ),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.add_rounded),
                          label: Text(repoDisplayName(repo)),
                          onPressed: enabled
                              ? () => _addAdditional(repo)
                              : null,
                        ),
                    ],
                  ),
              ],
            ),
            ...widget.extraOptions,
          ],
        ),
        if (refMissing)
          // Announced once for screen readers; the field carries the text.
          Semantics(
            liveRegion: true,
            label: l10n.newSessionBranchNotFound(
              _repoRef,
              repoDisplayName(_repoUrl),
            ),
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: children,
    ),
  );
}

class _RepoSetNameDialog extends StatefulWidget {
  const _RepoSetNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RepoSetNameDialog> createState() => _RepoSetNameDialogState();
}

class _RepoSetNameDialogState extends State<_RepoSetNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.newSessionRepoSetSave),
      content: TextField(
        key: const Key('k8s-repo-set-name'),
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.newSessionRepoSetName),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}
