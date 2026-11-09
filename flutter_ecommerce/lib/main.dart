import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/api_exception.dart';

void main() {
  runApp(
    ProviderScope(
      retry: (retryCount, error) {
        if (error is ApiException &&
            error.statusCode != null &&
            error.statusCode! >= 400 &&
            error.statusCode! < 500) {
          return null;
        }
        return ProviderContainer.defaultRetry(retryCount, error);
      },
      child: const TlvetaApp(),
    ),
  );
}
