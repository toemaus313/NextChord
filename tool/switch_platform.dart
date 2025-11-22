// tool/switch_platform.dart
import 'dart:io';

Future<void> runCommand(
  String command,
  List<String> args, {
  String? workingDirectory,
}) async {
  stdout.writeln('> $command ${args.join(' ')}'
      '${workingDirectory != null ? ' (in $workingDirectory)' : ''}');

  final process = await Process.start(
    command,
    args,
    workingDirectory: workingDirectory,
    runInShell: true, // lets "flutter" / "pod" be found on all platforms
  );

  await stdout.addStream(process.stdout);
  await stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ProcessException(
      command,
      args,
      'Exited with code $exitCode',
      exitCode,
    );
  }
}

bool get _usesBuildRunner {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) return false;
  final contents = pubspec.readAsStringSync();
  return contents.contains('build_runner');
}

Future<void> main(List<String> args) async {
  try {
    stdout.writeln('=== Switch platform – environment refresh ===');
    stdout.writeln('Detected platform: '
        '${Platform.isMacOS ? 'macOS' : Platform.isWindows ? 'Windows' : Platform.operatingSystem}');

    // 1. Clean old build artifacts
    await runCommand('flutter', ['clean']);

    // 2. Restore dependencies
    await runCommand('flutter', ['pub', 'get']);

    // 3. Optional: run code generation if build_runner is present
    if (_usesBuildRunner) {
      stdout.writeln('build_runner detected in pubspec.yaml – running codegen...');
      await runCommand('dart', [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ]);
    } else {
      stdout.writeln('No build_runner dependency found – skipping codegen.');
    }

    // 4. iOS / macOS CocoaPods (on macOS only)
    if (Platform.isMacOS) {
      Future<void> maybePodInstall(String dir) async {
        final d = Directory(dir);
        if (!d.existsSync()) return;
        final podfile = File('$dir/Podfile');
        if (!podfile.existsSync()) return;

        stdout.writeln('Running `pod install` in $dir ...');
        await runCommand('pod', ['install'], workingDirectory: dir);
      }

      await maybePodInstall('ios');
      await maybePodInstall('macos');
    }

    stdout.writeln('=== Done. You should be ready to run `flutter run`. ===');
  } on ProcessException catch (e) {
    stderr.writeln('\nERROR running command: ${e.message}');
    stderr.writeln('Command: ${e.executable} ${e.arguments.join(" ")}');
    stderr.writeln(
        'Check that the tool is installed and on your PATH on this machine.');
    exit(1);
  } catch (e, st) {
    stderr.writeln('\nUnexpected error in switch_platform.dart: $e');
    stderr.writeln(st);
    exit(1);
  }
}

