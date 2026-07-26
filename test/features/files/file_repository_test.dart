import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/files/data/file_repository.dart';

import '../../helpers/avatar_fixtures.dart';
import '../../helpers/stub_adapter.dart';

void main() {
  late StubAdapter adapter;
  late FileRepository repository;

  void register(Map<String, Stub> responses) {
    adapter = StubAdapter(responses);
    repository = FileRepository(dio: dioWith(adapter));
  }

  test('posts the bytes as multipart and returns the new file', () async {
    register({
      '/files': Stub(201, <String, dynamic>{
        ...avatarJson(id: 'f11e0000-0000-4000-8000-0000000000aa'),
        'mime_type': 'image/png',
        'size_bytes': 69,
        'created_at': '2026-08-24T18:30:00Z',
      }),
    });

    final uploaded = await repository.upload(testImage());

    expect(uploaded.id, 'f11e0000-0000-4000-8000-0000000000aa');
    expect(uploaded.url, contains('/files/'));

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(
      request.headers[Headers.contentTypeHeader],
      contains('multipart/form-data'),
    );

    // The part has to be named `file`; nothing else in the form is read.
    final form = request.data! as FormData;
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.contentType?.mimeType, 'image/png');
  });

  test('translates a rejected upload into an ApiException', () async {
    register({
      '/files': Stub(
        415,
        errorBody('unsupported_media_type', 'That file is not an image.'),
      ),
    });

    await expectLater(
      repository.upload(testImage()),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'unsupported_media_type')
            .having((e) => e.statusCode, 'statusCode', 415),
      ),
    );
  });

  test('refuses a response with no file in it', () async {
    register({'/files': Stub(201, <String, dynamic>{})});

    await expectLater(
      repository.upload(testImage()),
      throwsA(isA<ApiException>()),
    );
  });
}
