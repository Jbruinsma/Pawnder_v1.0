import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage(),
      dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl)) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await this.storage.read(key: accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await clearToken();
          }
          handler.next(e);
        },
      ),
    );

    if (kDebugMode) {
      this.dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pawnder.justinbruinsma.com/api/v1',
  );

  static const accessTokenKey = 'auth_token';

  final Dio dio;
  final FlutterSecureStorage storage;

  Future<String?> getToken() => storage.read(key: accessTokenKey);
  Future<void> saveToken(String token) => storage.write(key: accessTokenKey, value: token);
  Future<void> clearToken() => storage.delete(key: accessTokenKey);

  String _cleanPath(String path) => path.startsWith('/') ? path : '/$path';

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get<T>(_cleanPath(path), queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return dio.post<T>(_cleanPath(path), data: data);
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) {
    return dio.put<T>(_cleanPath(path), data: data);
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) {
    return dio.delete<T>(_cleanPath(path), data: data);
  }

  String messageForError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Could not connect to the backend.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}