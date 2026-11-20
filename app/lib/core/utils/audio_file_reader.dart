import 'audio_file_reader_stub.dart'
    if (dart.library.io) 'audio_file_reader_io.dart'
    if (dart.library.js_interop) 'audio_file_reader_web.dart'
    if (dart.library.html) 'audio_file_reader_web.dart';

Future<List<int>> readAudioBytes(String path) => readAudioBytesImpl(path);
String getTempAudioFilePath() => getTempAudioFilePathImpl();
