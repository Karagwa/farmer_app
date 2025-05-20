import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty || args[0] != 'bump') {
    print('Usage: dart tool/version_manager.dart bump [major|minor|patch]');
    exit(1);
  }

  final bumpType = args.length > 1 ? args[1] : 'patch';

  // Read pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  final lines = pubspecFile.readAsLinesSync();

  // Find version line
  var versionLineIndex = -1;
  var versionLine = '';

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('version:')) {
      versionLineIndex = i;
      versionLine = lines[i];
      break;
    }
  }

  if (versionLineIndex == -1) {
    print('Could not find version in pubspec.yaml');
    exit(1);
  }

  // Parse version
  final versionMatch = RegExp(
    r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)',
  ).firstMatch(versionLine);
  if (versionMatch == null) {
    print('Could not parse version from: $versionLine');
    exit(1);
  }

  var major = int.parse(versionMatch.group(1)!);
  var minor = int.parse(versionMatch.group(2)!);
  var patch = int.parse(versionMatch.group(3)!);
  var build = int.parse(versionMatch.group(4)!);

  // Bump version
  switch (bumpType) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
      break;
    case 'minor':
      minor++;
      patch = 0;
      break;
    case 'patch':
    default:
      patch++;
      break;
  }
  build++;

  // Update pubspec.yaml
  lines[versionLineIndex] = 'version: $major.$minor.$patch+$build';
  pubspecFile.writeAsStringSync(lines.join('\n'));

  print('Version bumped to $major.$minor.$patch+$build');
}
