import 'dart:async';
import 'package:grinder/grinder.dart';
import 'package:coveralls/coveralls.dart' show Configuration;
import 'dart:io';

import 'package:grinder_coveralls/grinder_coveralls.dart' as coveralls;

var files = [ "transformers.dart", "transaction.dart", "types.dart" ];

/// Starts the build system.
Future<void> main(List<String> args) => grind(args);


@Task('Collects the code coverage of Dart scripts from a given directory')
Future<String> collect() async {
  
  
  await Directory("lib").create();
  files.forEach( (file) {
    print("Copying $file");
    File("../lib/$file").copySync("lib/$file");
  });
  
  var s = await coveralls.collectCoverage(getFile('test.dart'),saveAs: 'lcov.info', basePath: Directory.current.path, reportOn: ["lib"]);
    
  return s;
  
}

@Task() Future<void> upload() async {
  final config = await Configuration.loadDefaults();
  config['repo_token'] = Platform.environment['COVERALLS_REPO_TOKEN'];  

  final coverage = await getFile('lcov.info').readAsString();
  await coveralls.uploadCoverage(coverage, configuration: config);
  
  files.forEach( (file) {
    print("Deleting $file");
    File("lib/$file").deleteSync();
  }); 
  
  await Directory("lib").delete();  
}