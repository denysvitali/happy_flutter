import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/error_message_widget.dart';

void main() {
  test('ErrorMessageWidget_errorTitle_unknown_uses_status_from_message', () {
    expect(
      ErrorMessageWidget.errorTitle(
        'unknown',
        'API Error: 400 [code=upstream_error] The request could not be completed.',
      ),
      'Provider error (400)',
    );
  });

  test('ErrorMessageWidget_errorTitle_unknown_prefers_debug_status', () {
    expect(
      ErrorMessageWidget.errorTitle('unknown', 'boom', status: 429),
      'Provider error (429)',
    );
  });

  test('ErrorMessageWidget_errorTitle_unknown_without_status', () {
    expect(ErrorMessageWidget.errorTitle('unknown', 'boom'), 'Request failed');
  });

  test('ErrorMessageWidget_errorTitle_keeps_specific_types', () {
    expect(
      ErrorMessageWidget.errorTitle('model_not_found', 'x'),
      'model not found',
    );
  });
}
