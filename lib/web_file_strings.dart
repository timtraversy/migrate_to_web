final String indexHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title></title>
  <script defer src="main.dart.js" type="application/javascript"></script>
</head>
<body>
</body>
</html>
''';

String mainDart({String projectName}) => '''
import 'package:flutter_web_ui/ui.dart' as ui;

import 'package:$projectName/main.dart' as app;

main() async {
  await ui.webOnlyInitializePlatform();
  app.main();
}
''';
