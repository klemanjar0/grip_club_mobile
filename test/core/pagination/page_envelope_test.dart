import 'package:flutter_test/flutter_test.dart';

import 'package:grip_club_mobile/core/pagination/page_envelope.dart';

void main() {
  group('PageEnvelope.fromJson', () {
    test('parses a full page', () {
      final page = PageEnvelope<String>.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'first'},
          <String, dynamic>{'name': 'second'},
        ],
        'page': 2,
        'page_size': 25,
        'has_next': true,
      }, (json) => json['name'] as String);

      expect(page.items, ['first', 'second']);
      expect(page.page, 2);
      expect(page.pageSize, 25);
      expect(page.hasNext, isTrue);
    });

    test('falls back to an empty page when items are missing', () {
      final page = PageEnvelope<String>.fromJson(
        <String, dynamic>{},
        (json) => json['name'] as String,
      );

      expect(page.items, isEmpty);
      expect(page.page, 0);
      expect(page.pageSize, PageEnvelope.defaultPageSize);
      expect(page.hasNext, isFalse);
    });

    test('skips elements that are not objects', () {
      final page = PageEnvelope<String>.fromJson(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'name': 'kept'},
          'not an object',
          null,
        ],
      }, (json) => json['name'] as String);

      expect(page.items, ['kept']);
    });
  });
}
