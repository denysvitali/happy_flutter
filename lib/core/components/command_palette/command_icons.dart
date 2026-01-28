import 'package:flutter/material.dart';
import 'command_model.dart';

/// Icon data mapping for command palette items.
///
/// Maps icon names to Material Icons.
class CommandPaletteIcons {
  /// Gets the IconData for a given icon name.
  static IconData? getIcon(String? iconName) {
    if (iconName == null) return null;

    final iconMap = <String, IconData>{
      'add-circle-outline': Icons.add_circle_outline,
      'chatbubbles-outline': Icons.chatbubbles_outline,
      'chatbubbles': Icons.chatbubbles,
      'settings-outline': Icons.settings_outlined,
      'settings': Icons.settings,
      'person-circle-outline': Icons.person_circle_outline,
      'person-circle': Icons.person_circle,
      'link-outline': Icons.link_outlined,
      'link': Icons.link,
      'time-outline': Icons.time_outline,
      'time': Icons.access_time,
      'log-out-outline': Icons.logout,
      'log-out': Icons.logout,
      'code-slash-outline': Icons.code,
      'code-slash': Icons.code,
      'add': Icons.add,
      'create': Icons.add,
      'search': Icons.search,
      'home': Icons.home,
      'home-outline': Icons.home_outlined,
      'terminal': Icons.terminal,
      'terminal-outline': Icons.terminal,
      'notifications': Icons.notifications,
      'notifications-outline': Icons.notifications_none,
      'help': Icons.help_outline,
      'help-outline': Icons.help,
      'theme': Icons.palette,
      'language': Icons.language,
      'profile': Icons.person,
      'profile-outline': Icons.person_outline,
      'developer': Icons.developer_mode,
      'developer-mode': Icons.developer_mode,
      'sign-out': Icons.logout,
      'refresh': Icons.refresh,
      'close': Icons.close,
      'check': Icons.check,
      'arrow-right': Icons.arrow_forward,
      'chevron-right': Icons.chevron_right,
      'new': Icons.add_circle,
      'folder': Icons.folder,
      'folder-open': Icons.folder_open,
      'computer': Icons.computer,
      'wifi': Icons.wifi,
      'lock': Icons.lock,
      'lock-open': Icons.lock_open,
      'visibility': Icons.visibility,
      'visibility-off': Icons.visibility_off,
      'copy': Icons.content_copy,
      'cut': Icons.content_cut,
      'paste': Icons.content_paste,
      'delete': Icons.delete,
      'edit': Icons.edit,
      'save': Icons.save,
      'share': Icons.share,
      'download': Icons.download,
      'upload': Icons.upload,
      'undo': Icons.undo,
      'redo': Icons.redo,
      'history': Icons.history,
      'star': Icons.star,
      'star-outline': Icons.star_outline,
      'heart': Icons.favorite,
      'heart-outline': Icons.favorite_border,
      'warning': Icons.warning,
      'error': Icons.error,
      'info': Icons.info,
      'success': Icons.check_circle,
    };

    return iconMap[iconName];
  }
}
