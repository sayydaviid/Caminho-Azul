'use strict';

// Testes das Security Rules do domínio (P0-03). Somente Firestore Emulator, projeto demo-*.
// Usa as contas sintéticas do seed (scripts/seed/data.js) com os valores canônicos em inglês
// (D-08), além de variantes em português, sem subrole e inativa, que NÃO podem operar.

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const {
  Timestamp, collection, deleteDoc, deleteField, doc, getDoc, getDocs, query, serverTimestamp,
  setDoc, updateDoc, where, writeBatch,
} = require('firebase/firestore');
const data = require('../seed/data');

const EN = data.ROLE_VALUES.CANONICAL_EN;
const PAST = Timestamp.fromDate(new Date('2026-01-01T12:00:00Z'));
const CASE = 'case-1';
const S1 = data.STUDENT_ID;

// Contas extras para cenários de vínculo, transferência e transição de roles.
const extraUsers = [
  { uid: 'seed-professor-2', email: 'professor2@caminhoazul.test', first: 'Professor', last: 'Dois Sintético', role: 'school', schoolRole: 'teacher', institutions: ['seed-escola-a'] },
  { uid: 'seed-familia-b', email: 'familia.b@caminhoazul.test', first: 'Família', last: 'B Sintética', role: 'family', studentIds: ['seed-estudante-2'] },
  { uid: 'seed-professor-inativo', email: 'prof.inativo@caminhoazul.test', first: 'Professor', last: 'Inativo', role: 'school', schoolRole: 'teacher', institutions: ['seed-escola-a'], active: false },
];
const allUsers = [...data.users, ...extraUsers];
const byUid = Object.fromEntries(allUsers.map((u) => [u.uid, u]));
const ACTOR_ROLE = {
  'school:teacher': 'school/teacher', 'school:director': 'school/director',
  'health:ubsDirector': 'health/ubs_director', 'health:psychologist': 'health/psychologist',
};

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-caminhoazul',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8') },
  });
});

test.after(async () => env.cleanup());

test.beforeEach(async () => {
  await env.clearFirestore();
  await asAdminSdk(async (db) => {
    const stamps = { createdAt: PAST, updatedAt: PAST };
    for (const inst of data.institutions) {
      await setDoc(doc(db, `institutions/${inst.id}`), { name: inst.name, type: inst.type, active: true, createdBy: 'seed-admin', ...stamps });
    }
    for (const user of allUsers) {
      if (user.noProfile) continue;
      await setDoc(doc(db, `users/${user.uid}`), data.userDoc(user, EN, stamps));
    }
    // Variantes que não podem operar no domínio.
    const legacy = data.ROLE_VALUES.LEGACY_PT;
    await setDoc(doc(db, 'users/pt-professor'), { ...data.userDoc(byUid['seed-professor'], legacy, stamps), name: 'PT Professor' });
    await setDoc(doc(db, 'users/pt-diretor'), { ...data.userDoc(byUid['seed-diretor-escola'], legacy, stamps), name: 'PT Diretor' });
    await setDoc(doc(db, 'users/saude-sem-subrole'), { ...data.userDoc(byUid['seed-diretor-ubs'], EN, stamps), healthRole: null, name: 'Sem Subrole' });

    const student = (id, name, school, familyUid) => setDoc(doc(db, `students/${id}`), {
      name, grade: '3º ano', schoolInstitutionId: school, familyUid, active: true,
      createdBy: 'seed-diretor-escola', updatedBy: 'seed-diretor-escola', ...stamps,
    });
    await student(S1, data.student.name, 'seed-escola-a', 'seed-familia');
    await student('seed-estudante-2', 'Estudante Sintético Dois', 'seed-escola-a', 'seed-familia-b');
    await student('seed-estudante-3', 'Estudante Sintético Três', 'seed-escola-b', null);
  });
});

// ---------------------------------------------------------------- helpers

async function asAdminSdk(fn) {
  await env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
}

const dbOf = (uid) => (uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore());

function eventData(uid, type, extra = {}) {
  const user = byUid[uid];
  const key = `${user.role}:${user.schoolRole || user.healthRole}`;
  return {
    type, visibility: 'familia', audience: [], referralId: null, refId: null,
    actorUid: uid, actorName: data.fullName(user), actorRole: ACTOR_ROLE[key],
    createdAt: serverTimestamp(), ...extra,
  };
}

function caseFixture(overrides = {}) {
  return {
    studentId: S1, studentName: data.student.name, schoolInstitutionId: 'seed-escola-a',
    primaryTeacherUid: 'seed-professor', teacherUids: ['seed-professor'], status: 'rascunho',
    familyVisible: false, complementOpen: false, approvedAt: null, approvedBy: null, activeReferrals: {},
    createdAt: PAST, updatedAt: PAST, createdBy: 'seed-professor', updatedBy: 'seed-professor',
    lastEventId: 'e0', ...overrides,
  };
}

function referralFixture(overrides = {}) {
  return {
    caseId: CASE, studentId: S1, studentName: data.student.name,
    originInstitutionId: 'seed-escola-a', destinationInstitutionId: 'seed-ubs-a',
    status: 'enviado', previousStatus: null, assignedPsychologistUid: null, assignedPsychologistName: null,
    createdAt: PAST, updatedAt: PAST, createdBy: 'seed-diretor-escola', updatedBy: 'seed-diretor-escola',
    lastEventId: 'r0', ...overrides,
  };
}

async function putCase(overrides) {
  await asAdminSdk(async (db) => {
    await setDoc(doc(db, `cases/${CASE}`), caseFixture(overrides));
    await setDoc(doc(db, `cases/${CASE}/timelineEvents/e0`), {
      type: 'case.created', visibility: 'familia', audience: [], referralId: null, refId: null,
      actorUid: 'seed-professor', actorName: 'Professor Sintético', actorRole: 'school/teacher', createdAt: PAST,
    });
    await setDoc(doc(db, `cases/${CASE}/timelineEvents/e-int`), {
      type: 'observation.created', visibility: 'interno', audience: [], referralId: null, refId: 'o0',
      actorUid: 'seed-professor', actorName: 'Professor Sintético', actorRole: 'school/teacher', createdAt: PAST,
    });
    await setDoc(doc(db, `cases/${CASE}/observations/o0`), {
      authorUid: 'seed-professor', authorName: 'Professor Sintético', context: 'Sala de aula',
      description: 'Observação sintética.', observedAt: PAST, createdAt: PAST, updatedAt: PAST,
    });
  });
}

async function putReferral(id, overrides = {}) {
  await asAdminSdk(async (db) => {
    const referral = referralFixture(overrides);
    await setDoc(doc(db, `referrals/${id}`), referral);
    if (!['finalizado', 'devolvido', 'recusado'].includes(referral.status)) {
      await updateDoc(doc(db, `cases/${CASE}`), { [`activeReferrals.${id}`]: referral.destinationInstitutionId });
    }
    await setDoc(doc(db, `referrals/${id}/private/details`), {
      reason: 'Motivo sintético', summary: 'Resumo mínimo sintético', createdAt: PAST, createdBy: 'seed-diretor-escola',
    });
    await setDoc(doc(db, `cases/${CASE}/timelineEvents/ev-${id}`), {
      type: 'referral.sent', visibility: 'familia', audience: [], referralId: id, refId: null,
      actorUid: 'seed-diretor-escola', actorName: 'Diretora Escolar Sintética', actorRole: 'school/director', createdAt: PAST,
    });
  });
}

// N-03: eventos relevantes e visíveis à família levam a notificação no mesmo batch.
const NOTIFIABLE = new Set(['case.approved', 'referral.sent', 'referral.received', 'referral.assigned',
  'referral.transferred', 'referral.statusChanged', 'referral.complementRequested', 'referral.returned',
  'referral.refused', 'healthReturn.created', 'referral.finalized', 'case.concluded']);

function notify(batch, db, uid, eventId, type, { referralId = null, visibility = 'familia', caseId = CASE, studentId = S1 } = {}) {
  if (!NOTIFIABLE.has(type) || visibility !== 'familia') return;
  batch.set(doc(db, `notifications/${caseId}_${eventId}`), {
    studentId, caseId, eventId, referralId, type, createdAt: serverTimestamp(), createdBy: uid, readAt: null,
  });
}

// Transição do caso no padrão do app: caso + evento no mesmo batch.
function caseTransition(uid, changes, type, eventId = `ev-${type}`, eventExtra = {}, { withNotification = true } = {}) {
  const db = dbOf(uid);
  const batch = writeBatch(db);
  batch.update(doc(db, `cases/${CASE}`), { ...changes, updatedAt: serverTimestamp(), updatedBy: uid, lastEventId: eventId });
  batch.set(doc(db, `cases/${CASE}/timelineEvents/${eventId}`), eventData(uid, type, eventExtra));
  if (withNotification) notify(batch, db, uid, eventId, type, { referralId: eventExtra.referralId || null, visibility: eventExtra.visibility || 'familia' });
  return batch.commit();
}

function referralTransition(uid, rid, changes, type, { eventId = `ev-${type}-${rid}`, note, caseChanges } = {}) {
  const db = dbOf(uid);
  const batch = writeBatch(db);
  batch.update(doc(db, `referrals/${rid}`), { ...changes, updatedAt: serverTimestamp(), updatedBy: uid, lastEventId: eventId });
  batch.set(doc(db, `cases/${CASE}/timelineEvents/${eventId}`), eventData(uid, type, { referralId: rid }));
  notify(batch, db, uid, eventId, type, { referralId: rid });
  if (note) {
    batch.set(doc(db, `referrals/${rid}/notes/${eventId}`), {
      kind: note.kind, text: 'Justificativa sintética', audience: note.audience,
      authorUid: uid, authorName: data.fullName(byUid[uid]), createdAt: serverTimestamp(),
    });
  }
  if (caseChanges) {
    batch.update(doc(db, `cases/${CASE}`), { ...caseChanges, updatedAt: serverTimestamp(), updatedBy: uid, lastEventId: eventId });
  }
  return batch.commit();
}

function teacherCreatesCase(uid, overrides = {}, { withEvent = true, withLock = true, eventOverrides = {} } = {}) {
  const db = dbOf(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, `cases/${CASE}`), {
    ...caseFixture({ primaryTeacherUid: uid, teacherUids: [uid], createdBy: uid, updatedBy: uid }),
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), lastEventId: 'ev-created', ...overrides,
  });
  if (withEvent) batch.set(doc(db, `cases/${CASE}/timelineEvents/ev-created`), eventData(uid, 'case.created', eventOverrides));
  if (withLock) {
    batch.set(doc(db, `caseLocks/${overrides.studentId || S1}`), {
      caseId: CASE, schoolInstitutionId: overrides.schoolInstitutionId || 'seed-escola-a',
      createdAt: serverTimestamp(), createdBy: uid,
    });
  }
  return batch.commit();
}

function directorSendsReferral(uid, rid, dest, { approveCase = true, withDetails = true, status = 'enviado', updateCase = true } = {}) {
  const db = dbOf(uid);
  const batch = writeBatch(db);
  const eventId = `ev-sent-${rid}`;
  batch.set(doc(db, `referrals/${rid}`), {
    ...referralFixture({ destinationInstitutionId: dest, status, createdBy: uid, updatedBy: uid }),
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), lastEventId: eventId,
  });
  if (withDetails) {
    batch.set(doc(db, `referrals/${rid}/private/details`), {
      reason: 'Motivo sintético', summary: 'Resumo mínimo', createdAt: serverTimestamp(), createdBy: uid,
    });
  }
  batch.set(doc(db, `cases/${CASE}/timelineEvents/${eventId}`), eventData(uid, 'referral.sent', { referralId: rid }));
  notify(batch, db, uid, eventId, 'referral.sent', { referralId: rid });
  if (updateCase) {
    batch.update(doc(db, `cases/${CASE}`), {
      [`activeReferrals.${rid}`]: dest, ...(approveCase ? { status: 'encaminhado' } : {}),
      updatedAt: serverTimestamp(), updatedBy: uid, lastEventId: eventId,
    });
  }
  return batch.commit();
}

function psychologistReturns(uid, rid, audience, { eventVisibility, eventAudience = [] } = {}) {
  const db = dbOf(uid);
  const batch = writeBatch(db);
  const id = `hr-${rid}`;
  batch.set(doc(db, `healthReturns/${id}`), {
    referralId: rid, caseId: CASE, studentId: S1, audience, content: 'Devolutiva sintética.',
    authorUid: uid, authorName: data.fullName(byUid[uid]), createdAt: serverTimestamp(),
  });
  batch.update(doc(db, `referrals/${rid}`), { status: 'devolutiva_registrada', updatedAt: serverTimestamp(), updatedBy: uid, lastEventId: id });
  const visibility = eventVisibility || (audience.includes('family') ? 'familia' : 'restrito');
  batch.set(doc(db, `cases/${CASE}/timelineEvents/${id}`), eventData(uid, 'healthReturn.created', {
    referralId: rid, refId: id, visibility, audience: visibility === 'restrito' ? ['school'] : eventAudience,
  }));
  notify(batch, db, uid, id, 'healthReturn.created', { referralId: rid, visibility });
  return batch.commit();
}

const read = (uid, p) => getDoc(doc(dbOf(uid), p));
const list = (uid, p, ...filters) => getDocs(query(collection(dbOf(uid), p), ...filters));

// ---------------------------------------------------------------- students

test('students: Direção cadastra só na própria escola; professor, PT e outra escola não', async () => {
  const student = (uid, extra = {}) => setDoc(doc(dbOf(uid), 'students/novo'), {
    name: 'Estudante Novo', grade: '1º ano', schoolInstitutionId: 'seed-escola-a', familyUid: null, active: true,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), createdBy: uid, updatedBy: uid, ...extra,
  });
  await assertFails(student('seed-diretor-escola-b'));
  await assertFails(student('seed-professor'));
  await assertFails(student('pt-diretor'));
  await assertFails(student('seed-admin'));
  await assertFails(student('seed-diretor-escola', { familyUid: 'seed-familia' }));
  await assertFails(student('seed-diretor-escola', { createdBy: 'seed-admin' }));
  await assertFails(student('seed-diretor-escola', { createdAt: PAST }));
  await assertSucceeds(student('seed-diretor-escola'));
});

test('students: leitura por vínculo institucional, família própria e admin', async () => {
  await assertSucceeds(read('seed-professor', `students/${S1}`));
  await assertSucceeds(read('seed-diretor-escola', `students/${S1}`));
  await assertSucceeds(read('seed-familia', `students/${S1}`));
  await assertSucceeds(read('seed-admin', `students/${S1}`));
  for (const uid of ['seed-professor-b', 'seed-diretor-escola-b', 'seed-familia-b', 'seed-diretor-ubs',
    'seed-psicologo', 'seed-inativo', 'seed-professor-inativo', 'seed-sem-perfil', 'pt-professor', null]) {
    await assertFails(read(uid, `students/${S1}`));
  }
  await assertSucceeds(list('seed-professor', 'students', where('schoolInstitutionId', '==', 'seed-escola-a')));
  await assertFails(list('seed-professor', 'students'));
  await assertFails(list('seed-professor-b', 'students', where('schoolInstitutionId', '==', 'seed-escola-a')));
  await assertSucceeds(list('seed-familia', 'students', where('familyUid', '==', 'seed-familia')));
});

test('students: edição pela Direção e vínculo familiar pelo admin, com consistência', async () => {
  const upd = (uid, changes) => updateDoc(doc(dbOf(uid), `students/${S1}`), { ...changes, updatedAt: serverTimestamp(), updatedBy: uid });
  await assertSucceeds(upd('seed-diretor-escola', { name: 'Estudante Sintético Renomeado' }));
  await assertFails(upd('seed-diretor-escola', { schoolInstitutionId: 'seed-escola-b' }));
  await assertFails(upd('seed-diretor-escola', { familyUid: 'seed-familia-b' }));
  await assertFails(upd('seed-professor', { name: 'X Y' }));
  await assertFails(upd('seed-diretor-escola-b', { name: 'X Y' }));

  // Admin move a família B do estudante 2 para o 3 (uma conta por estudante; batch nos três documentos).
  const adminDb = dbOf('seed-admin');
  const twoStudents = writeBatch(adminDb);
  twoStudents.update(doc(adminDb, 'students/seed-estudante-3'), { familyUid: 'seed-familia-b', updatedAt: serverTimestamp(), updatedBy: 'seed-admin' });
  twoStudents.update(doc(adminDb, 'users/seed-familia-b'), { studentIds: ['seed-estudante-2', 'seed-estudante-3'], updatedAt: serverTimestamp() });
  await assertFails(twoStudents.commit());
  const ok = writeBatch(adminDb);
  ok.update(doc(adminDb, 'students/seed-estudante-2'), { familyUid: null, updatedAt: serverTimestamp(), updatedBy: 'seed-admin' });
  ok.update(doc(adminDb, 'students/seed-estudante-3'), { familyUid: 'seed-familia-b', updatedAt: serverTimestamp(), updatedBy: 'seed-admin' });
  ok.update(doc(adminDb, 'users/seed-familia-b'), { studentIds: ['seed-estudante-3'], updatedAt: serverTimestamp(), lastAuditId: 'auditMove1' });
  // P2-05: sem o log da conta familiar no mesmo batch, negado.
  await assertFails(ok.commit());
  const audited = writeBatch(adminDb);
  audited.update(doc(adminDb, 'students/seed-estudante-2'), { familyUid: null, updatedAt: serverTimestamp(), updatedBy: 'seed-admin' });
  audited.update(doc(adminDb, 'students/seed-estudante-3'), { familyUid: 'seed-familia-b', updatedAt: serverTimestamp(), updatedBy: 'seed-admin' });
  audited.update(doc(adminDb, 'users/seed-familia-b'), { studentIds: ['seed-estudante-3'], updatedAt: serverTimestamp(), lastAuditId: 'auditMove2' });
  audited.set(doc(adminDb, 'adminAuditLogs/auditMove2'), {
    action: 'user.update', actorUid: 'seed-admin', targetType: 'user', targetId: 'seed-familia-b',
    before: null, after: null, createdAt: serverTimestamp(),
  });
  audited.set(doc(adminDb, 'adminAuditLogs/auditMove2-assoc'), {
    action: 'association.update', actorUid: 'seed-admin', targetType: 'user', targetId: 'seed-familia-b',
    before: null, after: null, createdAt: serverTimestamp(),
  });
  await assertSucceeds(audited.commit());
  // Sem atualizar o perfil da família: inconsistente.
  await assertFails(upd('seed-admin', { familyUid: 'seed-familia-b' }));
  // Família não altera os próprios vínculos.
  await assertFails(updateDoc(doc(dbOf('seed-familia'), 'users/seed-familia'), { studentIds: [S1, 'seed-estudante-2'], updatedAt: serverTimestamp() }));
});

// ---------------------------------------------------------------- cases

test('cases: professor da escola cria caso com evento; demais tentativas negadas', async () => {
  await assertFails(teacherCreatesCase('seed-professor', {}, { withEvent: false }));
  await assertFails(teacherCreatesCase('seed-professor', { createdAt: PAST }));
  await assertFails(teacherCreatesCase('seed-professor', { status: 'aprovado' }));
  await assertFails(teacherCreatesCase('seed-professor', { familyVisible: true }));
  await assertFails(teacherCreatesCase('seed-professor', { primaryTeacherUid: 'seed-professor-2', teacherUids: ['seed-professor-2'] }));
  await assertFails(teacherCreatesCase('seed-professor', { studentId: 'seed-estudante-3', studentName: 'Estudante Sintético Três' }));
  await assertFails(teacherCreatesCase('seed-professor', { studentName: 'Nome divergente' }));
  await assertFails(teacherCreatesCase('seed-professor', {}, { eventOverrides: { type: 'case.approved' } }));
  await assertFails(teacherCreatesCase('seed-professor', {}, { eventOverrides: { actorUid: 'seed-professor-2' } }));
  await assertFails(teacherCreatesCase('seed-professor', {}, { eventOverrides: { actorRole: 'school/director' } }));
  await assertFails(teacherCreatesCase('seed-professor', {}, { eventOverrides: { createdAt: PAST } }));
  await assertFails(teacherCreatesCase('seed-professor-b', { schoolInstitutionId: 'seed-escola-a' }));
  await assertFails(teacherCreatesCase('seed-diretor-escola'));
  await assertFails(teacherCreatesCase('seed-professor-inativo'));
  await assertFails(teacherCreatesCase('seed-professor', {}, { withLock: false }));
  await assertSucceeds(teacherCreatesCase('seed-professor'));
});

test('P2-06 (RN-20): um caso em andamento por estudante, inclusive em criações simultâneas', async () => {
  const create = (uid, caseId) => {
    const db = dbOf(uid);
    const batch = writeBatch(db);
    batch.set(doc(db, `cases/${caseId}`), {
      ...caseFixture({ primaryTeacherUid: uid, teacherUids: [uid], createdBy: uid, updatedBy: uid }),
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(), lastEventId: `ev-${caseId}`,
    });
    batch.set(doc(db, `cases/${caseId}/timelineEvents/ev-${caseId}`), eventData(uid, 'case.created'));
    batch.set(doc(db, `caseLocks/${S1}`), {
      caseId, schoolInstitutionId: 'seed-escola-a', createdAt: serverTimestamp(), createdBy: uid,
    });
    return batch.commit();
  };
  const results = await Promise.allSettled([create('seed-professor', 'case-a'), create('seed-professor-2', 'case-b')]);
  const accepted = results.filter((r) => r.status === 'fulfilled').length;
  if (accepted !== 1) throw new Error(`esperava 1 caso aceito, obtive ${accepted}`);
  const winner = results[0].status === 'fulfilled' ? 'case-a' : 'case-b';
  // Segundo caso enquanto o primeiro está em andamento: negado.
  await assertFails(create('seed-professor', 'case-c'));
  // A trava é legível pela escola do estudante e não por outras.
  await assertSucceeds(getDoc(doc(dbOf('seed-diretor-escola'), `caseLocks/${S1}`)));
  await assertFails(getDoc(doc(dbOf('seed-professor-b'), `caseLocks/${S1}`)));
  await assertFails(getDoc(doc(dbOf('seed-familia'), `caseLocks/${S1}`)));
  await assertFails(deleteDoc(doc(dbOf('seed-professor'), `caseLocks/${S1}`)));
  // Após a conclusão, um novo caso pode ser aberto.
  await asAdminSdk((db) => updateDoc(doc(db, `cases/${winner}`), { status: 'concluido' }));
  await assertSucceeds(create('seed-professor', 'case-d'));
});

test('cases: professores PT/sem subrole não operam (transição P1-17 sem fallback)', async () => {
  const db = dbOf('pt-professor');
  const batch = writeBatch(db);
  batch.set(doc(db, `cases/${CASE}`), { ...caseFixture({ primaryTeacherUid: 'pt-professor', teacherUids: ['pt-professor'], createdBy: 'pt-professor', updatedBy: 'pt-professor' }), createdAt: serverTimestamp(), updatedAt: serverTimestamp(), lastEventId: 'x' });
  batch.set(doc(db, `cases/${CASE}/timelineEvents/x`), { ...eventData('seed-professor', 'case.created'), actorUid: 'pt-professor', actorName: 'PT Professor' });
  await assertFails(batch.commit());
  await putCase({ teacherUids: ['seed-professor', 'pt-professor'] });
  await assertFails(read('pt-professor', `cases/${CASE}`));
  await assertFails(read('pt-diretor', `cases/${CASE}`));
  await putReferral('ref-a');
  await assertFails(read('saude-sem-subrole', 'referrals/ref-a'));
});

test('cases: leitura por perfil (admin só metadados; família só após aprovação)', async () => {
  await putCase({ teacherUids: ['seed-professor'] });
  await assertSucceeds(read('seed-professor', `cases/${CASE}`));
  await assertSucceeds(read('seed-diretor-escola', `cases/${CASE}`));
  await assertSucceeds(read('seed-admin', `cases/${CASE}`));
  for (const uid of ['seed-professor-2', 'seed-professor-b', 'seed-diretor-escola-b', 'seed-familia', 'seed-familia-b',
    'seed-diretor-ubs', 'seed-psicologo', 'seed-inativo', 'seed-professor-inativo', 'seed-sem-perfil', null]) {
    await assertFails(read(uid, `cases/${CASE}`));
  }
  await putCase({ status: 'aprovado', familyVisible: true });
  await assertSucceeds(read('seed-familia', `cases/${CASE}`));
  await assertFails(read('seed-familia-b', `cases/${CASE}`));
  // Consultas compatíveis com as regras.
  await assertSucceeds(list('seed-professor', 'cases', where('schoolInstitutionId', '==', 'seed-escola-a'), where('teacherUids', 'array-contains', 'seed-professor')));
  await assertFails(list('seed-professor', 'cases', where('teacherUids', 'array-contains', 'seed-professor')));
  await assertSucceeds(list('seed-diretor-escola', 'cases', where('schoolInstitutionId', '==', 'seed-escola-a')));
  await assertFails(list('seed-diretor-escola-b', 'cases', where('schoolInstitutionId', '==', 'seed-escola-a')));
  await assertSucceeds(list('seed-familia', 'cases', where('studentId', '==', S1), where('familyVisible', '==', true)));
  await assertFails(list('seed-familia', 'cases', where('studentId', '==', S1)));
  await assertFails(list('seed-familia-b', 'cases', where('studentId', '==', S1), where('familyVisible', '==', true)));
  await assertSucceeds(list('seed-admin', 'cases'));
});

test('cases: fluxo escolar envio → complementação → aprovação → conclusão', async () => {
  await putCase();
  await assertFails(caseTransition('seed-professor', { status: 'aprovado', familyVisible: true, approvedAt: serverTimestamp(), approvedBy: 'seed-professor' }, 'case.approved'));
  await assertFails(updateDoc(doc(dbOf('seed-professor'), `cases/${CASE}`), { status: 'aguardando_analise', updatedAt: serverTimestamp(), updatedBy: 'seed-professor', lastEventId: 'sem-evento' }));
  await assertFails(caseTransition('seed-professor-2', { status: 'aguardando_analise' }, 'case.submitted'));
  await assertSucceeds(caseTransition('seed-professor', { status: 'aguardando_analise' }, 'case.submitted'));

  await assertFails(caseTransition('seed-diretor-escola-b', { status: 'complementacao_solicitada' }, 'case.complementRequested'));
  await assertSucceeds(caseTransition('seed-diretor-escola', { status: 'complementacao_solicitada' }, 'case.complementRequested'));
  await assertSucceeds(caseTransition('seed-professor', { status: 'aguardando_analise' }, 'case.complemented'));

  await assertFails(caseTransition('seed-diretor-escola', { status: 'aprovado', approvedAt: serverTimestamp(), approvedBy: 'seed-diretor-escola' }, 'case.approved', 'ev-a1'));
  await assertFails(caseTransition('seed-diretor-escola', { status: 'aprovado', familyVisible: true, approvedAt: PAST, approvedBy: 'seed-diretor-escola' }, 'case.approved', 'ev-a2'));
  await assertFails(caseTransition('seed-diretor-escola', { status: 'aprovado', familyVisible: true, approvedAt: serverTimestamp(), approvedBy: 'seed-diretor-escola' }, 'case.approved', 'ev-a3', { visibility: 'interno' }));
  await assertSucceeds(caseTransition('seed-diretor-escola', { status: 'aprovado', familyVisible: true, approvedAt: serverTimestamp(), approvedBy: 'seed-diretor-escola' }, 'case.approved'));

  await assertFails(caseTransition('seed-diretor-escola', { studentId: 'seed-estudante-2' }, 'case.teachersUpdated'));
  await assertFails(caseTransition('seed-diretor-escola', { teacherUids: ['seed-professor', 'seed-professor-b'], primaryTeacherUid: 'seed-professor-b' }, 'case.teachersUpdated', 'ev-t1', { visibility: 'interno' }));
  await assertSucceeds(caseTransition('seed-diretor-escola', { teacherUids: ['seed-professor', 'seed-professor-2'], primaryTeacherUid: 'seed-professor-2' }, 'case.teachersUpdated', 'ev-t2', { visibility: 'interno' }));
  await assertSucceeds(read('seed-professor-2', `cases/${CASE}`));
  // P1-02: o professor desvinculado perde o acesso ao caso e ao conteúdo interno.
  await assertSucceeds(caseTransition('seed-diretor-escola', { teacherUids: ['seed-professor-2'], primaryTeacherUid: 'seed-professor-2' }, 'case.teachersUpdated', 'ev-t3', { visibility: 'interno' }));
  await assertFails(read('seed-professor', `cases/${CASE}`));
  await assertFails(list('seed-professor', `cases/${CASE}/observations`));
  await assertSucceeds(list('seed-professor-2', `cases/${CASE}/observations`));
  // Sem professor vinculado não é permitido.
  await assertFails(caseTransition('seed-diretor-escola', { teacherUids: [], primaryTeacherUid: 'seed-professor-2' }, 'case.teachersUpdated', 'ev-t4', { visibility: 'interno' }));

  await assertFails(caseTransition('seed-professor', { status: 'concluido' }, 'case.concluded'));
  await assertSucceeds(caseTransition('seed-diretor-escola', { status: 'concluido' }, 'case.concluded'));
  await assertFails(caseTransition('seed-diretor-escola', { complementOpen: true }, 'case.ubsComplementForwarded', 'ev-x', { visibility: 'interno' }));
  await assertFails(updateDoc(doc(dbOf('seed-familia'), `cases/${CASE}`), { status: 'rascunho' }));
  await assertFails(updateDoc(doc(dbOf('seed-admin'), `cases/${CASE}`), { status: 'rascunho' }));
  await assertFails(deleteDoc(doc(dbOf('seed-diretor-escola'), `cases/${CASE}`)));
});

// ---------------------------------------------------------------- observations / records

function teacherObserves(uid, id = 'o1', overrides = {}) {
  const db = dbOf(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, `cases/${CASE}/observations/${id}`), {
    authorUid: uid, authorName: data.fullName(byUid[uid]), context: 'Recreio', description: 'Descrição objetiva sintética.',
    observedAt: PAST, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...overrides,
  });
  batch.set(doc(db, `cases/${CASE}/timelineEvents/ev-${id}`), eventData(uid, 'observation.created', { visibility: 'interno', refId: id }));
  return batch.commit();
}

test('observations: só professor vinculado escreve; família, saúde e admin não leem', async () => {
  await putCase();
  await assertFails(teacherObserves('seed-professor', 'o1', { authorUid: 'seed-professor-2' }));
  await assertFails(teacherObserves('seed-professor', 'o1', { authorName: 'Outro Nome' }));
  await assertFails(teacherObserves('seed-professor', 'o1', { createdAt: PAST }));
  await assertFails(teacherObserves('seed-professor-2'));
  await assertFails(teacherObserves('seed-diretor-escola'));
  await assertSucceeds(teacherObserves('seed-professor'));
  await assertSucceeds(updateDoc(doc(dbOf('seed-professor'), `cases/${CASE}/observations/o1`), { description: 'Ajuste', updatedAt: serverTimestamp() }));

  await assertSucceeds(read('seed-diretor-escola', `cases/${CASE}/observations/o1`));
  await putCase({ status: 'aprovado', familyVisible: true });
  for (const uid of ['seed-familia', 'seed-admin', 'seed-diretor-ubs', 'seed-psicologo', 'seed-professor-b', 'seed-diretor-escola-b']) {
    await assertFails(read(uid, `cases/${CASE}/observations/o0`));
  }
  // Fora dos estados editáveis o professor não grava.
  await assertFails(teacherObserves('seed-professor', 'o2'));
  await assertFails(updateDoc(doc(dbOf('seed-professor'), `cases/${CASE}/observations/o0`), { description: 'Ajuste', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(dbOf('seed-professor'), `cases/${CASE}/observations/o0`)));
  // Complementação pedida pela UBS reabre a escrita (D-20).
  await putCase({ status: 'encaminhado', familyVisible: true, complementOpen: true });
  await assertSucceeds(teacherObserves('seed-professor', 'o3'));
});

test('pedagogicalRecords: registro estruturado interno', async () => {
  await putCase();
  const db = dbOf('seed-professor');
  const batch = writeBatch(db);
  batch.set(doc(db, `cases/${CASE}/pedagogicalRecords/p1`), {
    authorUid: 'seed-professor', authorName: 'Professor Sintético', summary: 'Síntese pedagógica sintética.',
    actions: ['Ajuste de rotina'], observationIds: ['o0'], createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  batch.set(doc(db, `cases/${CASE}/timelineEvents/ev-p1`), eventData('seed-professor', 'pedagogicalRecord.created', { visibility: 'interno', refId: 'p1' }));
  await assertSucceeds(batch.commit());
  await assertSucceeds(read('seed-diretor-escola', `cases/${CASE}/pedagogicalRecords/p1`));
  await assertFails(read('seed-admin', `cases/${CASE}/pedagogicalRecords/p1`));
  await assertFails(read('seed-familia', `cases/${CASE}/pedagogicalRecords/p1`));
});

// ---------------------------------------------------------------- timeline

test('timeline: família vê o histórico administrativo completo só após a aprovação', async () => {
  await putCase();
  await assertFails(read('seed-familia', `cases/${CASE}/timelineEvents/e0`));
  await putCase({ status: 'aprovado', familyVisible: true });
  await assertSucceeds(read('seed-familia', `cases/${CASE}/timelineEvents/e0`)); // anterior à aprovação
  await assertFails(read('seed-familia', `cases/${CASE}/timelineEvents/e-int`));
  await assertFails(read('seed-familia-b', `cases/${CASE}/timelineEvents/e0`));
  await assertSucceeds(list('seed-familia', `cases/${CASE}/timelineEvents`, where('visibility', '==', 'familia')));
  await assertFails(list('seed-familia', `cases/${CASE}/timelineEvents`));
  await assertSucceeds(list('seed-professor', `cases/${CASE}/timelineEvents`, where('visibility', 'in', ['familia', 'interno'])));
  await assertFails(read('seed-admin', `cases/${CASE}/timelineEvents/e0`));
  await assertFails(read('seed-diretor-ubs', `cases/${CASE}/timelineEvents/e0`));
});

test('timeline: eventos imutáveis e sem criação avulsa', async () => {
  await putCase();
  const db = dbOf('seed-professor');
  await assertFails(setDoc(doc(db, `cases/${CASE}/timelineEvents/avulso`), eventData('seed-professor', 'case.submitted')));
  await assertFails(updateDoc(doc(db, `cases/${CASE}/timelineEvents/e0`), { type: 'case.approved' }));
  await assertFails(deleteDoc(doc(db, `cases/${CASE}/timelineEvents/e0`)));
  await assertFails(setDoc(doc(dbOf('seed-familia'), `cases/${CASE}/timelineEvents/f`), { type: 'case.approved' }));
});

// ---------------------------------------------------------------- referrals

test('referrals: Direção escolar encaminha a UBS ativas (simultâneas); demais negados', async () => {
  await putCase({ status: 'aguardando_analise' });
  await assertFails(directorSendsReferral('seed-diretor-escola', 'ref-a', 'seed-ubs-a'));
  await putCase({ status: 'aprovado', familyVisible: true });
  await assertFails(directorSendsReferral('seed-professor', 'ref-a', 'seed-ubs-a'));
  await assertFails(directorSendsReferral('seed-diretor-escola-b', 'ref-a', 'seed-ubs-a'));
  await assertFails(directorSendsReferral('seed-diretor-escola', 'ref-a', 'seed-escola-b'));
  await assertFails(directorSendsReferral('seed-diretor-escola', 'ref-a', 'seed-ubs-a', { withDetails: false }));
  await assertFails(directorSendsReferral('seed-diretor-escola', 'ref-a', 'seed-ubs-a', { status: 'recebido' }));
  await assertSucceeds(directorSendsReferral('seed-diretor-escola', 'ref-a', 'seed-ubs-a'));
  await assertSucceeds(directorSendsReferral('seed-diretor-escola', 'ref-b', 'seed-ubs-b', { approveCase: false }));
});

test('referrals: leitura de metadados e do resumo por perfil e por UBS', async () => {
  await putCase({ status: 'encaminhado', familyVisible: true });
  await putReferral('ref-a');
  for (const uid of ['seed-diretor-escola', 'seed-diretor-ubs', 'seed-familia', 'seed-admin', 'seed-professor']) {
    await assertSucceeds(read(uid, 'referrals/ref-a'));
  }
  for (const uid of ['seed-diretor-ubs-b', 'seed-psicologo', 'seed-psicologo-b', 'seed-familia-b', 'seed-diretor-escola-b', 'seed-professor-b']) {
    await assertFails(read(uid, 'referrals/ref-a'));
  }
  await assertSucceeds(read('seed-diretor-ubs', 'referrals/ref-a/private/details'));
  await assertSucceeds(read('seed-diretor-escola', 'referrals/ref-a/private/details'));
  for (const uid of ['seed-admin', 'seed-familia', 'seed-professor', 'seed-diretor-ubs-b', 'seed-psicologo']) {
    await assertFails(read(uid, 'referrals/ref-a/private/details'));
  }
  await assertSucceeds(list('seed-diretor-ubs', 'referrals', where('destinationInstitutionId', '==', 'seed-ubs-a')));
  await assertFails(list('seed-diretor-ubs-b', 'referrals', where('destinationInstitutionId', '==', 'seed-ubs-a')));
  await assertFails(list('seed-diretor-ubs', 'referrals'));
  await assertSucceeds(list('seed-familia', 'referrals', where('studentId', '==', S1)));
  await assertSucceeds(list('seed-professor', 'referrals', where('caseId', '==', CASE)));
});

test('referrals: UBS recebe, atribui psicólogo da própria unidade e o caso entra em acompanhamento', async () => {
  await putCase({ status: 'encaminhado', familyVisible: true });
  await putReferral('ref-a');
  await assertFails(referralTransition('seed-diretor-ubs-b', 'ref-a', { status: 'recebido' }, 'referral.received'));
  await assertFails(referralTransition('seed-psicologo', 'ref-a', { status: 'recebido' }, 'referral.received'));
  await assertSucceeds(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'recebido' }, 'referral.received'));

  const assign = (psy, name, extra) => referralTransition('seed-diretor-ubs', 'ref-a', {
    status: 'atribuido', assignedPsychologistUid: psy, assignedPsychologistName: name,
  }, 'referral.assigned', { caseChanges: { status: 'em_acompanhamento' }, ...extra });
  await assertFails(assign('seed-psicologo-b', 'Psicólogo UBS B Sintético'));
  await assertFails(assign('seed-diretor-ubs', 'Diretor UBS Sintético'));
  await assertFails(assign('seed-psicologo', 'Nome forjado'));
  await assertSucceeds(assign('seed-psicologo', 'Psicóloga Sintética'));

  const c = await read('seed-diretor-escola', `cases/${CASE}`);
  if (c.get('status') !== 'em_acompanhamento') throw new Error('caso deveria estar em acompanhamento');
  // UBS de destino lê os metadados do caso enquanto o encaminhamento estiver ativo; outra UBS não.
  await assertSucceeds(read('seed-diretor-ubs', `cases/${CASE}`));
  await assertFails(read('seed-diretor-ubs-b', `cases/${CASE}`));
  await assertSucceeds(read('seed-psicologo', 'referrals/ref-a'));
  await assertSucceeds(read('seed-psicologo', 'referrals/ref-a/private/details'));
  await assertSucceeds(read('seed-psicologo', `cases/${CASE}/timelineEvents/ev-ref-a`));
  await assertFails(read('seed-psicologo', `cases/${CASE}`));
});

test('referrals: transferência revoga o acesso do psicólogo anterior', async () => {
  await putCase({ status: 'em_acompanhamento', familyVisible: true });
  await putReferral('ref-a', { status: 'em_atendimento', assignedPsychologistUid: 'seed-psicologo', assignedPsychologistName: 'Psicóloga Sintética' });
  await assertSucceeds(read('seed-psicologo', 'referrals/ref-a'));
  await assertFails(referralTransition('seed-psicologo', 'ref-a', { assignedPsychologistUid: 'seed-psicologo-2', assignedPsychologistName: 'Psicólogo Dois Sintético' }, 'referral.transferred'));
  await assertSucceeds(referralTransition('seed-diretor-ubs', 'ref-a', { assignedPsychologistUid: 'seed-psicologo-2', assignedPsychologistName: 'Psicólogo Dois Sintético' }, 'referral.transferred'));
  await assertFails(read('seed-psicologo', 'referrals/ref-a'));
  await assertFails(read('seed-psicologo', 'referrals/ref-a/private/details'));
  await assertFails(read('seed-psicologo', `cases/${CASE}/timelineEvents/ev-ref-a`));
  await assertFails(psychologistReturns('seed-psicologo', 'ref-a', ['family']));
  await assertSucceeds(read('seed-psicologo-2', 'referrals/ref-a'));
  await assertSucceeds(list('seed-psicologo-2', 'referrals', where('assignedPsychologistUid', '==', 'seed-psicologo-2')));
});

test('referrals: complementação via Direção escolar, devolução e recusa exigem justificativa', async () => {
  await putCase({ status: 'encaminhado', familyVisible: true });
  await putReferral('ref-a', { status: 'recebido' });
  await assertFails(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'complementacao_solicitada', previousStatus: 'recebido' }, 'referral.complementRequested'));
  await assertSucceeds(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'complementacao_solicitada', previousStatus: 'recebido' }, 'referral.complementRequested', { note: { kind: 'complementRequest', audience: ['school', 'ubs'] } }));
  await assertSucceeds(read('seed-diretor-escola', 'referrals/ref-a/notes/ev-referral.complementRequested-ref-a'));
  await assertFails(read('seed-familia', 'referrals/ref-a/notes/ev-referral.complementRequested-ref-a'));
  await assertFails(read('seed-professor', 'referrals/ref-a/notes/ev-referral.complementRequested-ref-a'));
  // A UBS não fala com o professor: só a Direção escolar responde.
  await assertFails(referralTransition('seed-professor', 'ref-a', { status: 'recebido', previousStatus: null }, 'referral.complementAnswered', { note: { kind: 'complementAnswer', audience: ['school', 'ubs', 'psychologist'] } }));
  await assertSucceeds(caseTransition('seed-diretor-escola', { complementOpen: true }, 'case.ubsComplementForwarded', 'ev-fw', { visibility: 'interno' }));
  await assertSucceeds(referralTransition('seed-diretor-escola', 'ref-a', { status: 'recebido', previousStatus: null }, 'referral.complementAnswered', { note: { kind: 'complementAnswer', audience: ['school', 'ubs', 'psychologist'] } }));

  await assertFails(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'recusado' }, 'referral.refused'));
  // Sem retirar o encaminhamento dos ativos do caso: negado.
  await assertFails(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'recusado' }, 'referral.refused', { note: { kind: 'refusal', audience: ['school', 'ubs'] } }));
  await assertSucceeds(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'recusado' }, 'referral.refused', {
    note: { kind: 'refusal', audience: ['school', 'ubs'] }, caseChanges: { 'activeReferrals.ref-a': deleteField() },
  }));
  await assertFails(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'recebido' }, 'referral.received', { eventId: 'depois' }));

  await putReferral('ref-c', { status: 'enviado' });
  await assertSucceeds(referralTransition('seed-diretor-ubs', 'ref-c', { status: 'devolvido' }, 'referral.returned', {
    note: { kind: 'return', audience: ['school', 'ubs'] }, caseChanges: { 'activeReferrals.ref-c': deleteField() },
  }));
  await assertSucceeds(read('seed-familia', `cases/${CASE}/timelineEvents/ev-referral.returned-ref-c`));
  await assertFails(read('seed-familia', 'referrals/ref-c/notes/ev-referral.returned-ref-c'));
});

test('referrals: um ativo por UBS e conclusão do caso só sem encaminhamentos ativos', async () => {
  await putCase({ status: 'aprovado', familyVisible: true });
  await assertSucceeds(directorSendsReferral('seed-diretor-escola', 'ref-a', 'seed-ubs-a'));
  await assertFails(directorSendsReferral('seed-diretor-escola', 'ref-a2', 'seed-ubs-a', { approveCase: false }));
  await assertFails(directorSendsReferral('seed-diretor-escola', 'ref-b', 'seed-ubs-b', { approveCase: false, updateCase: false }));
  await assertFails(caseTransition('seed-diretor-escola', { status: 'concluido' }, 'case.concluded'));
  // UBS não mexe em encaminhamento alheio no mapa do caso.
  await assertFails(caseTransition('seed-diretor-ubs-b', { 'activeReferrals.ref-a': deleteField() }, 'referral.finalized', 'ev-x', { referralId: 'ref-a' }));

  await asAdminSdk((db) => updateDoc(doc(db, 'referrals/ref-a'), { status: 'em_atendimento', assignedPsychologistUid: 'seed-psicologo', assignedPsychologistName: 'Psicóloga Sintética' }));
  await assertFails(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'finalizado' }, 'referral.finalized'));
  await assertSucceeds(referralTransition('seed-diretor-ubs', 'ref-a', { status: 'finalizado' }, 'referral.finalized', {
    caseChanges: { 'activeReferrals.ref-a': deleteField() },
  }));
  await assertSucceeds(caseTransition('seed-diretor-escola', { status: 'concluido' }, 'case.concluded'));
});

// ---------------------------------------------------------------- healthReturns

test('healthReturns: só o psicólogo atribuído registra; leitura por audiência', async () => {
  await putCase({ status: 'em_acompanhamento', familyVisible: true });
  await putReferral('ref-a', { status: 'atribuido', assignedPsychologistUid: 'seed-psicologo', assignedPsychologistName: 'Psicóloga Sintética' });
  await assertSucceeds(referralTransition('seed-psicologo', 'ref-a', { status: 'em_atendimento' }, 'referral.statusChanged'));
  await assertFails(psychologistReturns('seed-psicologo-2', 'ref-a', ['family']));
  await assertFails(psychologistReturns('seed-psicologo', 'ref-a', ['admin']));
  await assertFails(psychologistReturns('seed-psicologo', 'ref-a', ['family'], { eventVisibility: 'interno' }));
  await assertFails(setDoc(doc(dbOf('seed-psicologo'), 'healthReturns/avulso'), {
    referralId: 'ref-a', caseId: CASE, studentId: S1, audience: ['family'], content: 'x',
    authorUid: 'seed-psicologo', authorName: 'Psicóloga Sintética', createdAt: serverTimestamp(),
  }));
  await assertSucceeds(psychologistReturns('seed-psicologo', 'ref-a', ['family', 'school']));

  const hr = 'healthReturns/hr-ref-a';
  for (const uid of ['seed-psicologo', 'seed-familia', 'seed-diretor-escola', 'seed-professor']) {
    await assertSucceeds(read(uid, hr));
  }
  for (const uid of ['seed-admin', 'seed-diretor-ubs', 'seed-familia-b', 'seed-psicologo-b', 'seed-diretor-escola-b', 'seed-professor-b']) {
    await assertFails(read(uid, hr));
  }
  await assertSucceeds(list('seed-familia', 'healthReturns', where('studentId', '==', S1), where('audience', 'array-contains', 'family')));
  await assertFails(list('seed-familia', 'healthReturns', where('studentId', '==', S1)));
  await assertFails(updateDoc(doc(dbOf('seed-psicologo'), hr), { content: 'alterado' }));
  await assertSucceeds(read('seed-familia', `cases/${CASE}/timelineEvents/hr-ref-a`));
});

test('healthReturns: devolutiva só para a escola é invisível à família', async () => {
  await putCase({ status: 'em_acompanhamento', familyVisible: true });
  await putReferral('ref-a', { status: 'em_atendimento', assignedPsychologistUid: 'seed-psicologo', assignedPsychologistName: 'Psicóloga Sintética' });
  await assertFails(psychologistReturns('seed-psicologo', 'ref-a', ['school'], { eventVisibility: 'familia' }));
  await assertSucceeds(psychologistReturns('seed-psicologo', 'ref-a', ['school']));
  await assertFails(read('seed-familia', 'healthReturns/hr-ref-a'));
  await assertFails(read('seed-familia', `cases/${CASE}/timelineEvents/hr-ref-a`));
  await assertSucceeds(read('seed-diretor-escola', 'healthReturns/hr-ref-a'));
  await assertSucceeds(read('seed-diretor-escola', `cases/${CASE}/timelineEvents/hr-ref-a`));
  // Consultas usadas pela tela do caso (referralId + caseId + audiência school).
  const schoolQuery = [where('referralId', '==', 'ref-a'), where('caseId', '==', CASE), where('audience', 'array-contains', 'school')];
  await assertSucceeds(list('seed-professor', 'healthReturns', ...schoolQuery));
  await assertSucceeds(list('seed-diretor-escola', 'healthReturns', ...schoolQuery));
  await assertFails(list('seed-professor-b', 'healthReturns', ...schoolQuery));
  await assertFails(list('seed-familia', 'healthReturns', ...schoolQuery));
  await assertFails(list('seed-diretor-ubs', 'healthReturns', ...schoolQuery));
});

test('notes: atualização do psicólogo restrita a ele', async () => {
  await putCase({ status: 'em_acompanhamento', familyVisible: true });
  await putReferral('ref-a', { status: 'em_atendimento', assignedPsychologistUid: 'seed-psicologo', assignedPsychologistName: 'Psicóloga Sintética' });
  const note = (uid, audience) => setDoc(doc(dbOf(uid), 'referrals/ref-a/notes/n1'), {
    kind: 'progress', text: 'Atualização sintética', audience, authorUid: uid,
    authorName: data.fullName(byUid[uid]), createdAt: serverTimestamp(),
  });
  await assertFails(note('seed-psicologo-2', ['psychologist']));
  await assertFails(note('seed-psicologo', ['psychologist', 'ubs']));
  await assertSucceeds(note('seed-psicologo', ['psychologist']));
  await assertSucceeds(read('seed-psicologo', 'referrals/ref-a/notes/n1'));
  for (const uid of ['seed-diretor-ubs', 'seed-diretor-escola', 'seed-admin', 'seed-familia']) {
    await assertFails(read(uid, 'referrals/ref-a/notes/n1'));
  }
});

test('usuários: sem perfil, inativos e não autenticados não acessam o domínio', async () => {
  await putCase({ status: 'em_acompanhamento', familyVisible: true });
  await putReferral('ref-a');
  for (const uid of ['seed-sem-perfil', 'seed-inativo', 'seed-professor-inativo', null]) {
    await assertFails(read(uid, `cases/${CASE}`));
    await assertFails(read(uid, 'referrals/ref-a'));
    await assertFails(read(uid, `cases/${CASE}/timelineEvents/e0`));
    await assertFails(read(uid, `students/${S1}`));
  }
  // Usuário comum não se concede vínculos institucionais.
  await assertFails(updateDoc(doc(dbOf('seed-professor'), 'users/seed-professor'), { institutionIds: ['seed-escola-a', 'seed-escola-b'], updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(dbOf('seed-psicologo'), 'users/seed-psicologo'), { healthRole: 'ubs_director', updatedAt: serverTimestamp() }));
});

// ---------------------------------------------------------------- notifications (N-01..N-04)

test('notifications: aprovação notifica a família correta; leitura e marcação só por ela', async () => {
  await putCase({ status: 'aguardando_analise' });
  const approve = { status: 'aprovado', familyVisible: true, approvedAt: serverTimestamp(), approvedBy: 'seed-diretor-escola' };
  // Evento relevante sem a notificação no mesmo batch: negado.
  await assertFails(caseTransition('seed-diretor-escola', approve, 'case.approved', 'ev-ap', {}, { withNotification: false }));
  await assertSucceeds(caseTransition('seed-diretor-escola', approve, 'case.approved', 'ev-ap'));
  const nid = `notifications/${CASE}_ev-ap`;
  await assertSucceeds(read('seed-familia', nid));
  await assertSucceeds(list('seed-familia', 'notifications', where('studentId', '==', S1)));
  await assertSucceeds(list('seed-familia', 'notifications', where('studentId', '==', S1), where('readAt', '==', null)));
  for (const uid of ['seed-familia-b', 'seed-admin', 'seed-professor', 'seed-diretor-escola', 'seed-diretor-ubs', 'seed-psicologo']) {
    await assertFails(read(uid, nid));
  }
  await assertFails(list('seed-familia', 'notifications'));
  await assertFails(list('seed-familia-b', 'notifications', where('studentId', '==', S1)));
  // Família inativa não acessa.
  await asAdminSdk((db) => updateDoc(doc(db, 'users/seed-familia'), { active: false }));
  await assertFails(read('seed-familia', nid));
  await asAdminSdk((db) => updateDoc(doc(db, 'users/seed-familia'), { active: true }));
  // Marcar como lida: só readAt, uma vez, horário do servidor, pela própria família.
  const fam = dbOf('seed-familia');
  await assertFails(updateDoc(doc(dbOf('seed-familia-b'), nid), { readAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(fam, nid), { readAt: PAST }));
  await assertFails(updateDoc(doc(fam, nid), { readAt: serverTimestamp(), type: 'case.concluded' }));
  await assertSucceeds(updateDoc(doc(fam, nid), { readAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(fam, nid), { readAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(fam, nid)));
});

test('notifications: autoria, destinatário e conteúdo não são forjáveis; sem duplicação', async () => {
  await putCase({ status: 'aprovado', familyVisible: true, approvedAt: PAST, approvedBy: 'seed-diretor-escola' });
  const forge = (uid, { eventId = 'ev-f', eventType = 'case.concluded', notif = {}, withEvent = true, eventExtra = {} } = {}) => {
    const db = dbOf(uid);
    const batch = writeBatch(db);
    if (withEvent) {
      batch.update(doc(db, `cases/${CASE}`), { status: 'concluido', updatedAt: serverTimestamp(), updatedBy: uid, lastEventId: eventId });
      batch.set(doc(db, `cases/${CASE}/timelineEvents/${eventId}`), eventData(uid, eventType, eventExtra));
    }
    batch.set(doc(db, `notifications/${notif.id || `${CASE}_${eventId}`}`), {
      studentId: S1, caseId: CASE, eventId, referralId: null, type: eventType, createdAt: serverTimestamp(),
      createdBy: uid, readAt: null, ...(notif.data || {}),
    });
    return batch.commit();
  };
  // Notificação avulsa (sem evento no mesmo batch), em nome de outro, para outro estudante,
  // com id divergente, com texto livre ou já lida: negadas.
  await assertFails(forge('seed-diretor-escola', { withEvent: false, eventId: 'e0', eventType: 'case.created' }));
  await assertFails(forge('seed-familia', { withEvent: false, eventId: 'e0' }));
  await assertFails(forge('seed-diretor-escola', { notif: { data: { createdBy: 'seed-diretor-ubs' } } }));
  await assertFails(forge('seed-diretor-escola', { notif: { data: { studentId: 'seed-estudante-2' } } }));
  await assertFails(forge('seed-diretor-escola', { notif: { id: 'outro-id' } }));
  await assertFails(forge('seed-diretor-escola', { notif: { data: { title: 'Diagnóstico' } } }));
  await assertFails(forge('seed-diretor-escola', { notif: { data: { readAt: serverTimestamp() } } }));
  await assertFails(forge('seed-diretor-escola', { notif: { data: { type: 'case.approved' } } }));
  // Evento interno não gera notificação.
  await assertFails(forge('seed-diretor-escola', { eventId: 'ev-i', eventType: 'case.teachersUpdated', eventExtra: { visibility: 'interno' } }));
  await assertSucceeds(forge('seed-diretor-escola'));
  // Nova tentativa com o mesmo evento/notificação: negada (id determinístico).
  await assertFails(forge('seed-diretor-escola'));
  const fam = dbOf('seed-familia');
  const snapshot = await getDocs(query(collection(fam, 'notifications'), where('studentId', '==', S1)));
  if (snapshot.size !== 1) throw new Error(`esperava 1 notificação, obtive ${snapshot.size}`);
});

test('notifications: devolutiva só para a escola não notifica; para a família, notifica', async () => {
  await putCase({ status: 'em_acompanhamento', familyVisible: true, approvedAt: PAST, approvedBy: 'seed-diretor-escola' });
  await putReferral('ref-n', { status: 'em_atendimento', assignedPsychologistUid: 'seed-psicologo', assignedPsychologistName: data.fullName(byUid['seed-psicologo']) });
  await assertSucceeds(psychologistReturns('seed-psicologo', 'ref-n', ['school']));
  let none = 0;
  await asAdminSdk(async (db) => { none = (await getDocs(collection(db, 'notifications'))).size; });
  if (none !== 0) throw new Error('devolutiva restrita gerou notificação');
  await asAdminSdk((db) => updateDoc(doc(db, 'referrals/ref-n'), { status: 'em_atendimento' }));
  // Para a família: sem a notificação, negado; com ela, aceito.
  const db = dbOf('seed-psicologo');
  const batch = writeBatch(db);
  batch.set(doc(db, 'healthReturns/hr-fam'), {
    referralId: 'ref-n', caseId: CASE, studentId: S1, audience: ['family'], content: 'Devolutiva sintética.',
    authorUid: 'seed-psicologo', authorName: data.fullName(byUid['seed-psicologo']), createdAt: serverTimestamp(),
  });
  batch.update(doc(db, 'referrals/ref-n'), { status: 'devolutiva_registrada', updatedAt: serverTimestamp(), updatedBy: 'seed-psicologo', lastEventId: 'hr-fam' });
  batch.set(doc(db, `cases/${CASE}/timelineEvents/hr-fam`), eventData('seed-psicologo', 'healthReturn.created', { referralId: 'ref-n', refId: 'hr-fam' }));
  await assertFails(batch.commit());
  await putReferral('ref-n2', {
    destinationInstitutionId: 'seed-ubs-b', status: 'em_atendimento',
    assignedPsychologistUid: 'seed-psicologo', assignedPsychologistName: data.fullName(byUid['seed-psicologo']),
  });
  await assertSucceeds(psychologistReturns('seed-psicologo', 'ref-n2', ['family']));
  await assertSucceeds(read('seed-familia', `notifications/${CASE}_hr-ref-n2`));
});

// ---------------------------------------------------------------- documentExports (R-07)

test('documentExports: cada perfil registra só o próprio tipo de documento e só para o que lê', async () => {
  await putCase({ status: 'em_acompanhamento', familyVisible: true, approvedAt: PAST, approvedBy: 'seed-diretor-escola' });
  await putReferral('ref-x', { status: 'em_atendimento', assignedPsychologistUid: 'seed-psicologo', assignedPsychologistName: data.fullName(byUid['seed-psicologo']) });
  const exp = (uid, kind, extra = {}) => setDoc(doc(collection(dbOf(uid), 'documentExports')), {
    kind, action: 'generated', caseId: CASE, referralId: null, actorUid: uid, itemCount: 2,
    createdAt: serverTimestamp(), ...extra,
  });
  await assertSucceeds(exp('seed-professor', 'pedagogical'));
  await assertSucceeds(exp('seed-diretor-escola', 'school', { action: 'share_opened' }));
  await assertSucceeds(exp('seed-familia', 'family', { action: 'downloaded' }));
  await assertSucceeds(exp('seed-psicologo', 'health', { referralId: 'ref-x' }));
  await assertSucceeds(exp('seed-diretor-ubs', 'ubs', { referralId: 'ref-x', action: 'print_opened' }));
  // Tipo de outro perfil, sem acesso ao caso, campos extras ou ação inválida: negados.
  await assertFails(exp('seed-professor', 'school'));
  await assertFails(exp('seed-familia', 'pedagogical'));
  await assertFails(exp('seed-familia-b', 'family'));
  await assertFails(exp('seed-professor-b', 'pedagogical'));
  await assertFails(exp('seed-diretor-ubs-b', 'ubs', { referralId: 'ref-x' }));
  await assertFails(exp('seed-psicologo-b', 'health', { referralId: 'ref-x' }));
  await assertFails(exp('seed-admin', 'school'));
  await assertFails(exp('seed-professor', 'pedagogical', { actorUid: 'seed-diretor-escola' }));
  await assertFails(exp('seed-professor', 'pedagogical', { content: 'texto do relatório' }));
  await assertFails(exp('seed-professor', 'pedagogical', { action: 'delivered' }));
  // Somente o admin lê os metadados; ninguém altera.
  await assertSucceeds(getDocs(collection(dbOf('seed-admin'), 'documentExports')));
  await assertFails(getDocs(collection(dbOf('seed-diretor-escola'), 'documentExports')));
});
