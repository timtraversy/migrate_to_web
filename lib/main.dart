import 'dart:io';

import 'package:meta/meta.dart';
import 'package:args/args.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;

import 'package:migrate_to_web/web_file_strings.dart' as webFiles;

/// Migrates a Flutter project to a new project that can be run on Flutter Web.

/// Arguments:
/// Project name (defaults to PROJECT NAME)
/// [-o] overwrite. If true, creates a fresh project even if one exists. If false, only updates changed dart files.
Future<void> migrateToWeb(List<String> args) async {
  final String projectName = Directory.current.path.split('/').last;

  final ArgResults results = _getArgs(projectName: projectName, args: args);
  final Logger logger = _setUpLogger(results: results);

  final String newProjectName = results['name'].toString().trim();
  final Directory newProjectDirectory = Directory('../$newProjectName')
    ..createSync();

  logger.stdout(
    'Migrating $projectName to a web project named $newProjectName.',
  );

  if (!_hasPubspec()) {
    logger.stderr(
      'No pubspec.yaml file found. Please run `flutter pub run migrate_to_web` from the root of your Fluter project.',
    );
  }

  _copyDirectory(Directory.current, newProjectDirectory);

  _removeUnneededFiles(newProjectDirectory);

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

  _addWebDirectory(projectName: newProjectName, directory: newProjectDirectory);

  // await _runFlutterPackagesGet(newProjectName);
}

ArgResults _getArgs({String projectName, List<String> args}) {
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

Logger _setUpLogger({@required ArgResults results}) =>
    results['verbose'] ? Logger.verbose() : Logger.standard();

bool _hasPubspec() => File('pubspec.yaml').existsSync();

void _copyDirectory(Directory source, Directory destination) =>
    source.listSync(recursive: false).forEach((var entity) {
      if (entity is Directory) {
        var newDirectory = Directory(
            path.join(destination.absolute.path, path.basename(entity.path)));
        newDirectory.createSync();

        _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        entity
            .copySync(path.join(destination.path, path.basename(entity.path)));
      }
    });

void _updatePubspec(
    {Directory projectDirectory, String oldName, String newName}) {
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
      String fileString = entity.readAsStringSync();
      fileString = fileString.replaceAll(
          'import \'package:flutter', 'import \'package:flutter_web');
      fileString = fileString.replaceAll(
          'import \'dart:ui\'', 'import \'package:flutter_web_ui/ui.dart\'');
      fileString = fileString.replaceAll(
          'import \'package:$oldName', 'import \'package:$newName');
      entity.writeAsStringSync(fileString);
    }
  });
}

void _removeUnneededFiles(Directory directory) {
  Directory(directory.path + '/ios').deleteSync(recursive: true);
  Directory(directory.path + '/android').deleteSync(recursive: true);
}

void _addWebDirectory({String projectName, Directory directory}) {
  final webDirectory = Directory(directory.path + '/web')..createSync();
  File(webDirectory.path + '/index.html').writeAsStringSync(webFiles.indexHtml);
  File(webDirectory.path + '/main.dart')
      .writeAsStringSync(webFiles.mainDart(projectName: projectName));
}

void _runFlutterPackagesGet(String projectName) async => await Process.run(
      'cd $projectName && flutter packages get && cd -',
      [],
    );
