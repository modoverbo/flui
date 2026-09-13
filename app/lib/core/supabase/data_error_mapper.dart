import 'dart:async';

import 'package:flui/core/error/failure.dart';
import 'package:http/http.dart' as http;

/// Maps PostgREST and transport errors.
Failure mapDataError(Object error) {
  if (error is http.ClientException || error is TimeoutException) {
    return const NetworkFailure();
  }
  return UnexpectedFailure(error);
}
