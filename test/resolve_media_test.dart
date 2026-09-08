import 'package:flutter_test/flutter_test.dart';
import 'package:spike_flutter_app/core/api_config.dart';
import 'package:spike_flutter_app/models/store.dart';

void main() {
  test('resolveMedia matches the reference frontend URL construction', () {
    expect(
      ApiConfig.resolveMedia('stores/fa07cd31-c299-4b65-8b20-ae7c141c014e.jpg'),
      'https://oshdiaifvwfdbkatagex.supabase.co/storage/v1/object/public/spike-images/stores/fa07cd31-c299-4b65-8b20-ae7c141c014e.jpg',
    );
    expect(
      ApiConfig.resolveMedia('products/some-product.png'),
      'https://oshdiaifvwfdbkatagex.supabase.co/storage/v1/object/public/spike-images/products/some-product.png',
    );
    expect(
      ApiConfig.resolveMedia('/uploads/receipts/r.pdf'),
      'https://spike2.aymanjameel60.deno.net/uploads/receipts/r.pdf',
    );
    expect(ApiConfig.resolveMedia('https://example.com/x.jpg'), 'https://example.com/x.jpg');
    expect(ApiConfig.resolveMedia(''), '');
    expect(ApiConfig.resolveMedia('  '), '');
  });

  test('StoreModel resolves relative store logos to the media bucket', () {
    final store = StoreModel.fromJson(const {
      'id': 's1',
      'name': 'رؤيا',
      'logo_url': 'stores/fa07cd31-c299-4b65-8b20-ae7c141c014e.jpg',
    });
    expect(
      store.logoUrl,
      'https://oshdiaifvwfdbkatagex.supabase.co/storage/v1/object/public/spike-images/stores/fa07cd31-c299-4b65-8b20-ae7c141c014e.jpg',
    );
    expect(StoreModel.fromJson(const {'id': 's2', 'name': 'x'}).logoUrl, isNull);
  });
}
