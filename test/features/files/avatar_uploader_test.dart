import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/images/avatar_selection.dart';
import 'package:grip_club_mobile/core/images/local_image.dart';
import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/files/data/avatar_uploader.dart';

import '../../helpers/avatar_fixtures.dart';

void main() {
  late MockFileRepository files;
  late AvatarUploader uploader;

  setUpAll(() => registerFallbackValue(testImage()));

  setUp(() {
    files = MockFileRepository();
    uploader = AvatarUploader(files: files);
  });

  test('leaves the key out entirely when the image was not touched', () async {
    final resolved = await uploader.resolve(const AvatarSelection.unchanged());

    // `null` is what keeps `avatar_file_id` out of the body, so a save that had
    // nothing to do with the picture cannot disturb it.
    expect(resolved, isNull);
    verifyNever(() => files.upload(any()));
  });

  test('sends an explicit null to clear the picture', () async {
    final resolved = await uploader.resolve(const AvatarSelection.cleared());

    expect(resolved, isNotNull);
    expect(resolved!.isClearing, isTrue);
    verifyNever(() => files.upload(any()));
  });

  test('uploads first and answers with the new id', () async {
    final image = testImage();
    when(
      () => files.upload(image),
    ).thenAnswer((_) async => remoteImage(id: 'new-file-id'));

    final resolved = await uploader.resolve(AvatarSelection.picked(image));

    expect(resolved?.value, 'new-file-id');
    verify(() => files.upload(image)).called(1);
  });

  test('lets a failed upload through so the save reports it', () async {
    final LocalImage image = testImage();
    when(
      () => files.upload(image),
    ).thenThrow(const ApiException('No internet connection.'));

    await expectLater(
      uploader.resolve(AvatarSelection.picked(image)),
      throwsA(isA<ApiException>()),
    );
  });
}
