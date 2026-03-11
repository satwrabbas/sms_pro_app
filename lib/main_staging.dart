import 'package:my_pro_app/app/app.dart';
import 'package:my_pro_app/bootstrap.dart';

Future<void> main() async {
  await bootstrap(() => const App());
}
