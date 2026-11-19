import '../folders/session_folders_doc.dart';
import 'app_localizations.dart';

/// User-facing text for a refused folder edit.
String folderRuleMessage(AppLocalizations l10n, FolderRule rule) =>
    switch (rule) {
      FolderRule.emptyName => l10n.foldersErrorEmptyName,
      FolderRule.nameTooLong => l10n.foldersErrorNameTooLong,
      FolderRule.controlCharacters => l10n.foldersErrorControlCharacters,
      FolderRule.duplicateName => l10n.foldersErrorDuplicateName,
      FolderRule.tooManyFolders => l10n.foldersErrorTooMany,
      FolderRule.tooDeep => l10n.foldersErrorTooDeep,
      FolderRule.cycle => l10n.foldersErrorCycle,
      FolderRule.missingFolder => l10n.foldersErrorMissing,
      FolderRule.wrongAnchor => l10n.foldersErrorWrongAnchor,
      FolderRule.readOnly => l10n.foldersReadOnly,
    };
