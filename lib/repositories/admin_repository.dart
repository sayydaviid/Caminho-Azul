import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_models.dart';
import '../models/student_models.dart';
import '../services/auth_service.dart';

class AdminRepositoryException implements Exception {
  const AdminRepositoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AdminRepository {
  Stream<List<Institution>> watchInstitutions();
  Stream<List<Professional>> watchProfessionals();
  Stream<List<LocalNetwork>> watchLocalNetworks();
  Stream<List<AdminUser>> watchUsers();
  Stream<List<AdminParameter>> watchParameters();

  /// P1-12: consulta somente leitura da auditoria (mais recentes primeiro).
  Stream<List<AuditEntry>> watchAuditLogs({int limit = 200});
  Future<List<Institution>> getActiveInstitutions();
  Future<List<Institution>> getInstitutions();
  Future<List<Professional>> getProfessionals();
  Future<List<AdminUser>> getUsers();
  Future<List<Student>> getStudents();
  Future<void> createUserProfile(
    String uid,
    UserFormData value, {
    required String actorUid,
  });
  Future<void> updateUser(
    AdminUser user,
    UserFormData value, {
    required String actorUid,
  });
  Future<void> deleteUser(
    AdminUser user, {
    required String actorUid,
  });
  Future<void> saveInstitution(Institution value, {required String actorUid});
  Future<void> saveProfessional(Professional value, {required String actorUid});
  Future<void> saveLocalNetwork(LocalNetwork value, {required String actorUid});
  Future<void> saveParameter(AdminParameter value, {required String actorUid});
}

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Institution>> watchInstitutions() => _firestore
      .collection('institutions')
      .snapshots()
      .map((event) => _sorted(event.docs.map(Institution.fromFirestore)));

  @override
  Stream<List<Professional>> watchProfessionals() => _firestore
      .collection('professionals')
      .snapshots()
      .map((event) => _sorted(event.docs.map(Professional.fromFirestore)));

  @override
  Stream<List<LocalNetwork>> watchLocalNetworks() => _firestore
      .collection('localNetworks')
      .snapshots()
      .map((event) => _sorted(event.docs.map(LocalNetwork.fromFirestore)));

  @override
  Stream<List<AdminUser>> watchUsers() => _firestore
      .collection('users')
      .snapshots()
      .map((event) => _sorted(event.docs.map(AdminUser.fromFirestore)));

  @override
  Stream<List<AuditEntry>> watchAuditLogs({int limit = 200}) => _firestore
      .collection('adminAuditLogs')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => List.unmodifiable(snapshot.docs
          .map((doc) => AuditEntry.fromMap(doc.id, doc.data()))));

  @override
  Stream<List<AdminParameter>> watchParameters() => _firestore
      .collection('adminParameters')
      .snapshots()
      .map((event) => _sorted(event.docs.map(AdminParameter.fromFirestore)));

  List<T> _sorted<T>(Iterable<T> values) {
    final list = values.toList();
    list.sort((a, b) {
      final first = switch (a) {
        Institution(:final name) => name,
        Professional(:final name) => name,
        LocalNetwork(:final name) => name,
        AdminUser(:final name) => name,
        AdminParameter(:final title) => title,
        _ => '',
      };
      final second = switch (b) {
        Institution(:final name) => name,
        Professional(:final name) => name,
        LocalNetwork(:final name) => name,
        AdminUser(:final name) => name,
        AdminParameter(:final title) => title,
        _ => '',
      };
      return first.toLowerCase().compareTo(second.toLowerCase());
    });
    return List.unmodifiable(list);
  }

  @override
  Future<List<Institution>> getActiveInstitutions() async {
    final snapshot = await _firestore
        .collection('institutions')
        .where('active', isEqualTo: true)
        .get();
    return _sorted(snapshot.docs.map(Institution.fromFirestore));
  }

  @override
  Future<List<Institution>> getInstitutions() async {
    final snapshot = await _firestore.collection('institutions').get();
    return _sorted(snapshot.docs.map(Institution.fromFirestore));
  }

  @override
  Future<List<Professional>> getProfessionals() async {
    final snapshot = await _firestore.collection('professionals').get();
    return _sorted(snapshot.docs.map(Professional.fromFirestore));
  }

  @override
  Future<List<AdminUser>> getUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return _sorted(snapshot.docs.map(AdminUser.fromFirestore));
  }

  @override
  Future<List<Student>> getStudents() async {
    final snapshot = await _firestore.collection('students').get();
    final list = snapshot.docs.map(Student.fromFirestore).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(list);
  }

  @override
  Future<void> createUserProfile(
    String uid,
    UserFormData value, {
    required String actorUid,
  }) async {
    _requireSubrole(value);
    _requireLinks(value);
    final userRef = _firestore.collection('users').doc(uid);
    final existing = await userRef.get();
    if (existing.exists) {
      throw const AdminRepositoryException('Este usuário já está cadastrado.');
    }
    if (value.isOperational) {
      await _ensureActiveInstitutions(value.institutionIds,
          type: value.requiredInstitutionType);
    }
    final batch = _firestore.batch();
    String? professionalId;
    if (value.isOperational) {
      professionalId = _createProfessional(batch, uid, value, actorUid);
    }
    if (value.role == UserRole.family) {
      await _linkStudent(batch, value.studentId!, uid, actorUid);
    }

    final after = <String, Object?>{
      'firstName': value.firstName.trim(),
      'lastName': value.lastName.trim(),
      'name': value.fullName,
      'email': value.normalizedEmail,
      'role': value.role.value,
      'schoolRole': value.schoolRoleValue,
      'healthRole': value.healthRoleValue,
      'active': value.active,
      'professionalId': professionalId,
      'institutionIds': value.isOperational ? value.institutionIds : <String>[],
      'studentIds': value.role == UserRole.family
          ? <String>[value.studentId!]
          : <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': actorUid,
      'lastAccessAt': null,
    };
    final auditId = _newAuditId();
    batch.set(userRef, {...after, 'lastAuditId': auditId});
    _addAudit(
      batch,
      id: auditId,
      action: 'user.create',
      actorUid: actorUid,
      targetType: 'user',
      targetId: uid,
      before: null,
      after: after,
    );
    await batch.commit();
  }

  @override
  Future<void> updateUser(
    AdminUser user,
    UserFormData value, {
    required String actorUid,
  }) async {
    if (user.id == actorUid &&
        (!value.active || value.role != UserRole.administration)) {
      throw const AdminRepositoryException(
        'Você não pode desativar a própria conta nem remover sua role administrativa.',
      );
    }
    _requireSubrole(value);
    if (value.normalizedEmail != user.email.trim().toLowerCase()) {
      throw const AdminRepositoryException(
        'O e-mail de uma conta existente não pode ser alterado sem um servidor administrativo.',
      );
    }
    _requireLinks(value);
    if (value.isOperational) {
      await _ensureActiveInstitutions(value.institutionIds,
          type: value.requiredInstitutionType);
    }

    final userRef = _firestore.collection('users').doc(user.id);
    final before = await userRef.get();
    if (!before.exists) {
      throw const AdminRepositoryException('Usuário não encontrado.');
    }
    final data = before.data() ?? const <String, dynamic>{};
    final oldProfessionalId = data['professionalId'] as String?;
    final oldStudentIds =
        (data['studentIds'] as List? ?? const []).whereType<String>().toList();
    final professionals = _firestore.collection('professionals');
    final batch = _firestore.batch();
    // P2-05: um log principal referenciado por lastAuditId; os complementares
    // (role, status, vínculos) usam o mesmo id com sufixo.
    final auditId = _newAuditId();

    var professionalId = oldProfessionalId;
    if (value.isOperational) {
      if (oldProfessionalId == null) {
        professionalId = _createProfessional(batch, user.id, value, actorUid);
      } else {
        batch.update(professionals.doc(oldProfessionalId), {
          'firstName': value.firstName.trim(),
          'lastName': value.lastName.trim(),
          'name': value.fullName,
          'userId': user.id,
          'institutionIds': value.institutionIds,
          'role': value.role.value,
          'subrole': value.schoolRoleValue ?? value.healthRoleValue,
          'active': value.active, // D-A06: acompanha a conta
          'updatedAt': FieldValue.serverTimestamp(),
          'lastAuditId': auditId,
        });
      }
    } else if (oldProfessionalId != null) {
      batch.update(professionals.doc(oldProfessionalId), {
        'userId': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAuditId': auditId,
      });
      professionalId = null;
    }

    final newStudentIds =
        value.role == UserRole.family ? <String>[value.studentId!] : <String>[];
    for (final studentId in oldStudentIds) {
      if (newStudentIds.contains(studentId)) continue;
      batch.update(_firestore.collection('students').doc(studentId), {
        'familyUid': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actorUid,
      });
    }
    for (final studentId in newStudentIds) {
      if (oldStudentIds.contains(studentId)) continue;
      await _linkStudent(batch, studentId, user.id, actorUid);
    }

    final after = <String, Object?>{
      'firstName': value.firstName.trim(),
      'lastName': value.lastName.trim(),
      'name': value.fullName,
      'role': value.role.value,
      'schoolRole': value.schoolRoleValue,
      'healthRole': value.healthRoleValue,
      'active': value.active,
      'professionalId': professionalId,
      'institutionIds': value.isOperational ? value.institutionIds : <String>[],
      'studentIds': newStudentIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.update(userRef, {...after, 'lastAuditId': auditId});
    _addAudit(
      batch,
      id: auditId,
      action: 'user.update',
      actorUid: actorUid,
      targetType: 'user',
      targetId: user.id,
      before: before.data(),
      after: after,
    );
    if (user.needsNormalization ||
        user.role != value.role ||
        user.schoolRole != value.schoolRole ||
        user.healthRole != value.healthRole) {
      _addAudit(
        batch,
        id: '$auditId-role',
        action: 'user.role.update',
        actorUid: actorUid,
        targetType: 'user',
        targetId: user.id,
        before: {
          'role': before.data()?['role'],
          'schoolRole': before.data()?['schoolRole'],
          'healthRole': before.data()?['healthRole'],
        },
        after: {
          'role': value.role.value,
          'schoolRole': value.schoolRoleValue,
          'healthRole': value.healthRoleValue,
        },
      );
    }
    if (user.active != value.active) {
      _addAudit(
        batch,
        id: '$auditId-active',
        action: value.active ? 'user.activate' : 'user.deactivate',
        actorUid: actorUid,
        targetType: 'user',
        targetId: user.id,
        before: {'active': user.active},
        after: {'active': value.active},
      );
    }
    final oldInstitutions =
        (data['institutionIds'] as List? ?? const []).whereType<String>();
    if (oldProfessionalId != professionalId ||
        oldInstitutions.join('|') != (after['institutionIds'] as List).join('|') ||
        oldStudentIds.join('|') != newStudentIds.join('|')) {
      _addAudit(
        batch,
        id: '$auditId-assoc',
        action: 'association.update',
        actorUid: actorUid,
        targetType: 'user',
        targetId: user.id,
        before: {
          'professionalId': oldProfessionalId,
          'institutionIds': oldInstitutions.toList(),
          'studentIds': oldStudentIds,
        },
        after: {
          'professionalId': professionalId,
          'institutionIds': after['institutionIds'],
          'studentIds': newStudentIds,
        },
      );
    }
    await batch.commit();
  }

  /// "Excluir usuário" = desativação lógica (D-04, D-15): `active: false`,
  /// histórico, vínculos e auditoria preservados; a identidade continua no
  /// Authentication (remoção definitiva só manual, no Console).
  @override
  Future<void> deleteUser(
    AdminUser user, {
    required String actorUid,
  }) async {
    if (user.id == actorUid) {
      throw const AdminRepositoryException(
        'Você não pode desativar a própria conta administrativa.',
      );
    }
    final userRef = _firestore.collection('users').doc(user.id);
    final before = await userRef.get();
    if (!before.exists) {
      throw const AdminRepositoryException('Usuário não encontrado.');
    }
    if (before.data()?['active'] != true) {
      throw const AdminRepositoryException('Esta conta já está desativada.');
    }
    final auditId = _newAuditId();
    final batch = _firestore.batch()
      ..update(userRef, {
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAuditId': auditId,
      });
    // D-A06: o cadastro profissional acompanha a conta, para a pessoa sair
    // das listas de atribuição (psicólogos) e de vínculo (professores).
    final professionalId = before.data()?['professionalId'] as String?;
    if (professionalId != null) {
      batch.update(_firestore.collection('professionals').doc(professionalId), {
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAuditId': auditId,
      });
    }
    _addAudit(
      batch,
      id: auditId,
      action: 'user.deactivate',
      actorUid: actorUid,
      targetType: 'user',
      targetId: user.id,
      before: {'active': true},
      after: {'active': false, 'via': 'excluir-usuario'},
    );
    await batch.commit();
  }

  @override
  Future<void> saveInstitution(
    Institution value, {
    required String actorUid,
  }) async {
    final collection = _firestore.collection('institutions');
    final ref = value.id.isEmpty ? collection.doc() : collection.doc(value.id);
    final before = await ref.get();
    final auditId = _newAuditId();
    final data = <String, Object?>{
      ...value.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastAuditId': auditId,
      if (!before.exists) ...{
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': actorUid,
      },
    };
    final batch = _firestore.batch()..set(ref, data, SetOptions(merge: true));
    _addAudit(
      batch,
      id: auditId,
      action: before.exists ? 'institution.update' : 'institution.create',
      actorUid: actorUid,
      targetType: 'institution',
      targetId: ref.id,
      before: before.data(),
      after: value.toMap(),
    );
    await batch.commit();
  }

  @override
  Future<void> saveProfessional(
    Professional value, {
    required String actorUid,
  }) async {
    if (value.institutionIds.length > maxInstitutionsPerProfile) {
      throw const AdminRepositoryException(
          'Selecione no máximo $maxInstitutionsPerProfile instituições.');
    }
    final professionals = _firestore.collection('professionals');
    final ref =
        value.id.isEmpty ? professionals.doc() : professionals.doc(value.id);
    final before = await ref.get();
    final previousUserId = before.data()?['userId'] as String?;
    final nextUserId = value.userId;

    if (nextUserId == null) {
      throw const AdminRepositoryException(
        'Selecione o usuário vinculado ao profissional.',
      );
    }
    final duplicates =
        await professionals.where('userId', isEqualTo: nextUserId).get();
    if (duplicates.docs.any((doc) => doc.id != ref.id)) {
      throw const AdminRepositoryException(
        'Este usuário já está vinculado a outro profissional.',
      );
    }
    final user = await _firestore.collection('users').doc(nextUserId).get();
    final userData = user.data();
    if (!user.exists || userData == null || userData['active'] != true) {
      throw const AdminRepositoryException(
        'Selecione um usuário existente e ativo.',
      );
    }
    final linkedProfessional = userData['professionalId'] as String?;
    if (linkedProfessional != null && linkedProfessional != ref.id) {
      throw const AdminRepositoryException(
        'Este usuário já está vinculado a outro profissional.',
      );
    }
    // D-A01 / P2-05: tipo de instituição conforme a role da conta.
    final role = userData['role'] as String?;
    final subrole = role == 'school'
        ? userData['schoolRole'] as String?
        : role == 'health'
            ? userData['healthRole'] as String?
            : null;
    await _ensureActiveInstitutions(value.institutionIds,
        type: role == 'school'
            ? InstitutionType.school
            : role == 'health'
                ? InstitutionType.ubs
                : null);

    String text(Object? field) => field is String ? field.trim() : '';
    final storedName = text(userData['name']);
    final nameParts = storedName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final firstName = text(userData['firstName']).isNotEmpty
        ? text(userData['firstName'])
        : nameParts.firstOrNull ?? '';
    final lastName = text(userData['lastName']).isNotEmpty
        ? text(userData['lastName'])
        : nameParts.skip(1).join(' ');
    final fullName =
        storedName.isNotEmpty ? storedName : '$firstName $lastName'.trim();
    final email = text(userData['email']).toLowerCase();
    if (fullName.isEmpty || email.isEmpty) {
      throw const AdminRepositoryException(
        'O usuário selecionado possui nome ou e-mail incompleto.',
      );
    }
    final professionalData = <String, Object?>{
      ...value.toMap(),
      'firstName': firstName,
      'lastName': lastName,
      'name': fullName,
      'email': email,
      'userId': nextUserId,
      // Mesma função da conta: as listas de professores e psicólogos usam
      // role/subrole do profissional (as regras conferem).
      if (subrole != null) ...{'role': role, 'subrole': subrole},
    };

    final auditId = _newAuditId();
    final data = <String, Object?>{
      ...professionalData,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastAuditId': auditId,
      if (!before.exists) ...{
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': actorUid,
      },
    };
    final batch = _firestore.batch()..set(ref, data, SetOptions(merge: true));
    if (previousUserId != null && previousUserId != nextUserId) {
      batch.update(_firestore.collection('users').doc(previousUserId), {
        'professionalId': null,
        'institutionIds': <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAuditId': auditId,
      });
    }
    batch.update(_firestore.collection('users').doc(nextUserId), {
      'professionalId': ref.id,
      'institutionIds': value.institutionIds,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastAuditId': auditId,
    });
    _addAudit(
      batch,
      id: auditId,
      action: before.exists ? 'professional.update' : 'professional.create',
      actorUid: actorUid,
      targetType: 'professional',
      targetId: ref.id,
      before: before.data(),
      after: professionalData,
    );
    await batch.commit();
  }

  @override
  Future<void> saveLocalNetwork(
    LocalNetwork value, {
    required String actorUid,
  }) async {
    await _ensureActiveInstitutions(value.institutionIds);
    final collection = _firestore.collection('localNetworks');
    final ref = value.id.isEmpty ? collection.doc() : collection.doc(value.id);
    final before = await ref.get();
    final auditId = _newAuditId();
    final data = <String, Object?>{
      ...value.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastAuditId': auditId,
      if (!before.exists) ...{
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': actorUid,
      },
    };
    final batch = _firestore.batch()..set(ref, data, SetOptions(merge: true));
    _addAudit(
      batch,
      id: auditId,
      action: before.exists ? 'localNetwork.update' : 'localNetwork.create',
      actorUid: actorUid,
      targetType: 'localNetwork',
      targetId: ref.id,
      before: before.data(),
      after: value.toMap(),
    );
    await batch.commit();
  }

  @override
  Future<void> saveParameter(
    AdminParameter value, {
    required String actorUid,
  }) async {
    final collection = _firestore.collection('adminParameters');
    final ref = value.id.isEmpty ? collection.doc() : collection.doc(value.id);
    final before = await ref.get();
    final after = <String, Object?>{
      'title': value.title.trim(),
      'items': value.items,
      'active': value.active,
    };
    final auditId = _newAuditId();
    final batch = _firestore.batch()
      ..set(
          ref,
          {
            ...after,
            'updatedAt': FieldValue.serverTimestamp(),
            'lastAuditId': auditId,
            if (!before.exists) ...{
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': actorUid,
            },
          },
          SetOptions(merge: true));
    _addAudit(
      batch,
      id: auditId,
      action: before.exists ? 'parameter.update' : 'parameter.create',
      actorUid: actorUid,
      targetType: 'parameter',
      targetId: ref.id,
      before: before.data(),
      after: after,
    );
    await batch.commit();
  }

  void _requireSubrole(UserFormData value) {
    if (!value.hasRequiredSubrole) {
      throw const AdminRepositoryException(
        'Selecione a função do usuário na Escola ou na Saúde.',
      );
    }
  }

  Future<void> _ensureActiveInstitutions(List<String> ids,
      {InstitutionType? type}) async {
    if (ids.isEmpty) return;
    final docs = await Future.wait(
      ids.map((id) => _firestore.collection('institutions').doc(id).get()),
    );
    if (docs.any((doc) => !doc.exists || doc.data()?['active'] != true)) {
      throw const AdminRepositoryException(
        'Uma das instituições selecionadas não está mais ativa.',
      );
    }
    // D-A01: Escola só atua em escolas; Saúde só em UBS.
    if (type != null && docs.any((doc) => doc.data()?['type'] != type.value)) {
      throw AdminRepositoryException(type == InstitutionType.school
          ? 'Perfis da Escola só podem ser vinculados a escolas.'
          : 'Perfis da Saúde só podem ser vinculados a UBS.');
    }
  }

  void _requireLinks(UserFormData value) {
    final message = value.missingLinkMessage;
    if (message != null) throw AdminRepositoryException(message);
  }

  /// Limite imposto pelas regras (verificação de tipo por índice, P2-05).
  static const maxInstitutionsPerProfile = UserFormData.maxInstitutions;

  /// Cadastro profissional obrigatório de contas da Escola e da Saúde (D-03).
  String _createProfessional(
    WriteBatch batch,
    String uid,
    UserFormData value,
    String actorUid,
  ) {
    final ref = _firestore.collection('professionals').doc();
    final auditId = _newAuditId();
    final data = <String, Object?>{
      'firstName': value.firstName.trim(),
      'lastName': value.lastName.trim(),
      'name': value.fullName,
      'email': value.normalizedEmail,
      'phone': null,
      'specialty': null,
      'registrationNumber': null,
      'userId': uid,
      'institutionIds': value.institutionIds,
      // Função copiada do perfil: permite listar professores e psicólogos.
      'role': value.role.value,
      'subrole': value.schoolRoleValue ?? value.healthRoleValue,
      'active': value.active, // D-A06: acompanha a conta
    };
    batch.set(ref, {
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': actorUid,
      'lastAuditId': auditId,
    });
    _addAudit(
      batch,
      id: auditId,
      action: 'professional.create',
      actorUid: actorUid,
      targetType: 'professional',
      targetId: ref.id,
      before: null,
      after: data,
    );
    return ref.id;
  }

  /// Uma conta familiar por estudante (D-10).
  Future<void> _linkStudent(
    WriteBatch batch,
    String studentId,
    String familyUid,
    String actorUid,
  ) async {
    final ref = _firestore.collection('students').doc(studentId);
    final student = await ref.get();
    if (!student.exists) {
      throw const AdminRepositoryException('Estudante não encontrado.');
    }
    final current = student.data()?['familyUid'] as String?;
    if (current != null && current != familyUid) {
      throw const AdminRepositoryException(
        'Este estudante já possui uma conta familiar vinculada.',
      );
    }
    batch.update(ref, {
      'familyUid': familyUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorUid,
    });
  }

  /// Id de log sem hífen (as regras aceitam os sufixos -role/-active/-assoc).
  String _newAuditId() => _firestore.collection('adminAuditLogs').doc().id;

  void _addAudit(
    WriteBatch batch, {
    required String id,
    required String action,
    required String actorUid,
    required String targetType,
    required String targetId,
    required Map<String, dynamic>? before,
    required Map<String, Object?>? after,
  }) {
    final ref = _firestore.collection('adminAuditLogs').doc(id);
    batch.set(ref, {
      'action': action,
      'actorUid': actorUid,
      'targetType': targetType,
      'targetId': targetId,
      'before': before,
      'after': after,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
