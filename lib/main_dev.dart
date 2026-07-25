import 'package:grip_club_mobile/app/config/app_config.dart';
import 'package:grip_club_mobile/bootstrap.dart';

/// Entrypoint for the dev flavor. Run with:
///   flutter run --flavor dev -t lib/main_dev.dart \
///     --dart-define-from-file=env/dev.json
Future<void> main() => bootstrap(expectedFlavor: Flavor.dev);
