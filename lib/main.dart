import 'dart:io';

import 'package:meta/meta.dart';
import 'package:args/args.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:path/path.dart' as path;

/// Migrates a Flutter project to a new project that can be run on Flutter Web.

/// Arguments:
/// Project name (defaults to PROJECT NAME)
/// [-o] overwrite. If true, creates a fresh project even if one exists. If false, only updates changed dart files.

Future<void> migrateToWeb(List<String> args) async {
  final projectName = Directory.current.path.split('/').last;

  final ArgResults results = _getArgs(projectName: projectName, args: args);
  final Logger logger = _setUpLogger(results: results);

  final newProjectName = results['name'];

  logger.stdout(
    'Migrating $projectName to a web project named $newProjectName.',
  );

  if (!_hasPubspec()) {
    logger.stderr(
      'No pubspec.yaml file found. Please run `flutter pub run migrate_to_web` from the root of your Fluter project.',
    );
  }

  Directory('../test_baby').createSync();
  _copyDirectory(Directory.current, Directory('../test_baby'));

  // Directory('').listSync(recursive: t)
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
