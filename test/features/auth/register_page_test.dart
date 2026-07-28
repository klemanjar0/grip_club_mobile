import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:grip_club_mobile/core/network/api_exception.dart';
import 'package:grip_club_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:grip_club_mobile/features/auth/data/auth_repository.dart';
import 'package:grip_club_mobile/features/auth/domain/user.dart';
import 'package:grip_club_mobile/features/auth/view/register_page.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

final _user = User(
  id: '3f9a1c2e-0b64-4f1a-9c1f-2a4b6d8e0f11',
  email: 'rider@example.com',
  displayName: 'rider',
  country: 'Ukraine',
  city: 'Kyiv',
  createdAt: DateTime.utc(2026, 8, 24, 18, 30),
);

void main() {
  late AuthRepository repository;
  late AuthBloc bloc;

  void stubRegister({Object? throws}) {
    final call = when(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
        country: any(named: 'country'),
        city: any(named: 'city'),
      ),
    );

    if (throws != null) {
      call.thenThrow(throws);
    } else {
      call.thenAnswer((_) async => _user);
    }
  }

  setUp(() => repository = _MockAuthRepository());

  tearDown(() async => bloc.close());

  /// The bloc is built here rather than in `setUp` on purpose: a bloc created
  /// outside the test body emits on the enclosing zone, and its states then
  /// never reach the widget between pumps.
  Future<void> pumpRegister(WidgetTester tester) async {
    bloc = AuthBloc(repository: repository);

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: const MaterialApp(home: RegisterPage()),
      ),
    );
  }

  /// Fills in the credentials and moves on to the location step.
  Future<void> fillAccountStep(
    WidgetTester tester, {
    String email = 'rider@example.com',
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'correct-horse');
    await tester.enterText(fields.at(2), 'correct-horse');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> fillLocationStep(
    WidgetTester tester, {
    String country = 'Ukraine',
    String city = 'Kyiv',
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), country);
    await tester.enterText(fields.at(1), city);
    await tester.pumpAndSettle();
  }

  testWidgets('asks for the credentials before the location', (tester) async {
    await pumpRegister(tester);

    expect(find.text('Confirm password'), findsOneWidget);
    // Only the step on screen is mounted, so the second step's fields are not
    // in the tree yet — its title in the header is.
    expect(find.text('Country'), findsNothing);

    await fillAccountStep(tester);

    expect(find.text('Country'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Confirm password'), findsNothing);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('a step is not passed until its own fields validate', (
    tester,
  ) async {
    await pumpRegister(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'not-an-email');
    await tester.enterText(fields.at(1), 'correct-horse');
    await tester.enterText(fields.at(2), 'a-different-one');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(find.text('Country'), findsNothing);
  });

  testWidgets('registers with the location the second step collected', (
    tester,
  ) async {
    stubRegister();

    await pumpRegister(tester);
    await fillAccountStep(tester);
    await fillLocationStep(tester);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    verify(
      () => repository.register(
        email: 'rider@example.com',
        password: 'correct-horse',
        country: 'Ukraine',
        city: 'Kyiv',
      ),
    ).called(1);
  });

  testWidgets('the location step can be left empty', (tester) async {
    stubRegister();

    await pumpRegister(tester);
    await fillAccountStep(tester);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // Blank rather than absent: the repository is what drops an unanswered
    // field from the request.
    verify(
      () => repository.register(
        email: 'rider@example.com',
        password: 'correct-horse',
        country: '',
        city: '',
      ),
    ).called(1);
  });

  testWidgets('Back returns to the credentials with them still filled in', (
    tester,
  ) async {
    await pumpRegister(tester);
    await fillAccountStep(tester);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('rider@example.com'), findsOneWidget);
    expect(find.text('Country'), findsNothing);
  });

  testWidgets('a rejected email sends the form back to the step that owns it', (
    tester,
  ) async {
    stubRegister(
      throws: const ApiException(
        'That email is already registered.',
        statusCode: 409,
        code: 'email_taken',
      ),
    );

    await pumpRegister(tester);
    await fillAccountStep(tester);
    await fillLocationStep(tester);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('That email is already registered'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('a rejected city stays on the step that owns it', (tester) async {
    stubRegister(
      throws: const ApiException(
        'The request payload is invalid.',
        statusCode: 400,
        code: 'validation_failed',
        fieldErrors: <String, String>{
          'city': 'must be 120 characters or fewer',
        },
      ),
    );

    await pumpRegister(tester);
    await fillAccountStep(tester);
    await fillLocationStep(tester);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('must be 120 characters or fewer'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
  });
}
