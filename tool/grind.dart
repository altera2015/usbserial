import 'dart:async';
import 'package:grinder/grinder.dart';

/// Starts the build system.
Future<void> main(List<String> args) => grind(args);

@Task('Uploads the results of the code coverage')
void upload() => Pub.runAsync('coveralls', script: 'coveralls', arguments: ['lcov.info']);


@Task('Runs the test suites')
Future<void> test() async {
  await Future.wait([
    Dart.runAsync('test/test.dart', vmArgs: ['--enable-vm-service', '--pause-isolates-on-exit']),
    Pub.runAsync('coverage', script: 'collect_coverage', arguments: ['--out=coverage.json', '--resume-isolates', '--wait-paused'])
  ]);

  final args = ['--in=coverage.json', '--lcov', '--out=lcov.info', '--packages=.packages', '--report-on=${libDir.path}'];
  return Pub.runAsync('coverage', script: 'format_coverage', arguments: args);
}

