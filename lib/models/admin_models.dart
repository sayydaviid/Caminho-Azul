import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';

enum AdminSection {
  institutions('Instituições'),
  professionals('Profissionais'),
  localNetwork('Rede local'),
  users('Usuários'),
  parameters('Parâmetros'),
  audit('Auditoria');

  const AdminSection(this.label);
  final String label;
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
String? _nullableText(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.schoolRole,
    this.healthRole,
    this.needsNormalization = false,
    this.institutionIds = const [],
    this.studentIds = const [],
    this.professionalId,
    this.createdAt,
    this.updatedAt,
    this.lastAccessAt,
    this.createdBy,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String name;
  final String email;
  final UserRole role;
  final SchoolRole? schoolRole;
  final HealthRole? healthRole;

  /// Perfil com valores antigos (português), ausentes ou incompletos. Não tem
  /// acesso operacional até o admin salvar o cadastro com valores canônicos.
  final bool needsNormalization;
  final List<String> institutionIds;
  final List<String> studentIds;
  final bool active;
  final String? professionalId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastAccessAt;
  final String? createdBy;

  factory AdminUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AdminUser.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  factory AdminUser.fromMap(String id, Map<String, dynamic> data) {
    final fullName = _nullableText(data['name']) ?? '';
    final explicitFirst = _nullableText(data['firstName']);
    final explicitLast = _nullableText(data['lastName']);
    final parts =
        fullName.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final rawRole = data['role'] as String?;
    final rawSchoolRole = data['schoolRole'] as String?;
    final canonicalRole = UserRole.fromValue(rawRole);
    final role =
        canonicalRole ?? UserRole.fromLegacyValue(rawRole) ?? UserRole.family;
    final canonicalSchoolRole = SchoolRole.fromValue(rawSchoolRole);
    final schoolRole =
        canonicalSchoolRole ?? SchoolRole.fromLegacyValue(rawSchoolRole);
    final healthRole = HealthRole.fromValue(data['healthRole'] as String?);
    final needsNormalization = canonicalRole == null ||
        (role == UserRole.school && canonicalSchoolRole == null) ||
        (role == UserRole.health && healthRole == null);
    List<String> ids(Object? value) => List<String>.unmodifiable(
          value is List ? value.whereType<String>() : const <String>[],
        );
    return AdminUser(
      id: id,
      firstName: explicitFirst ?? (parts.isEmpty ? '' : parts.first),
      lastName:
          explicitLast ?? (parts.length < 2 ? '' : parts.skip(1).join(' ')),
      name: fullName.isNotEmpty
          ? fullName
          : [explicitFirst, explicitLast].whereType<String>().join(' '),
      email: (_nullableText(data['email']) ?? '').toLowerCase(),
      role: role,
      schoolRole: role == UserRole.school ? schoolRole : null,
      healthRole: role == UserRole.health ? healthRole : null,
      needsNormalization: needsNormalization,
      institutionIds: ids(data['institutionIds']),
      studentIds: ids(data['studentIds']),
      // Igual ao login e às regras: só `active == true` é ativo (P0-04).
      active: data['active'] == true,
      professionalId: _nullableText(data['professionalId']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      lastAccessAt: _date(data['lastAccessAt']),
      createdBy: _nullableText(data['createdBy']),
    );
  }

  String get accessLabel {
    final label =
        accessLabelFor(role, schoolRole: schoolRole, healthRole: healthRole);
    return needsNormalization ? '$label • Perfil a normalizar' : label;
  }
}

class UserFormData {
  const UserFormData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.active,
    this.schoolRole,
    this.healthRole,
    this.professionalId,
    this.institutionIds = const [],
    this.studentId,
  });

  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final SchoolRole? schoolRole;
  final HealthRole? healthRole;
  final bool active;
  final String? professionalId;

  /// Instituições de atuação (Escola/Saúde). Geram o cadastro profissional.
  final List<String> institutionIds;

  /// Estudante vinculado (Família, uma conta por estudante no MVP).
  final String? studentId;

  bool get isOperational =>
      role == UserRole.school || role == UserRole.health;

  /// Tipo de instituição aceito pelo perfil (D-A01).
  InstitutionType? get requiredInstitutionType => switch (role) {
        UserRole.school => InstitutionType.school,
        UserRole.health => InstitutionType.ubs,
        _ => null,
      };

  /// Vínculos obrigatórios por perfil (D-03, D-10).
  /// Máximo de instituições por perfil (as regras verificam cada uma, P2-05).
  static const maxInstitutions = 5;

  String? get missingLinkMessage {
    if (isOperational && institutionIds.isEmpty) {
      return 'Selecione ao menos uma instituição de atuação.';
    }
    if (isOperational && institutionIds.length > maxInstitutions) {
      return 'Selecione no máximo $maxInstitutions instituições de atuação.';
    }
    if (role == UserRole.family && studentId == null) {
      return 'Selecione o estudante vinculado à conta familiar.';
    }
    return null;
  }

  String get normalizedEmail => email.trim().toLowerCase();
  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();

  /// Subrole coerente com a role, sem padrão implícito (D-08).
  String? get schoolRoleValue =>
      role == UserRole.school ? schoolRole?.value : null;
  String? get healthRoleValue =>
      role == UserRole.health ? healthRole?.value : null;

  /// Role exige subrole: Escola e Saúde não são salvas sem ela.
  bool get hasRequiredSubrole => switch (role) {
        UserRole.school => schoolRole != null,
        UserRole.health => healthRole != null,
        _ => true,
      };

  Map<String, Object?> toCallableMap({String? uid}) => {
        if (uid != null) 'uid': uid,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': normalizedEmail,
        'role': role.value,
        'schoolRole': schoolRoleValue,
        'healthRole': healthRoleValue,
        'active': active,
        'professionalId': professionalId,
      };
}

class Address {
  const Address({
    required this.street,
    required this.number,
    required this.district,
    required this.city,
    required this.state,
    required this.zipCode,
    this.complement,
  });

  final String street;
  final String number;
  final String? complement;
  final String district;
  final String city;
  final String state;
  final String zipCode;

  factory Address.fromMap(Object? raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return Address(
      street: _nullableText(map['street']) ?? '',
      number: _nullableText(map['number']) ?? '',
      complement: _nullableText(map['complement']),
      district: _nullableText(map['district']) ?? '',
      city: _nullableText(map['city']) ?? '',
      state: _nullableText(map['state']) ?? '',
      zipCode: _nullableText(map['zipCode']) ?? '',
    );
  }

  Map<String, Object?> toMap() => {
        'street': street.trim(),
        'number': number.trim(),
        'complement': _nullableText(complement),
        'district': district.trim(),
        'city': city.trim(),
        'state': state.trim().toUpperCase(),
        'zipCode': zipCode.trim(),
      };

  String get formatted => [
        [street, number].where((e) => e.isNotEmpty).join(', '),
        district,
        [city, state].where((e) => e.isNotEmpty).join(' - '),
      ].where((e) => e.isNotEmpty).join(' • ');
}

/// Tipos controlados de instituição: as regras exigem `ubs` no destino dos
/// encaminhamentos e `school` nos casos (P0-03).
enum InstitutionType {
  school('school', 'Escola'),
  ubs('ubs', 'UBS');

  const InstitutionType(this.value, this.label);
  final String value;
  final String label;

  static InstitutionType? fromValue(String? value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// Rótulo em português; valores antigos em texto livre aparecem como estão.
String institutionTypeLabel(String raw) =>
    InstitutionType.fromValue(raw)?.label ?? (raw.isEmpty ? 'Sem tipo' : raw);

class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.active,
    this.cnpj,
    this.email,
    this.phone,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final String type;
  final String? cnpj;
  final String? email;
  final String? phone;
  final Address address;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory Institution.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Institution(
      id: doc.id,
      name: _nullableText(data['name']) ?? '',
      type: _nullableText(data['type']) ?? '',
      cnpj: _nullableText(data['cnpj']),
      email: _nullableText(data['email']),
      phone: _nullableText(data['phone']),
      address: Address.fromMap(data['address']),
      active: data['active'] != false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _nullableText(data['createdBy']),
    );
  }

  Map<String, Object?> toMap() => {
        'name': name.trim(),
        'type': type.trim(),
        'cnpj': _nullableText(cnpj),
        'email': _nullableText(email)?.toLowerCase(),
        'phone': _nullableText(phone),
        'address': address.toMap(),
        'active': active,
      };
}

class Professional {
  const Professional({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.institutionIds,
    required this.active,
    this.email,
    this.phone,
    this.specialty,
    this.registrationNumber,
    this.userId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String name;
  final String? email;
  final String? phone;
  final String? specialty;
  final String? registrationNumber;
  final String? userId;
  final List<String> institutionIds;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory Professional.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = _nullableText(data['name']) ?? '';
    final parts =
        name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return Professional(
      id: doc.id,
      firstName: _nullableText(data['firstName']) ??
          (parts.isEmpty ? '' : parts.first),
      lastName: _nullableText(data['lastName']) ??
          (parts.length < 2 ? '' : parts.skip(1).join(' ')),
      name: name,
      email: _nullableText(data['email']),
      phone: _nullableText(data['phone']),
      specialty: _nullableText(data['specialty']),
      registrationNumber: _nullableText(data['registrationNumber']),
      userId: _nullableText(data['userId']),
      institutionIds: List<String>.unmodifiable(
        (data['institutionIds'] as List? ?? const []).whereType<String>(),
      ),
      active: data['active'] != false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _nullableText(data['createdBy']),
    );
  }

  Map<String, Object?> toMap() => {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'name': '${firstName.trim()} ${lastName.trim()}'.trim(),
        'email': _nullableText(email)?.toLowerCase(),
        'phone': _nullableText(phone),
        'specialty': _nullableText(specialty),
        'registrationNumber': _nullableText(registrationNumber),
        'userId': _nullableText(userId),
        'institutionIds': institutionIds,
        'active': active,
      };
}

class LocalNetwork {
  const LocalNetwork({
    required this.id,
    required this.name,
    required this.institutionIds,
    required this.active,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String name;
  final String? description;
  final List<String> institutionIds;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory LocalNetwork.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return LocalNetwork(
      id: doc.id,
      name: _nullableText(data['name']) ?? '',
      description: _nullableText(data['description']),
      institutionIds: List<String>.unmodifiable(
        (data['institutionIds'] as List? ?? const []).whereType<String>(),
      ),
      active: data['active'] != false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      createdBy: _nullableText(data['createdBy']),
    );
  }

  Map<String, Object?> toMap() => {
        'name': name.trim(),
        'description': _nullableText(description),
        'institutionIds': institutionIds,
        'active': active,
      };
}

class AdminParameter {
  const AdminParameter({
    required this.id,
    required this.title,
    required this.items,
    required this.active,
  });

  final String id;
  final String title;
  final List<String> items;
  final bool active;

  factory AdminParameter.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminParameter(
      id: doc.id,
      title: _nullableText(data['title']) ?? '',
      items: List<String>.unmodifiable(
        (data['items'] as List? ?? const []).whereType<String>(),
      ),
      active: data['active'] != false,
    );
  }
}

/// Registro de `adminAuditLogs` exibido ao admin (P1-12). Os campos `before`
/// e `after` não são mostrados: só o resumo da ação.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.actorUid,
    required this.targetType,
    required this.targetId,
    this.createdAt,
  });

  factory AuditEntry.fromMap(String id, Map<String, dynamic> data) {
    return AuditEntry(
      id: id,
      action: data['action'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      targetType: data['targetType'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      createdAt: _date(data['createdAt']),
    );
  }

  final String id;
  final String action;
  final String actorUid;
  final String targetType;
  final String targetId;
  final DateTime? createdAt;

  static const _actions = {
    'user.create': 'Usuário criado',
    'user.update': 'Usuário atualizado',
    'user.role.update': 'Perfil de acesso alterado',
    'user.activate': 'Usuário reativado',
    'user.deactivate': 'Usuário desativado',
    'association.update': 'Vínculo atualizado',
    'institution.create': 'Instituição cadastrada',
    'institution.update': 'Instituição atualizada',
    'professional.create': 'Profissional cadastrado',
    'professional.update': 'Profissional atualizado',
    'localNetwork.create': 'Rede local cadastrada',
    'localNetwork.update': 'Rede local atualizada',
    'parameter.create': 'Parâmetro cadastrado',
    'parameter.update': 'Parâmetro atualizado',
  };

  static const _targets = {
    'user': 'Usuário',
    'institution': 'Instituição',
    'professional': 'Profissional',
    'localNetwork': 'Rede local',
    'parameter': 'Parâmetro',
    'student': 'Estudante',
  };

  String get actionLabel => _actions[action] ?? action;
  String get targetTypeLabel => _targets[targetType] ?? targetType;
}
