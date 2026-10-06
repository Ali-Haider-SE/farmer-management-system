import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();
  String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5050/api',
  );
  String? _accessToken;

  Duration requestTimeout = const Duration(seconds: 30);

  String get baseUrl => _baseUrl;

  bool get isConfigured => _baseUrl.trim().isNotEmpty;

  bool get isAuthenticated =>
      _accessToken != null && _accessToken!.trim().isNotEmpty;

  String? get accessToken => _accessToken;

  void configure({String? url, String? accessToken, Duration? timeout}) {
    if (url != null) {
      _baseUrl = _normalizeBaseUrl(url);
    }

    if (accessToken != null) {
      setAccessToken(accessToken);
    }

    if (timeout != null) {
      requestTimeout = timeout;
    }
  }

  void setBaseUrl(String url) {
    _baseUrl = _normalizeBaseUrl(url);
  }

  void setAccessToken(String? token) {
    final value = token?.trim();

    _accessToken = value == null || value.isEmpty ? null : value;
  }

  void clearAuthentication() {
    _accessToken = null;
  }

  Map<String, String> get defaultHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = _accessToken;

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Map<String, String> _mergeHeaders(Map<String, String>? headers) {
    return {...defaultHeaders, ...?headers};
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(endpoint, queryParameters: queryParameters);

    try {
      final response = await http
          .get(uri, headers: _mergeHeaders(headers))
          .timeout(requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message: 'The request timed out. Please try again.',
        type: ApiExceptionType.timeout,
      );
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to connect to the server. Please check your internet connection.',
        type: ApiExceptionType.network,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'An unexpected error occurred: $e',
        type: ApiExceptionType.unknown,
      );
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(endpoint, queryParameters: queryParameters);

    try {
      final response = await http
          .post(
            uri,
            headers: _mergeHeaders(headers),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message: 'The request timed out. Please try again.',
        type: ApiExceptionType.timeout,
      );
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to connect to the server. Please check your internet connection.',
        type: ApiExceptionType.network,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'An unexpected error occurred: $e',
        type: ApiExceptionType.unknown,
      );
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(endpoint, queryParameters: queryParameters);

    try {
      final response = await http
          .put(
            uri,
            headers: _mergeHeaders(headers),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message: 'The request timed out. Please try again.',
        type: ApiExceptionType.timeout,
      );
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to connect to the server. Please check your internet connection.',
        type: ApiExceptionType.network,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'An unexpected error occurred: $e',
        type: ApiExceptionType.unknown,
      );
    }
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(endpoint, queryParameters: queryParameters);

    try {
      final response = await http
          .patch(
            uri,
            headers: _mergeHeaders(headers),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message: 'The request timed out. Please try again.',
        type: ApiExceptionType.timeout,
      );
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to connect to the server. Please check your internet connection.',
        type: ApiExceptionType.network,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'An unexpected error occurred: $e',
        type: ApiExceptionType.unknown,
      );
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    final uri = _buildUri(endpoint, queryParameters: queryParameters);

    try {
      final response = await http
          .delete(uri, headers: _mergeHeaders(headers))
          .timeout(requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message: 'The request timed out. Please try again.',
        type: ApiExceptionType.timeout,
      );
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to connect to the server. Please check your internet connection.',
        type: ApiExceptionType.network,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'An unexpected error occurred: $e',
        type: ApiExceptionType.unknown,
      );
    }
  }

  Future<bool> healthCheck([String endpoint = '/health']) async {
    try {
      await get(endpoint);
      return true;
    } catch (_) {
      return false;
    }
  }

  Uri _buildUri(String endpoint, {Map<String, dynamic>? queryParameters}) {
    if (!isConfigured) {
      throw const ApiException(
        message:
            'API base URL has not been configured. Set API_BASE_URL before making a remote request.',
        type: ApiExceptionType.configuration,
      );
    }

    final normalizedEndpoint = endpoint.trim().isEmpty ? '/' : endpoint.trim();

    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;

    final path = normalizedEndpoint.startsWith('/')
        ? normalizedEndpoint
        : '/$normalizedEndpoint';

    final uri = Uri.parse('$base$path');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final convertedParameters = <String, String>{};

    queryParameters.forEach((key, value) {
      if (value == null) {
        return;
      }

      if (value is Iterable) {
        convertedParameters[key] = value.join(',');
      } else {
        convertedParameters[key] = value.toString();
      }
    });

    return uri.replace(
      queryParameters: {...uri.queryParameters, ...convertedParameters},
    );
  }

  String _normalizeBaseUrl(String value) {
    var url = value.trim();

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final data = _decodeResponse(response);

    if (statusCode >= 200 && statusCode < 300) {
      return data;
    }

    throw ApiException(
      message: _extractErrorMessage(data, statusCode),
      statusCode: statusCode,
      data: data,
      type: _exceptionTypeFromStatusCode(statusCode),
    );
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) {
      return null;
    }

    final contentType = response.headers['content-type'] ?? '';

    if (contentType.contains('application/json') ||
        response.body.trim().startsWith('{') ||
        response.body.trim().startsWith('[')) {
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    return response.body;
  }

  String _extractErrorMessage(dynamic data, int statusCode) {
    if (data is Map) {
      final message = data['message'];

      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }

      final error = data['error'];

      if (error is String && error.trim().isNotEmpty) {
        return error;
      }

      if (error is Map) {
        final nestedMessage = error['message'];

        if (nestedMessage != null) {
          return nestedMessage.toString();
        }
      }

      final detail = data['detail'];

      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }

      final errors = data['errors'];

      if (errors is Map && errors.isNotEmpty) {
        final firstError = errors.values.first;

        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }

        return firstError.toString();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    return _defaultStatusMessage(statusCode);
  }

  String _defaultStatusMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request. Please check the submitted data.';
      case 401:
        return 'Authentication failed. Please log in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'The request conflicts with existing data.';
      case 422:
        return 'The submitted data is invalid.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'The server encountered an error.';
      case 502:
      case 503:
      case 504:
        return 'The server is temporarily unavailable.';
      default:
        return 'Request failed with status code $statusCode.';
    }
  }

  ApiExceptionType _exceptionTypeFromStatusCode(int statusCode) {
    if (statusCode == 401) {
      return ApiExceptionType.unauthorized;
    }

    if (statusCode == 403) {
      return ApiExceptionType.forbidden;
    }

    if (statusCode == 404) {
      return ApiExceptionType.notFound;
    }

    if (statusCode >= 400 && statusCode < 500) {
      return ApiExceptionType.client;
    }

    if (statusCode >= 500) {
      return ApiExceptionType.server;
    }

    return ApiExceptionType.unknown;
  }
}

enum ApiExceptionType {
  configuration,
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  client,
  server,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final ApiExceptionType type;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
    this.type = ApiExceptionType.unknown,
  });

  bool get isNetworkError => type == ApiExceptionType.network;

  bool get isTimeout => type == ApiExceptionType.timeout;

  bool get isUnauthorized => type == ApiExceptionType.unauthorized;

  bool get isServerError => type == ApiExceptionType.server;

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException [$statusCode]: $message';
    }

    return 'ApiException: $message';
  }
}
