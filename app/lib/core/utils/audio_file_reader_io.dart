import 'dart:io';

Future<List<int>> readAudioBytesImpl(String path) async {
  final file = File(path);
  return await file.readAsBytes();
}

String getTempAudioFilePathImpl() {
  final dir = Directory.systemTemp.path;
  return '$dir/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
}
