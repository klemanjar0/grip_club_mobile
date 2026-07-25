import 'package:equatable/equatable.dart';

/// A value that may be *absent* or may be *present and null* — the distinction a
/// plain `T?` cannot make.
///
/// Some fields in a PATCH body clear themselves when sent as `null`, so
/// "leave this alone" and "set this to null" have to travel separately:
///
/// ```dart
/// update(id);                                  // description untouched
/// update(id, description: Optional('Bring chalk.'));
/// update(id, description: Optional.clear());   // description becomes null
/// ```
///
/// Only the fields the API documents as clearable take one of these. Everything
/// else keeps a plain nullable parameter, where `null` means "unchanged".
class Optional<T extends Object> extends Equatable {
  const Optional(this.value);

  /// Sends an explicit `null`, which is what clears the field server-side.
  const Optional.clear() : value = null;

  final T? value;

  bool get isClearing => value == null;

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'Optional($value)';
}
