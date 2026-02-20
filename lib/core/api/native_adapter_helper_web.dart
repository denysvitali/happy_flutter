// This file is conditionally selected on web (dart.library.js_interop).
// The native counterpart is native_adapter_helper.dart.
import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

HttpClientAdapter createNativeAdapter() => BrowserHttpClientAdapter();
