import 'dart:io';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:args/args.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'package:migrate_to_web/web_file_strings.dart' as webFiles;

/// Migrates a Flutter project to a new project that can be run on Flutter Web.

/// Arguments:
/// Project name (defaults to PROJECT NAME)
/// [-o] overwrite. If true, creates a fresh project even if one exists. If false, only updates changed dart files.
Future<void> migrateToWeb(List<String> args) async {
  final String projectName = Directory.current.path.split('/').last;

  final ArgResults results = getArgs(projectName: projectName, args: args);
  final Logger logger = setUpLogger(results: results);

  final String newProjectName = results['name'].toString().trim();

  logger.stdout(
    'Migrating $projectName to a web project named $newProjectName.',
  );

  if (!hasPubspec()) {
    logger.stderr(
      'No pubspec.yaml file found. Please run `flutter pub run migrate_to_web` from the root of your Fluter project.',
    );
  }

  final Directory newProjectDirectory = Directory('../$newProjectName')
    ..createSync();

  try {
    copyDirectory(Directory.current, newProjectDirectory);

    _addWebDirectory(
      projectName: newProjectName,
      directory: newProjectDirectory,
    );

    _updatePubspec(
      projectDirectory: newProjectDirectory,
      oldName: projectName,
      newName: newProjectName,
    );

    _updateLibImports(
      oldName: projectName,
      newName: newProjectName,
      dir: Directory(newProjectDirectory.path + '/lib'),
    );

    // await _runFlutterPackagesGet(newProjectName);
    logger.stdout('Successfully migrated project!');
  } catch (e) {
    logger.stderr('Error, deleting migration attempt: $e');
    newProjectDirectory.deleteSync(recursive: true);
  }
}

ArgResults getArgs({String projectName, List<String> args}) {
  final ArgParser parser = ArgParser()
    ..addOption(
      'name',
      abbr: 'n',
      defaultsTo: projectName + '_web',
    )
    ..addFlag('overwrite', abbr: 'o')
    ..addFlag('verbose', abbr: 'v');
  return parser.parse(args);
}

Logger setUpLogger({@required ArgResults results}) =>
    results['verbose'] ? Logger.verbose() : Logger.standard();

bool hasPubspec() => File('pubspec.yaml').existsSync();

void copyDirectory(Directory source, Directory destination) =>
    source.listSync(recursive: false).forEach((var entity) {
      if (entity is Directory) {
        var newDirectory = Directory(
            path.join(destination.absolute.path, path.basename(entity.path)));
        newDirectory.createSync();

        copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        entity
            .copySync(path.join(destination.path, path.basename(entity.path)));
      }
    });

void _addWebDirectory({String projectName, Directory directory}) {
  final webDirectory = Directory(directory.path + '/web')..createSync();
  File(webDirectory.path + '/index.html').writeAsStringSync(webFiles.indexHtml);
  File(webDirectory.path + '/main.dart')
      .writeAsStringSync(webFiles.mainDart(projectName: projectName));

  // get fonts
  final File pubspecFile = File(directory.path + '/pubspec.yaml');
  final YamlMap doc = loadYaml(pubspecFile.readAsStringSync());
  final YamlList fonts = doc['flutter']['fonts'];
  final bool usesMaterialDesign = doc['flutter']['uses-material-design'];
  if (!usesMaterialDesign && fonts == null) {
    return;
  }
  final List<dynamic> fontJson =
      fonts == null ? [] : jsonDecode(jsonEncode(fonts));
  if (usesMaterialDesign) {
    fontJson.add({
      'fonts': [
        {'asset': 'MaterialIcons-Regular.ttf'}
      ],
      'family': 'MaterialIcons'
    });
  }
  final assetsDir = Directory(webDirectory.path + '/assets')..createSync();
  final fontsDir = Directory(assetsDir.path + '/fonts')..createSync();
  JsonEncoder encoder = new JsonEncoder.withIndent('    ');
  File('${assetsDir.path}/FontManifest.json').writeAsStringSync(
    encoder.convert(fontJson),
  );
}

void _updatePubspec({
  Directory projectDirectory,
  String oldName,
  String newName,
}) {
  final File pubspecFile = File(projectDirectory.path + '/pubspec.yaml');
  String pubspecString = pubspecFile.readAsStringSync();
  pubspecString = pubspecString.replaceAll(oldName, newName);
  pubspecString = pubspecString.replaceFirst(
    'flutter:\n    sdk: flutter',
    'flutter_web: any\n  flutter_web_ui: any',
  );
  pubspecString = pubspecString.replaceFirst(
    'flutter_test:\n    sdk: flutter',
    'flutter_web_test: any',
  );
  pubspecString = pubspecString.replaceFirst(
    'dev_dependencies:',
    'dev_dependencies:\n  build_runner: ^1.4.0\n  build_web_compilers: ^2.0.0',
  );
  final flutterSection = pubspecString.indexOf('flutter:');
  int i;
  for (i = flutterSection; i < pubspecString.length - 1; ++i) {
    if (pubspecString[i] == '\n') {
      if (pubspecString[i + 1] == RegExp('[A-z]') ||
          pubspecString[i + 1] == '\n') {}
    }
  }
  pubspecString = pubspecString.replaceRange(flutterSection, i + 1, '').trim();
  pubspecString = pubspecString +
      '''\n\ndependency_overrides:
  flutter_web:
    git:
      url: https://github.com/flutter/flutter_web
      path: packages/flutter_web
  flutter_web_ui:
    git:
      url: https://github.com/flutter/flutter_web
      path: packages/flutter_web_ui
  flutter_web_test:
    git:
      url: https://github.com/flutter/flutter_web
      path: packages/flutter_web_test
  ''';
  pubspecFile.writeAsStringSync(pubspecString.trim());
}

void _updateLibImports({String newName, String oldName, Directory dir}) {
  dir.listSync(recursive: false).forEach((var entity) {
    if (entity is Directory) {
      _updateLibImports(dir: entity, newName: newName, oldName: oldName);
    } else if (entity is File) {
      if (path.basename(entity.path) != '.DS_Store') {
        String fileString = entity.readAsStringSync();
        fileString = fileString.replaceAll(
            'import \'package:flutter/', 'import \'package:flutter_web/');
        fileString = fileString.replaceAll(
            'import \'dart:ui\'', 'import \'package:flutter_web_ui/ui.dart\'');
        fileString = fileString.replaceAll(
            'import \'package:$oldName/', 'import \'package:$newName/');
        entity.writeAsStringSync(fileString);
      }
    }
  });
}

void _runFlutterPackagesGet(String projectName) async =>
    await Process.run('flutter', ['packages', 'get']);
