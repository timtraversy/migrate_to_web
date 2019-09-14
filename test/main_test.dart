import 'dart:io';
import 'package:test/test.dart';
import 'package:migrate_to_web/main.dart';

/// Original Flutter project
const String projectPath = 'test/test_project';

/// Successfully migrated project for comparing
const String successfullMigrationPath =
    '../successfull_migration/test_project_web';

/// Attempted project migration
const String migrationAttemptPath = '../test_project_web';

void main() {
  group('Unit tests', () {
    test('Update pubspec', () {});
    test('Update lib imports', () {});
  });
  group('Whole migration', () {
    tearDown(() {
      Directory(Directory.current.path + '/' + migrationAttemptPath)
          .deleteSync(recursive: true);
    });
    Directory.current = projectPath;
    test('Create web project', () async {
      await migrateToWeb([]);
      expect(fileMigratedSuccessfully('/web/assets/FontManifest.json'), isTrue);
      expect(fileMigratedSuccessfully('/pubspec.yaml'), isTrue);
      expect(fileMigratedSuccessfully('/lib/main.dart'), isTrue);
      expect(fileMigratedSuccessfully('/lib/main.dart'), isTrue);
      expect(fileMigratedSuccessfully('/lib/subdir/home_page.dart'), isTrue);
      expect(fileMigratedSuccessfully('/web/index.html'), isTrue);
      expect(fileMigratedSuccessfully('/web/main.dart'), isTrue);
    });
    test('Update web project', () async {
      /// TODO: make sure updating doesn't wipe out web/ changes
      final String newFlutterMain =
          File('new_main/flutter.dart').readAsStringSync();
      final String newWebMain = File('new_main/web.dart').readAsStringSync();
      final String currentFlutterMain =
          File(projectPath + '/lib/main.dart').readAsStringSync();
      final String currentWebMain =
          File(projectPath + '/lib/main.dart').readAsStringSync();
      await migrateToWeb([migrationAttemptPath]);
    }, skip: true);
  });
}

bool fileMigratedSuccessfully(String path) {
  final File webFile = File(migrationAttemptPath + path);
  final File attemptFile = File(successfullMigrationPath + path);
  return webFile.readAsStringSync() == attemptFile.readAsStringSync();
}
