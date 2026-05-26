const _relationshipGoalLabels = {
  'long_term':  'Long-term relationship',
  'short_term': 'Short-term dating',
  'marriage':   'Marriage',
  'friendship': 'Friendship first',
  'casual':     'Just exploring',
  'unsure':     'Not sure yet',
};

/// Converts a backend enum value (e.g. 'long_term') to a display label.
/// Returns the original string if no mapping is found.
String formatRelationshipGoal(String value) =>
    _relationshipGoalLabels[value] ?? value;

String timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

String formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $suffix';
}
