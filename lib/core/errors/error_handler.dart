import 'package:flutter/material.dart';

import 'app_exception.dart';

class ErrorHandler {
  ErrorHandler._();

  static String getMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Something went wrong. Please try again.';
  }

  static void showError(BuildContext context, Object error) {
    final message = getMessage(error);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
