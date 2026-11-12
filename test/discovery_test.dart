import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msgi_one/features/discovery/data/sample_alumni.dart';

void main() {
  test('sample directory search trims input and matches case-insensitive careers and cities', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(filteredSampleAlumniProvider('  PUNE  ')).single.name,
      'Sample alumna B',
    );
    expect(
      container.read(filteredSampleAlumniProvider('research')).single.city,
      'London',
    );
    expect(container.read(filteredSampleAlumniProvider('')).length, 3);
    expect(
      container.read(filteredSampleAlumniProvider('unavailable')),
      isEmpty,
    );
  });
}
