import 'package:dio/dio.dart';

Future<List<int>> readAudioBytesImpl(String path) async {
  if (path.isEmpty) return [];
  final dio = Dio();
  final response = await dio.get<List<int>>(
    path,
    options: Options(responseType: ResponseType.bytes),
  );
  return response.data ?? [];
}

String getTempAudioFilePathImpl() => '';
