/// Display helpers for the Kubernetes pods screen. Pure functions so the
/// formatting is unit-testable without a widget tree.
library;

/// CPU in cores from millicores: `250` → `0.25`, `1500` → `1.5`,
/// `12000` → `12`. Trailing zeros are trimmed.
String formatCpuCores(int millicores) {
  final cores = millicores / 1000;
  final digits = cores < 1
      ? 2
      : cores < 10
      ? 1
      : 0;
  var text = cores.toStringAsFixed(digits);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return text;
}

const _binaryUnits = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];

/// Bytes in binary units: `536870912` → `512 MiB`, `1610612736` → `1.5 GiB`.
/// One decimal below 10 units, none above.
String formatBinaryBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _binaryUnits.length - 1) {
    value /= 1024;
    unit++;
  }
  var text = value.toStringAsFixed(unit == 0 || value >= 10 ? 0 : 1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return '$text ${_binaryUnits[unit]}';
}

/// Compact uptime: `45s`, `12m`, `2h 14m`, `3d 4h`.
String formatPodUptime(Duration duration) {
  if (duration.isNegative) return '0s';
  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  if (days > 0) return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  if (duration.inHours > 0) {
    return minutes > 0 ? '${duration.inHours}h ${minutes}m' : '${hours}h';
  }
  if (duration.inMinutes > 0) return '${duration.inMinutes}m';
  return '${duration.inSeconds}s';
}

/// Short repository label: `https://github.com/acme/app.git` + `main` →
/// `acme/app @ main`. Non-GitHub URLs keep their host-less path.
String formatPodRepo(String url, String ref) {
  var repo = url.trim();
  if (repo.isEmpty) return '';
  repo = repo.replaceFirst(
    RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false),
    '',
  );
  repo = repo.replaceFirst(RegExp(r'^git@'), '');
  repo = repo.replaceFirst(RegExp(r'^(www\.)?github\.com[/:]'), '');
  repo = repo.replaceFirst(RegExp(r'\.git$'), '');
  repo = repo.replaceFirst(RegExp(r'/+$'), '');
  return ref.isEmpty ? repo : '$repo @ $ref';
}

/// Usage as a fraction of the limit, falling back to the request. Null when
/// neither is set, so the caller shows the raw value without a bar.
double? podUsageFraction({
  required int usage,
  required int limit,
  required int request,
}) {
  final capacity = limit > 0 ? limit : request;
  if (capacity <= 0) return null;
  return (usage / capacity).clamp(0.0, 1.0);
}
