import 'package:caminho_azul/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _profile(Map<String, dynamic> data, {bool requireAdmin = false}) =>
    appUserFromProfile(
      uid: 'u1',
      authEmail: 'u1@caminhoazul.test',
      data: {
        'name': 'Pessoa Sintética',
        'active': true,
        'professionalId': 'p1',
        'institutionIds': ['i1'],
        'studentIds': ['s1'],
        ...data,
      },
      requireAdmin: requireAdmin,
    );

void main() {
  group('appUserFromProfile (P1-17, sem fallback)', () {
    test('aceita os quatro perfis canônicos com subrole', () {
      expect(
        _profile({'role': 'school', 'schoolRole': 'teacher'}).schoolRole,
        SchoolRole.teacher,
      );
      expect(
        _profile({'role': 'school', 'schoolRole': 'director'}).schoolRole,
        SchoolRole.director,
      );
      final ubs = _profile({'role': 'health', 'healthRole': 'ubs_director'});
      expect(ubs.healthRole, HealthRole.ubsDirector);
      expect(ubs.accessLabel, 'Saúde • Direção da UBS');
      expect(
        _profile({'role': 'health', 'healthRole': 'psychologist'}).healthRole,
        HealthRole.psychologist,
      );
      final family = _profile({
        'role': 'family',
        'studentIds': ['s1'],
      });
      expect(family.role, UserRole.family);
      expect(family.studentIds, ['s1']);
      expect(_profile({'role': 'admin'}, requireAdmin: true).role,
          UserRole.administration);
    });

    test('recusa valores antigos em português', () {
      for (final data in [
        {'role': 'escola', 'schoolRole': 'professor'},
        {'role': 'familia'},
        {'role': 'saude', 'healthRole': 'psychologist'},
        {'role': 'school', 'schoolRole': 'direcao'},
      ]) {
        expect(() => _profile(data), throwsA(isA<AuthException>()));
      }
    });

    test('recusa Escola ou Saúde sem subrole (não há Professor por padrão)',
        () {
      expect(() => _profile({'role': 'school'}), throwsA(isA<AuthException>()));
      expect(() => _profile({'role': 'health'}), throwsA(isA<AuthException>()));
      expect(
        () => _profile({'role': 'health', 'healthRole': 'psicologo'}),
        throwsA(isA<AuthException>()),
      );
    });

    test('recusa perfil inativo, ausente ou sem role', () {
      expect(() => _profile({'role': 'family', 'active': false}),
          throwsA(isA<AuthException>()));
      expect(() => _profile({}), throwsA(isA<AuthException>()));
      expect(
        () => appUserFromProfile(uid: 'u1', authEmail: null, data: null),
        throwsA(isA<AuthException>()),
      );
      expect(() => _profile({'role': 'family'}, requireAdmin: true),
          throwsA(isA<AuthException>()));
    });
  });

  group('appUserFromProfile (P1-10, vínculos obrigatórios)', () {
    test('Escola ou Saúde sem profissional ou sem instituição são bloqueadas', () {
      for (final role in [
        {'role': 'school', 'schoolRole': 'teacher'},
        {'role': 'health', 'healthRole': 'psychologist'},
      ]) {
        expect(() => _profile({...role, 'professionalId': null}),
            throwsA(isA<AuthException>()));
        expect(() => _profile({...role, 'institutionIds': <String>[]}),
            throwsA(isA<AuthException>()));
      }
    });

    test('família sem estudante é bloqueada; admin não exige vínculos', () {
      expect(() => _profile({'role': 'family', 'studentIds': <String>[]}),
          throwsA(isA<AuthException>()));
      expect(
        _profile({
          'role': 'admin',
          'professionalId': null,
          'institutionIds': <String>[],
          'studentIds': <String>[],
        }).role,
        UserRole.administration,
      );
    });
  });
}
