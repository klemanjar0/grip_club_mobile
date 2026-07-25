import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/bootstrap.dart';

/// Entrypoint for the prod flavor. Run with:
///   flutter run --flavor prod --release -t lib/main_prod.dart \
///     --dart-define-from-file=env/prod.json
Future<void> main() => bootstrap(expectedFlavor: Flavor.prod);
