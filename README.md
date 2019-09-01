# Migrate To Web
Automatially migrate your current Flutter projects to be compatible with Flutter Web. The current workflow suggested by the Flutter team is to create a copy of your app's code and change it according to their [migration guide](https://github.com/flutter/flutter_web/blob/master/docs/migration_guide.md). This tool automates all those steps and creates a nice little Flutter Web project out of your current one.

#### How To use it
From the root of your flutter project run

    flutter pub run migrate_to_web

This will automatically create a project in the same parent directory with the suffix `_web`.

To use a different name for the web project, use the argument `-n or --name`.

    flutter pub run migrate_to_web -n my_web_project

If you make changes to your project, just run the same command and it will update the web project.

#### To-do
- [ ] Handle assets and fonts
- [ ] Add tests for updating situations

PRs & issues welcome 😛
