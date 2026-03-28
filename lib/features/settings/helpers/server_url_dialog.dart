import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/socket_io_client.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/server_config.dart';
import '../../../core/theme/app_tokens.dart';

/// Shows a dialog for editing the server URL with validation and
/// verification.
Future<void> showServerUrlDialog(
  BuildContext context,
  String currentUrl,
) async {
  final controller = TextEditingController(text: currentUrl);
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        String? errorText;
        var isVerifying = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final l10nDialog = AppLocalizations.of(dialogContext);
            return AlertDialog(
              title: Text(l10nDialog.settingsServerUrl),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: l10nDialog.settingsServerUrlLabel,
                        hintText: defaultServerUrl,
                        errorText: errorText,
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                tooltip: l10nDialog.commonClear,
                                onPressed: () {
                                  controller.clear();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.url,
                      autofillHints: const [AutofillHints.url],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(l10nDialog.commonCancel),
                ),
                if (currentUrl != defaultServerUrl)
                  TextButton(
                    onPressed: () {
                      setServerUrl(null);
                      ApiClient().refreshServerUrl();
                      socketIoClient.refreshServerUrl(getServerUrl());
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10nDialog.settingsServerResetSuccess,
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Text(l10nDialog.settingsServerResetToDefault),
                  ),
                FilledButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final url = controller.text.trim();

                          final validation = validateServerUrl(url);
                          if (!validation.valid) {
                            setDialogState(() {
                              errorText = validation.error;
                            });
                            return;
                          }

                          setDialogState(() {
                            errorText = null;
                            isVerifying = true;
                          });

                          final verificationResult =
                              await verifyServerUrl(url);

                          setDialogState(() {
                            isVerifying = false;
                          });

                          if (!verificationResult.isValid) {
                            setDialogState(() {
                              errorText =
                                  l10nDialog.settingsServerNotReachable;
                            });
                            return;
                          }

                          setServerUrl(url);
                          unawaited(ApiClient().refreshServerUrl());
                          socketIoClient.refreshServerUrl(url);

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10nDialog.settingsServerSaved,
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                  child: isVerifying
                      ? Semantics(
                          label: 'Verifying...',
                          child: SizedBox(
                            width: AppSpacing.lg,
                            height: AppSpacing.lg,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Text(l10nDialog.settingsServerSaveVerify),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
