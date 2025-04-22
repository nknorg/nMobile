@TestOn('vm')
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:sqflite_test_app/src/ffi_test_utils.dart';

var runningOnGithubAction = Platform.environment['GITHUB_ACTION'] != null;

Future<void> main() async {
  var binSubDir = 'sqflite_test_app.app/Contents/MacOS';
  var binDir = join(platformExeDir, binSubDir);
  var exeDir = platformExeDir;
  var exePath = join(binDir, 'sqflite_test_app');
  test('build $platform', () async {
    var cachedExePath = join(binDir, 'ffi_create_and_exit');
    var absoluteExePath = absolute(cachedExePath);

    // If you change the app code, you must delete the built executable since it
    // since it won't rebuild
    if (!File(absoluteExePath).existsSync()) {
      await createProject('.');
      await buildProject('.', target: 'test/ffi_create_and_exit_main.dart');

      // Cache executable
      await File(exePath).copy(cachedExePath);
    }
    // Create an empty shell environment
    var env = ShellEnvironment.empty();
    var runAppShell = Shell(environment: env, workingDirectory: exeDir);
    // We run the generated exe, not the copy as it does not work
    await runAppShell.run(shellArgument(join(binSubDir, 'sqflite_test_app')));
  }, skip: !platformIsMacOS, timeout: const Timeout(Duration(minutes: 10)));
}
