import 'package:caminho_azul/models/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminUser.fromMap (P0-04)', () {
    test('documento sem active é exibido como inativo, como no login', () {
      final user = AdminUser.fromMap('u1', {'name': 'Somente Nome'});
      expect(user.active, isFalse);
      expect(user.firstName, 'Somente');
      expect(user.lastName, 'Nome');
    });

    test('somente active == true é ativo', () {
      expect(AdminUser.fromMap('u1', {'active': true}).active, isTrue);
      expect(AdminUser.fromMap('u1', {'active': false}).active, isFalse);
      expect(AdminUser.fromMap('u1', {'active': 'true'}).active, isFalse);
    });
  });
}
