import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/message_outbox.dart';
import '../../../core/services/server_config.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_tokens.dart';

/// Account-blind legacy records are never displayed or automatically adopted.
class LegacyOutboxRecoveryTile extends ConsumerStatefulWidget {
  const LegacyOutboxRecoveryTile({super.key});

  @override
  ConsumerState<LegacyOutboxRecoveryTile> createState() =>
      _LegacyOutboxRecoveryTileState();
}

class _LegacyOutboxRecoveryTileState
    extends ConsumerState<LegacyOutboxRecoveryTile> {
  String? _sessionId;
  bool _busy = false;

  Future<void> _review() async {
    final sessionId = _sessionId;
    if (sessionId == null || _busy) return;
    setState(() => _busy = true);
    try {
      final preview = await Sync().previewLegacyOutbox(sessionId);
      if (!mounted) return;
      final l10n = context.l10n;
      if (preview == null) {
        _message(l10n.legacyOutboxUnavailable);
        return;
      }
      // Omit credentials, query and fragment, but retain a server routing path.
      // The ticket fences the account/server/runtime after confirmation.
      final account =
          ref.read(profileNotifierProvider)?.displayName ?? Sync().anonID;
      final server = Uri.parse(getServerUrl());
      final origin = Uri(
        scheme: server.scheme,
        host: server.host,
        port: server.hasPort ? server.port : null,
        path: server.path,
      ).toString();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.legacyOutboxTitle),
          content: Text(
            l10n.legacyOutboxConfirm(preview.count, sessionId, account, origin),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.legacyOutboxRecover),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final recovered = await messageOutbox.recoverLegacy(preview);
      if (!mounted) return;
      if (recovered) Sync().reconcileOutboxStatuses(sessionId);
      _message(
        recovered ? l10n.legacyOutboxSuccess : l10n.legacyOutboxUnavailable,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final l10n = context.l10n;
    // Do not reveal whether another account has legacy sends. This entry is
    // always available; only a selected, current-account session can be probed.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.legacyOutboxTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.legacyOutboxExplanation),
          const SizedBox(height: AppSpacing.sm),
          DropdownButton<String>(
            isExpanded: true,
            value: sessions.containsKey(_sessionId) ? _sessionId : null,
            hint: Text(l10n.sessionsReviewSession),
            items: sessions.keys
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(
                      '${sessions[id]?.metadata?.name ?? id} ($id)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy ? null : (id) => setState(() => _sessionId = id),
          ),
          TextButton(
            onPressed: !_busy && sessions.containsKey(_sessionId)
                ? _review
                : null,
            child: Text(l10n.legacyOutboxPreview),
          ),
        ],
      ),
    );
  }
}
