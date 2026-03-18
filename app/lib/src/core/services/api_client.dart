import 'package:dio/dio.dart';

class ApiClient {
  late final Dio _dio;
  String? _token;

  String get baseUrl => _dio.options.baseUrl;

  ApiClient({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
  }

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  // Auth
  Future<Map<String, dynamic>> pair(String pin, String deviceName) async {
    final response = await _dio.post('/api/pair', data: {
      'pin': pin,
      'deviceName': deviceName,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> health() async {
    final response = await _dio.get('/api/health');
    return response.data;
  }

  // Terminals
  Future<List<dynamic>> getTerminals() async {
    final response = await _dio.get('/api/terminals');
    return response.data;
  }

  // System
  Future<Map<String, dynamic>> getSystemInfo() async {
    final response = await _dio.get('/api/system');
    return response.data;
  }

  Future<List<dynamic>> getProcesses({int top = 50}) async {
    final response = await _dio.get('/api/processes', queryParameters: {'top': top});
    return response.data;
  }

  Future<void> killProcess(int pid) async {
    await _dio.delete('/api/processes/$pid');
  }

  // Files
  Future<List<dynamic>> listFiles({String? path}) async {
    final response = await _dio.get('/api/files',
        queryParameters: path != null ? {'path': path} : null);
    return response.data;
  }

  Future<void> createDirectory(String path) async {
    await _dio.post('/api/files/mkdir', queryParameters: {'path': path});
  }

  Future<Map<String, dynamic>> readFile(String path) async {
    final response = await _dio.get('/api/files/read', queryParameters: {'path': path});
    return response.data;
  }

  Future<void> deleteFile(String path) async {
    await _dio.delete('/api/files', queryParameters: {'path': path});
  }

  Future<void> renameFile(String oldPath, String newPath) async {
    await _dio.put('/api/files/rename',
        queryParameters: {'oldPath': oldPath, 'newPath': newPath});
  }

  Future<Response> downloadFile(String path, String savePath) async {
    return _dio.get(
      '/api/files/download',
      queryParameters: {'path': path},
      options: Options(responseType: ResponseType.stream),
    );
  }

  Future<void> uploadFile(String directory, String filePath, String fileName) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    await _dio.post('/api/files/upload',
        data: formData, queryParameters: {'dir': directory});
  }

  // Actions
  Future<void> shutdown() async => _dio.post('/api/actions/shutdown');
  Future<void> restart() async => _dio.post('/api/actions/restart');
  Future<void> lock() async => _dio.post('/api/actions/lock');
  Future<void> sleep() async => _dio.post('/api/actions/sleep');

  Future<String> getClipboard() async {
    final response = await _dio.get('/api/actions/clipboard');
    return response.data['text'] ?? '';
  }

  Future<void> setClipboard(String text) async {
    await _dio.post('/api/actions/clipboard', queryParameters: {'text': text});
  }
}
