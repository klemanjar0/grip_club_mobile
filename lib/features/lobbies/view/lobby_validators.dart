/// Field validators for the lobby form.
///
/// The limits mirror the API's own so a round trip is not needed to learn that
/// a name is 300 characters long; the server stays the authority.
abstract final class LobbyValidators {
  static const int nameMaxLength = 200;
  static const int descriptionMaxLength = 2000;
  static const int placeMaxLength = 120;
  static const int addressMaxLength = 300;
  static const int chatLinkMaxLength = 500;

  static String? name(String? value) =>
      _required(value, label: 'name', maxLength: nameMaxLength);

  static String? country(String? value) =>
      _required(value, label: 'country', maxLength: placeMaxLength);

  static String? city(String? value) =>
      _required(value, label: 'city', maxLength: placeMaxLength);

  static String? description(String? value) =>
      _optional(value, label: 'Description', maxLength: descriptionMaxLength);

  static String? address(String? value) =>
      _optional(value, label: 'Address', maxLength: addressMaxLength);

  static String? chatLink(String? value) =>
      _optional(value, label: 'Chat link', maxLength: chatLinkMaxLength);

  /// The API rejects an [eventTime] that is not in the future.
  static String? eventTime(DateTime? value) {
    if (value == null) return 'Pick a date and time';
    if (!value.isAfter(DateTime.now())) return 'Pick a time in the future';

    return null;
  }

  static String? _required(
    String? value, {
    required String label,
    required int maxLength,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a $label';
    if (trimmed.length > maxLength) {
      return 'Keep the $label under $maxLength characters';
    }

    return null;
  }

  static String? _optional(
    String? value, {
    required String label,
    required int maxLength,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > maxLength) {
      return '$label must be under $maxLength characters';
    }

    return null;
  }
}
