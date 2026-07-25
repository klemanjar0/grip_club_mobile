/// Date helpers for the feeds. Hand-rolled on purpose: `intl` is not a
/// dependency and two formats do not justify adding one.
library;

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `Sat, 24 Aug · 18:30`, in the device's local time zone.
String formatEventTime(DateTime time) {
  final local = time.toLocal();
  final weekday = _weekdays[local.weekday - 1];
  final month = _months[local.month - 1];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$weekday, ${local.day} $month · $hour:$minute';
}

/// `just now` / `12m ago` / `3h ago` / `5d ago`, falling back to a date once
/// the gap passes a week. Future times read as `in 3h`.
String formatRelative(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final difference = reference.difference(time.toLocal());
  final magnitude = difference.abs();

  if (magnitude.inDays >= 7) return formatEventTime(time);

  final label = switch (magnitude) {
    final Duration d when d.inMinutes < 1 => null,
    final Duration d when d.inHours < 1 => '${d.inMinutes}m',
    final Duration d when d.inDays < 1 => '${d.inHours}h',
    final Duration d => '${d.inDays}d',
  };

  if (label == null) return 'just now';

  return difference.isNegative ? 'in $label' : '$label ago';
}
