// This file is conditionally selected on non-web platforms (native).
// The web counterpart is native_adapter_helper_web.dart.
import 'package:dio/dio.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

HttpClientAdapter createNativeAdapter() => NativeAdapter();
