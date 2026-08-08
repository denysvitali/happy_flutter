/// Low-cardinality bucket for collection sizes used in performance metrics.
///
/// Exact collection sizes belong on sampled traces, not metric labels: a
/// label value per size would create an ever-growing Prometheus series set.
String collectionSizeBucket(int count) {
  if (count <= 0) return '0';
  if (count <= 10) return '1-10';
  if (count <= 25) return '11-25';
  if (count <= 50) return '26-50';
  if (count <= 100) return '51-100';
  if (count <= 250) return '101-250';
  return '251+';
}
