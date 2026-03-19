import 'package:dio/dio.dart';
import 'dio_factory_stub.dart'
    if (dart.library.io) 'dio_factory_native.dart' as platform;
import 'network_log.dart';

class DioFactory {
  static Dio create({
    String? baseUrl,
    Duration connectTimeout = const Duration(seconds: 5),
    Duration receiveTimeout = const Duration(seconds: 30),
    Duration sendTimeout = const Duration(seconds: 30),
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      headers: {
        'User-Agent': 'ClaudeRemote/1.0',
        'ngrok-skip-browser-warning': 'true',
      },
    ));

    // Use platform-native HTTP stack on mobile (OkHttp/URLSession)
    // No-op on web (uses browser fetch API by default)
    platform.configureAdapter(dio);

    // Logging interceptor
    dio.interceptors.add(_LogInterceptor());

    return dio;
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    NetworkLog.instance.add('HTTP', '-> ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    NetworkLog.instance.add('HTTP',
        '<- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    NetworkLog.instance.add(
      'ERROR',
      'XX ${err.requestOptions.method} ${err.requestOptions.uri}',
      '${err.type}: ${err.error?.runtimeType} - ${err.error}\n${err.message}',
    );
    handler.next(err);
  }
}
