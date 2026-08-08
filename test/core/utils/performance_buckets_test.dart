import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/performance_buckets.dart';

void main() {
  test('collectionSizeBucket keeps scale labels bounded', () {
    expect(collectionSizeBucket(-1), '0');
    expect(collectionSizeBucket(0), '0');
    expect(collectionSizeBucket(1), '1-10');
    expect(collectionSizeBucket(10), '1-10');
    expect(collectionSizeBucket(11), '11-25');
    expect(collectionSizeBucket(25), '11-25');
    expect(collectionSizeBucket(26), '26-50');
    expect(collectionSizeBucket(50), '26-50');
    expect(collectionSizeBucket(51), '51-100');
    expect(collectionSizeBucket(100), '51-100');
    expect(collectionSizeBucket(101), '101-250');
    expect(collectionSizeBucket(250), '101-250');
    expect(collectionSizeBucket(251), '251+');
  });
}
