'use strict';

// Regras administrativas (cadastros, contas e auditoria). Somente Firestore
// Emulator, projeto demo-*. Desde a P2-05 toda gravação administrativa leva um
// log de auditoria no mesmo batch, referenciado por lastAuditId.

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');

let environment;
let auditSeq = 0;

// Id alfanumérico, como os ids automáticos do Firestore.
const newAuditId = () => `audit${Date.now()}x${++auditSeq}`;

function addAudit(batch, db, id, action, targetType, targetId, actorUid = 'admin-1') {
  batch.set(doc(db, `adminAuditLogs/${id}`), {
    action, actorUid, targetType, targetId, before: null, after: null, createdAt: serverTimestamp(),
  });
}

// Atualização administrativa auditada (padrão do app): alvo + log no mesmo batch.
// extraLogs: sufixos exigidos por regra (-role, -active, -assoc).
function audited(db, targetPath, changes, { action, targetType, targetId, extraLogs = [] }) {
  const id = newAuditId();
  const batch = writeBatch(db);
  batch.update(doc(db, targetPath), { ...changes, lastAuditId: id });
  addAudit(batch, db, id, action, targetType, targetId);
  for (const [suffix, extraAction] of extraLogs) {
    addAudit(batch, db, `${id}-${suffix}`, extraAction, targetType, targetId);
  }
  return batch.commit();
}

const userUpdate = (db, uid, changes, extraLogs = []) => audited(db, `users/${uid}`,
  { ...changes, updatedAt: serverTimestamp() },
  { action: 'user.update', targetType: 'user', targetId: uid, extraLogs });

// Cria (como admin) um usuário operacional com o cadastro profissional no mesmo
// batch (P1-10), com os logs de auditoria (P2-05).
function createOperationalUser(db, uid, userData, institutionIds = ['school-1'], { userAudit = true } = {}) {
  const batch = writeBatch(db);
  const profAudit = newAuditId();
  const userAuditId = newAuditId();
  batch.set(doc(db, `professionals/prof-${uid}`), {
    name: userData.name, userId: uid, institutionIds, active: true,
    role: userData.role, subrole: userData.schoolRole || userData.healthRole || null,
    createdBy: 'admin-1', createdAt: serverTimestamp(), lastAuditId: profAudit,
  });
  addAudit(batch, db, profAudit, 'professional.create', 'professional', `prof-${uid}`);
  batch.set(doc(db, `users/${uid}`), {
    ...userData, professionalId: `prof-${uid}`, institutionIds, lastAuditId: userAuditId,
  });
  if (userAudit) addAudit(batch, db, userAuditId, 'user.create', 'user', uid);
  return batch.commit();
}

function newInstitution(db, id, data) {
  const auditId = newAuditId();
  const batch = writeBatch(db);
  batch.set(doc(db, `institutions/${id}`), {
    createdBy: 'admin-1', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    lastAuditId: auditId, ...data,
  });
  addAudit(batch, db, auditId, 'institution.create', 'institution', id);
  return batch.commit();
}

const schoolUserBase = {
  firstName: 'Nova',
  lastName: 'Pessoa',
  name: 'Nova Pessoa',
  email: 'nova@exemplo.com',
  role: 'school',
  schoolRole: 'teacher',
  healthRole: null,
  active: true,
  professionalId: null,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  createdBy: 'admin-1',
  lastAccessAt: null,
};

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-caminhoazul',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
    },
  });
});

test.beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/admin-1'), {
      name: 'Admin', email: 'admin@exemplo.com', role: 'admin', active: true,
    });
    await setDoc(doc(db, 'users/admin-2'), {
      name: 'Admin Dois', email: 'admin2@exemplo.com', role: 'admin', active: true,
    });
    await setDoc(doc(db, 'users/user-1'), {
      name: 'Pessoa', email: 'pessoa@exemplo.com', role: 'family', active: true,
      professionalId: null,
    });
    await setDoc(doc(db, 'users/disabled-1'), {
      name: 'Inativo', email: 'inativo@exemplo.com', role: 'family', active: false,
    });
    await setDoc(doc(db, 'institutions/school-1'), {
      name: 'Escola ativa', type: 'school', active: true,
    });
    await setDoc(doc(db, 'institutions/school-2'), {
      name: 'Escola dois', type: 'school', active: true,
    });
    await setDoc(doc(db, 'institutions/ubs-1'), {
      name: 'UBS ativa', type: 'ubs', active: true,
    });
    await setDoc(doc(db, 'institutions/legacy-1'), {
      name: 'Instituição legada', type: 'Escola', active: true,
    });
  });
});

test.after(async () => environment.cleanup());

test('usuario comum nao cria conta nem eleva a propria role', async () => {
  const db = environment.authenticatedContext('user-1').firestore();
  await assertFails(setDoc(doc(db, 'users/new-user'), {
    name: 'Novo', email: 'novo@exemplo.com', role: 'admin', active: true,
  }));
  await assertFails(updateDoc(doc(db, 'users/user-1'), { role: 'admin' }));
});

test('administrador lista usuarios e usuario comum nao lista', async () => {
  const adminDb = environment.authenticatedContext('admin-1').firestore();
  const commonDb = environment.authenticatedContext('user-1').firestore();
  await assertSucceeds(getDocs(collection(adminDb, 'users')));
  await assertFails(getDocs(collection(commonDb, 'users')));
});

test('administrador cria usuario e altera role de outro usuario', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertSucceeds(createOperationalUser(db, 'new-user', schoolUserBase));
  await assertFails(createOperationalUser(db, 'invalid-school-user', {
    ...schoolUserBase,
    email: 'invalido@exemplo.com',
    schoolRole: 'coordenacao',
  }));
  await assertSucceeds(userUpdate(db, 'new-user', { schoolRole: 'director' },
    [['role', 'user.role.update']]));
  // Família → Saúde exige cadastro profissional e instituições (P1-10).
  await assertFails(userUpdate(db, 'user-1', { role: 'health', healthRole: 'psychologist' },
    [['role', 'user.role.update']]));
  const auditId = newAuditId();
  const profAudit = newAuditId();
  const batch = writeBatch(db);
  batch.set(doc(db, 'professionals/prof-user-1'), {
    name: 'Pessoa', userId: 'user-1', institutionIds: ['ubs-1'], active: true,
    role: 'health', subrole: 'psychologist',
    createdBy: 'admin-1', createdAt: serverTimestamp(), lastAuditId: profAudit,
  });
  addAudit(batch, db, profAudit, 'professional.create', 'professional', 'prof-user-1');
  batch.update(doc(db, 'users/user-1'), {
    role: 'health', healthRole: 'psychologist', professionalId: 'prof-user-1',
    institutionIds: ['ubs-1'], updatedAt: serverTimestamp(), lastAuditId: auditId,
  });
  addAudit(batch, db, auditId, 'user.update', 'user', 'user-1');
  addAudit(batch, db, `${auditId}-role`, 'user.role.update', 'user', 'user-1');
  await assertSucceeds(batch.commit());
});

test('administrador nao remove a propria role nem se desativa', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertFails(userUpdate(db, 'user-1', { role: 'papel-invalido' }, [['role', 'user.role.update']]));
  await assertFails(userUpdate(db, 'admin-1', { role: 'family' }, [['role', 'user.role.update']]));
  await assertFails(userUpdate(db, 'admin-1', { active: false }, [['active', 'user.deactivate']]));
});

test('P1-13: "Excluir usuário" desativa; ninguém apaga perfis', async () => {
  const adminDb = environment.authenticatedContext('admin-1').firestore();
  const commonDb = environment.authenticatedContext('user-1').firestore();

  await assertFails(deleteDoc(doc(commonDb, 'users/admin-1')));
  await assertFails(deleteDoc(doc(adminDb, 'users/admin-1')));
  await assertFails(deleteDoc(doc(adminDb, 'users/user-1')));
  await assertFails(audited(adminDb, 'users/admin-1', { active: false, updatedAt: serverTimestamp() },
    { action: 'user.deactivate', targetType: 'user', targetId: 'admin-1' }));
  // Fluxo de deleteUser: log único user.deactivate.
  await assertSucceeds(audited(adminDb, 'users/user-1', { active: false, updatedAt: serverTimestamp() },
    { action: 'user.deactivate', targetType: 'user', targetId: 'user-1' }));
  // Desativado: não lê dados protegidos.
  await assertFails(getDoc(doc(commonDb, 'institutions/school-1')));
});

test('somente administrador grava instituicoes', async () => {
  const adminDb = environment.authenticatedContext('admin-1').firestore();
  const commonDb = environment.authenticatedContext('user-1').firestore();
  const value = { name: 'Centro Azul', type: 'school', active: true };
  await assertSucceeds(newInstitution(adminDb, 'new-1', value));
  await assertFails(setDoc(doc(commonDb, 'institutions/new-2'), {
    ...value, createdBy: 'user-1', createdAt: serverTimestamp(),
  }));
  await assertSucceeds(audited(adminDb, 'institutions/school-1',
    { name: 'Escola atualizada', updatedAt: serverTimestamp() },
    { action: 'institution.update', targetType: 'institution', targetId: 'school-1' }));
});

test('usuario desativado nao le dados protegidos', async () => {
  const activeDb = environment.authenticatedContext('user-1').firestore();
  const disabledDb = environment.authenticatedContext('disabled-1').firestore();
  await assertSucceeds(getDoc(doc(activeDb, 'institutions/school-1')));
  await assertFails(getDoc(doc(disabledDb, 'institutions/school-1')));
});

test('P0-04: admin vincula profissional a perfis antigos sem normalizar role (sondas P1-P3)', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/legacy-escola'), { name: 'Legado Escola', email: 'le@exemplo.com', role: 'escola', active: true });
    await setDoc(doc(db, 'users/legacy-school'), { name: 'Legado School', email: 'ls@exemplo.com', role: 'school', active: true });
    await setDoc(doc(db, 'users/legacy-name'), { name: 'Somente Nome' });
  });
  const db = environment.authenticatedContext('admin-1').firestore();
  // Fluxo de saveProfessional: profissional + usuário com as mesmas instituições,
  // ambos referenciando o log do profissional.
  const link = (uid) => {
    const auditId = newAuditId();
    const batch = writeBatch(db);
    batch.set(doc(db, `professionals/prof-${uid}`), {
      name: uid, userId: uid, institutionIds: ['school-1'], active: true,
      createdBy: 'admin-1', createdAt: serverTimestamp(), lastAuditId: auditId,
    });
    batch.update(doc(db, `users/${uid}`), {
      professionalId: `prof-${uid}`, institutionIds: ['school-1'], updatedAt: serverTimestamp(), lastAuditId: auditId,
    });
    addAudit(batch, db, auditId, 'professional.create', 'professional', `prof-${uid}`);
    return batch.commit();
  };
  await assertSucceeds(link('legacy-escola'));
  await assertSucceeds(link('legacy-school'));
  await assertSucceeds(link('legacy-name'));
  // Alterar role ou status continua exigindo valores válidos.
  await assertFails(userUpdate(db, 'legacy-name', { role: 'papel-invalido' }, [['role', 'user.role.update']]));
  await assertFails(userUpdate(db, 'legacy-name', { active: 'sim' }, [['active', 'user.activate']]));
  await assertFails(userUpdate(db, 'legacy-escola', { schoolRole: 'coordenacao' }, [['role', 'user.role.update']]));
  // Usuário comum continua sem conseguir se vincular.
  const common = environment.authenticatedContext('user-1').firestore();
  await assertFails(updateDoc(doc(common, 'users/user-1'), { professionalId: 'prof-legacy-escola', updatedAt: serverTimestamp() }));
});

test('P1-17: cadastro só com identificadores em inglês e subrole coerente', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  const base = {
    firstName: 'Nova', lastName: 'Conta', name: 'Nova Conta', email: 'nova.conta@exemplo.com',
    role: 'health', schoolRole: null, healthRole: 'ubs_director', active: true, professionalId: null,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), createdBy: 'admin-1', lastAccessAt: null,
  };
  const ubs = ['ubs-1'];
  await assertFails(createOperationalUser(db, 'pt-1', { ...base, role: 'saude' }, ubs));
  await assertFails(createOperationalUser(db, 'pt-2', { ...base, role: 'escola', schoolRole: 'professor', healthRole: null }, ubs));
  await assertFails(createOperationalUser(db, 'h-1', { ...base, healthRole: null }, ubs));
  await assertFails(createOperationalUser(db, 'h-2', { ...base, healthRole: 'psicologo' }, ubs));
  await assertFails(createOperationalUser(db, 'h-3', { ...base, schoolRole: 'teacher' }, ubs));
  await assertFails(createOperationalUser(db, 's-1', { ...base, role: 'school', healthRole: null }, ubs));
  await assertFails(createOperationalUser(db, 'f-1', { ...base, role: 'family', healthRole: 'psychologist' }, ubs));
  await assertSucceeds(createOperationalUser(db, 'ok-ubs', base, ubs));
  await assertSucceeds(createOperationalUser(db, 'ok-psi', { ...base, email: 'psi@exemplo.com', healthRole: 'psychologist' }, ubs));

  // Normalização de documento antigo pelo admin.
  await environment.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'users/legado'), {
    name: 'Legado', email: 'legado@exemplo.com', role: 'escola', schoolRole: 'professor', active: true,
  }));
  await assertFails(userUpdate(db, 'legado', { role: 'escola', schoolRole: 'direcao' }, [['role', 'user.role.update']]));
  await assertFails(userUpdate(db, 'legado', { role: 'school', schoolRole: 'teacher', healthRole: null },
    [['role', 'user.role.update']]));
  const auditId = newAuditId();
  const profAudit = newAuditId();
  const normalize = writeBatch(db);
  normalize.set(doc(db, 'professionals/prof-legado'), {
    name: 'Legado', userId: 'legado', institutionIds: ['school-1'], active: true,
    role: 'school', subrole: 'teacher',
    createdBy: 'admin-1', createdAt: serverTimestamp(), lastAuditId: profAudit,
  });
  addAudit(normalize, db, profAudit, 'professional.create', 'professional', 'prof-legado');
  normalize.update(doc(db, 'users/legado'), {
    role: 'school', schoolRole: 'teacher', healthRole: null, professionalId: 'prof-legado',
    institutionIds: ['school-1'], updatedAt: serverTimestamp(), lastAuditId: auditId,
  });
  addAudit(normalize, db, auditId, 'user.update', 'user', 'legado');
  addAudit(normalize, db, `${auditId}-role`, 'user.role.update', 'user', 'legado');
  await assertSucceeds(normalize.commit());
});

test('P1-10: vínculos obrigatórios e consistentes entre conta, profissional e estudante', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  const base = {
    firstName: 'Prof', lastName: 'Novo', name: 'Prof Novo', email: 'prof.novo@exemplo.com',
    role: 'school', schoolRole: 'teacher', healthRole: null, active: true, studentIds: [],
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), createdBy: 'admin-1', lastAccessAt: null,
  };
  // Escola sem profissional, sem instituições ou com instituições divergentes: negado.
  const noProf = writeBatch(db);
  const noProfAudit = newAuditId();
  noProf.set(doc(db, 'users/p1'), { ...base, professionalId: null, institutionIds: [], lastAuditId: noProfAudit });
  addAudit(noProf, db, noProfAudit, 'user.create', 'user', 'p1');
  await assertFails(noProf.commit());
  await assertFails(createOperationalUser(db, 'p2', base, []));
  const divergent = writeBatch(db);
  const divAudit = newAuditId();
  const divProfAudit = newAuditId();
  divergent.set(doc(db, 'professionals/prof-p3'), { name: 'x', userId: 'p3', institutionIds: ['school-1'], active: true, createdBy: 'admin-1', createdAt: serverTimestamp(), lastAuditId: divProfAudit });
  addAudit(divergent, db, divProfAudit, 'professional.create', 'professional', 'prof-p3');
  divergent.set(doc(db, 'users/p3'), { ...base, professionalId: 'prof-p3', institutionIds: ['school-2'], lastAuditId: divAudit });
  addAudit(divergent, db, divAudit, 'user.create', 'user', 'p3');
  await assertFails(divergent.commit());
  // Profissional de outro usuário: negado.
  const foreign = writeBatch(db);
  const forAudit = newAuditId();
  const forProfAudit = newAuditId();
  foreign.set(doc(db, 'professionals/prof-p4'), { name: 'x', userId: 'outro', institutionIds: ['school-1'], active: true, createdBy: 'admin-1', createdAt: serverTimestamp(), lastAuditId: forProfAudit });
  addAudit(foreign, db, forProfAudit, 'professional.create', 'professional', 'prof-p4');
  foreign.set(doc(db, 'users/p4'), { ...base, professionalId: 'prof-p4', institutionIds: ['school-1'], lastAuditId: forAudit });
  addAudit(foreign, db, forAudit, 'user.create', 'user', 'p4');
  await assertFails(foreign.commit());
  await assertSucceeds(createOperationalUser(db, 'p5', base));

  // Alterar instituições do profissional sem sincronizar o usuário: negado; sincronizado: permitido.
  await assertFails(audited(db, 'professionals/prof-p5', { institutionIds: ['school-1', 'school-2'] },
    { action: 'professional.update', targetType: 'professional', targetId: 'prof-p5' }));
  const syncAudit = newAuditId();
  const sync = writeBatch(db);
  sync.update(doc(db, 'professionals/prof-p5'), { institutionIds: ['school-1', 'school-2'], lastAuditId: syncAudit });
  sync.update(doc(db, 'users/p5'), { institutionIds: ['school-1', 'school-2'], updatedAt: serverTimestamp(), lastAuditId: syncAudit });
  addAudit(sync, db, syncAudit, 'user.update', 'user', 'p5');
  addAudit(sync, db, `${syncAudit}-assoc`, 'association.update', 'user', 'p5');
  await assertSucceeds(sync.commit());

  // Família: exige estudante com familyUid apontando para a conta; um responsável por estudante.
  await environment.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    const stamps = { createdAt: new Date('2026-01-01'), updatedAt: new Date('2026-01-01'), createdBy: 'dir', updatedBy: 'dir' };
    await setDoc(doc(adminDb, 'students/est-1'), { name: 'Estudante', schoolInstitutionId: 'school-1', familyUid: null, active: true, ...stamps });
    await setDoc(doc(adminDb, 'students/est-2'), { name: 'Outro', schoolInstitutionId: 'school-1', familyUid: 'user-1', active: true, ...stamps });
  });
  const family = { ...base, email: 'fam.nova@exemplo.com', role: 'family', schoolRole: null, professionalId: null, institutionIds: [] };
  const familyBatch = (studentId, { studentIds = [studentId], linkStudent = true } = {}) => {
    const auditId = newAuditId();
    const batch = writeBatch(db);
    if (linkStudent) {
      batch.update(doc(db, `students/${studentId}`), { familyUid: 'f1', updatedAt: serverTimestamp(), updatedBy: 'admin-1' });
    }
    batch.set(doc(db, 'users/f1'), { ...family, studentIds, lastAuditId: auditId });
    addAudit(batch, db, auditId, 'user.create', 'user', 'f1');
    return batch.commit();
  };
  await assertFails(familyBatch('est-1', { studentIds: [], linkStudent: false }));
  await assertFails(familyBatch('est-1', { linkStudent: false }));
  await assertFails(familyBatch('est-2'));
  await assertSucceeds(familyBatch('est-1'));
});

// ------------------------------------------------------------------ P2-05

test('P2-05 (sondas P7/P7b): auditoria imposta pelas regras', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertSucceeds(createOperationalUser(db, 'aud-1', { ...schoolUserBase, email: 'aud1@exemplo.com' }));
  // P7: log avulso (sem alteração do alvo no mesmo batch) é negado.
  await assertFails(setDoc(doc(db, 'adminAuditLogs/forjado1'), {
    action: 'user.update', actorUid: 'admin-1', targetType: 'user', targetId: 'aud-1',
    before: null, after: null, createdAt: serverTimestamp(),
  }));
  // Log em nome de outro admin, com ação ou alvo inválidos: negado.
  const forged = (overrides) => {
    const id = newAuditId();
    const batch = writeBatch(db);
    batch.update(doc(db, 'users/aud-1'), { firstName: 'Outro', updatedAt: serverTimestamp(), lastAuditId: id });
    batch.set(doc(db, `adminAuditLogs/${id}`), {
      action: 'user.update', actorUid: 'admin-1', targetType: 'user', targetId: 'aud-1',
      before: null, after: null, createdAt: serverTimestamp(), ...overrides,
    });
    return batch.commit();
  };
  await assertFails(forged({ actorUid: 'admin-2' }));
  await assertFails(forged({ action: 'qualquer.coisa' }));
  await assertFails(forged({ targetType: 'institution' }));
  await assertFails(forged({ targetId: 'user-1' }));
  await assertFails(forged({ senha: 'x' }));
  await assertSucceeds(forged({}));
  // Alteração sem log, ou reaproveitando um log antigo: negada.
  await assertFails(updateDoc(doc(db, 'users/aud-1'), { firstName: 'Sem log', updatedAt: serverTimestamp() }));
  const current = await readAsAdminSdk('users/aud-1').then((d) => d.lastAuditId);
  await assertFails(updateDoc(doc(db, 'users/aud-1'), { firstName: 'Log velho', updatedAt: serverTimestamp(), lastAuditId: current }));
  // P7b: troca de role/subrole sem o log específico, e status sem log de status.
  await assertFails(userUpdate(db, 'aud-1', { schoolRole: 'director' }));
  await assertSucceeds(userUpdate(db, 'aud-1', { schoolRole: 'director' }, [['role', 'user.role.update']]));
  await assertFails(userUpdate(db, 'aud-1', { active: false }));
  await assertFails(userUpdate(db, 'aud-1', { active: false }, [['active', 'user.role.update']]));
  await assertSucceeds(userUpdate(db, 'aud-1', { active: false }, [['active', 'user.deactivate']]));
  // Logs são imutáveis e só o admin os lê.
  let logs = [];
  await environment.withSecurityRulesDisabled(async (context) => {
    logs = (await getDocs(collection(context.firestore(), 'adminAuditLogs'))).docs.map((d) => d.id);
  });
  await assertFails(updateDoc(doc(db, `adminAuditLogs/${logs[0]}`), { action: 'user.create' }));
  await assertFails(deleteDoc(doc(db, `adminAuditLogs/${logs[0]}`)));
  await assertFails(getDocs(collection(environment.authenticatedContext('user-1').firestore(), 'adminAuditLogs')));
});

test('P2-05 (sonda P14): schema das instituições e cadastros', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertFails(newInstitution(db, 'bad-1', { name: 1, type: 'school', active: true }));
  await assertFails(newInstitution(db, 'bad-2', { name: 'Escola', type: 'school', active: 'sim' }));
  await assertFails(newInstitution(db, 'bad-3', { name: 'Escola', type: 'Centro', active: true }));
  await assertFails(newInstitution(db, 'bad-4', { name: 'Escola', type: 'school', active: true, extra: true }));
  await assertFails(newInstitution(db, 'bad-5', { name: 'Escola', type: 'school', active: true, address: 'texto' }));
  await assertSucceeds(newInstitution(db, 'ok-1', {
    name: 'Escola Nova', type: 'school', active: true, cnpj: null, email: 'escola@exemplo.com', phone: null,
    address: { street: 'Rua Sintética', number: '1' },
  }));
  const instUpdate = (id, changes) => audited(db, `institutions/${id}`, { ...changes, updatedAt: serverTimestamp() },
    { action: 'institution.update', targetType: 'institution', targetId: id });
  // Tipo canônico é imutável; tipo legado pode ser normalizado.
  await assertFails(instUpdate('school-1', { type: 'ubs' }));
  await assertFails(instUpdate('school-1', { active: 'nao' }));
  await assertSucceeds(instUpdate('legacy-1', { type: 'school' }));
  // Redes e parâmetros: schema e auditoria.
  const network = (id, value) => {
    const auditId = newAuditId();
    const batch = writeBatch(db);
    batch.set(doc(db, `localNetworks/${id}`), {
      createdBy: 'admin-1', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), lastAuditId: auditId, ...value,
    });
    addAudit(batch, db, auditId, 'localNetwork.create', 'localNetwork', id);
    return batch.commit();
  };
  await assertFails(network('n-1', { name: 'Rede', institutionIds: 'x', active: true }));
  await assertSucceeds(network('n-2', { name: 'Rede Sintética', description: null, institutionIds: ['school-1'], active: true }));
  const parameter = (id, value, action = 'parameter.create') => {
    const auditId = newAuditId();
    const batch = writeBatch(db);
    batch.set(doc(db, `adminParameters/${id}`), {
      createdBy: 'admin-1', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), lastAuditId: auditId, ...value,
    });
    addAudit(batch, db, auditId, action, 'parameter', id);
    return batch.commit();
  };
  await assertFails(parameter('par-1', { title: 'Lista', items: 'a,b', active: true }));
  await assertFails(parameter('par-2', { title: 'Lista', items: ['a'], active: true }, 'institution.create'));
  await assertSucceeds(parameter('par-3', { title: 'Lista', items: ['a', 'b'], active: true }));
});

test('P2-05 (D-A01): perfis só se vinculam a instituições do tipo do perfil', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertFails(createOperationalUser(db, 't-ubs', { ...schoolUserBase, email: 't.ubs@exemplo.com' }, ['ubs-1']));
  await assertFails(createOperationalUser(db, 't-mix', { ...schoolUserBase, email: 't.mix@exemplo.com' }, ['school-1', 'ubs-1']));
  await assertFails(createOperationalUser(db, 't-legacy', { ...schoolUserBase, email: 't.leg@exemplo.com' }, ['legacy-1']));
  await assertFails(createOperationalUser(db, 'psi-school', {
    ...schoolUserBase, email: 'psi.esc@exemplo.com', role: 'health', schoolRole: null, healthRole: 'psychologist',
  }, ['school-1']));
  await environment.withSecurityRulesDisabled((context) =>
    setDoc(doc(context.firestore(), 'institutions/school-off'), { name: 'Escola inativa', type: 'school', active: false }));
  await assertFails(createOperationalUser(db, 't-off', { ...schoolUserBase, email: 't.off@exemplo.com' }, ['school-off']));
  await assertFails(createOperationalUser(db, 't-many', { ...schoolUserBase, email: 't.many@exemplo.com' },
    ['school-1', 'school-2', 'school-1', 'school-2', 'school-1', 'school-2']));
  await assertSucceeds(createOperationalUser(db, 't-ok', { ...schoolUserBase, email: 't.ok@exemplo.com' }, ['school-1', 'school-2']));
  // Profissional com função diferente da conta: negado (listas de atribuição).
  const mismatch = writeBatch(db);
  const mAudit = newAuditId();
  const mUser = newAuditId();
  mismatch.set(doc(db, 'professionals/prof-mm'), {
    name: 'X', userId: 'mm', institutionIds: ['school-1'], active: true, role: 'school', subrole: 'director',
    createdBy: 'admin-1', createdAt: serverTimestamp(), lastAuditId: mAudit,
  });
  addAudit(mismatch, db, mAudit, 'professional.create', 'professional', 'prof-mm');
  mismatch.set(doc(db, 'users/mm'), {
    ...schoolUserBase, email: 'mm@exemplo.com', professionalId: 'prof-mm', institutionIds: ['school-1'], lastAuditId: mUser,
  });
  addAudit(mismatch, db, mUser, 'user.create', 'user', 'mm');
  await assertFails(mismatch.commit());
});

test('P2-05 (sonda P9): contatos de profissionais com leitura mínima', async () => {
  const admin = environment.authenticatedContext('admin-1').firestore();
  await assertSucceeds(createOperationalUser(admin, 'prof-a', { ...schoolUserBase, email: 'pa@exemplo.com' }, ['school-1']));
  await assertSucceeds(createOperationalUser(admin, 'dir-a', { ...schoolUserBase, email: 'da@exemplo.com', schoolRole: 'director' }, ['school-1']));
  await assertSucceeds(createOperationalUser(admin, 'dir-b', { ...schoolUserBase, email: 'db@exemplo.com', schoolRole: 'director' }, ['school-2']));
  const family = environment.authenticatedContext('user-1').firestore();
  const teacher = environment.authenticatedContext('prof-a').firestore();
  const directorA = environment.authenticatedContext('dir-a').firestore();
  const directorB = environment.authenticatedContext('dir-b').firestore();
  await assertFails(getDoc(doc(family, 'professionals/prof-prof-a')));
  await assertFails(getDocs(collection(family, 'professionals')));
  // Professor da mesma escola lê (nomes dos professores do caso); outra escola não.
  await assertSucceeds(getDoc(doc(teacher, 'professionals/prof-dir-a')));
  await assertFails(getDoc(doc(directorB, 'professionals/prof-prof-a')));
  await assertSucceeds(getDoc(doc(directorA, 'professionals/prof-prof-a')));
  // Consulta do app (teachersOf) aceita para a Direção da própria escola.
  const teachersOf = (db, schoolId) => getDocs(query(collection(db, 'professionals'),
    where('active', '==', true), where('institutionIds', 'array-contains', schoolId), where('subrole', '==', 'teacher')));
  await assertSucceeds(teachersOf(directorA, 'school-1'));
  await assertSucceeds(teachersOf(teacher, 'school-1'));
  await assertFails(teachersOf(directorB, 'school-1'));
  await assertFails(teachersOf(family, 'school-1'));
});

// ------------------------------------------------------------------ P2-06

test('P2-06: vínculo conta↔profissional único e bidirecional (sonda P8)', async () => {
  const db = environment.authenticatedContext('admin-1').firestore();
  await assertSucceeds(createOperationalUser(db, 'u8', { ...schoolUserBase, email: 'u8@exemplo.com' }));
  // P8: apontar a conta para outro profissional sem atualizar os dois lados.
  await assertFails(userUpdate(db, 'u8', { professionalId: 'prof-inexistente' }));
  // Segundo profissional para a mesma conta, sem soltar o anterior: negado.
  const second = () => {
    const auditId = newAuditId();
    const batch = writeBatch(db);
    batch.set(doc(db, 'professionals/prof-u8-b'), {
      name: 'Nova Pessoa', userId: 'u8', institutionIds: ['school-1'], active: true, role: 'school', subrole: 'teacher',
      createdBy: 'admin-1', createdAt: serverTimestamp(), lastAuditId: auditId,
    });
    batch.update(doc(db, 'users/u8'), { professionalId: 'prof-u8-b', updatedAt: serverTimestamp(), lastAuditId: auditId });
    addAudit(batch, db, auditId, 'professional.create', 'professional', 'prof-u8-b');
    return batch;
  };
  await assertFails(second().commit());
  // Soltando o anterior no mesmo batch: permitido.
  const swap = second();
  const unlinkAudit = newAuditId();
  swap.update(doc(db, 'professionals/prof-u8'), { userId: null, lastAuditId: unlinkAudit });
  addAudit(swap, db, unlinkAudit, 'professional.update', 'professional', 'prof-u8');
  await assertSucceeds(swap.commit());
});

test('P2-06: operações concorrentes não duplicam vínculos', async () => {
  const db1 = environment.authenticatedContext('admin-1').firestore();
  const db2 = environment.authenticatedContext('admin-2').firestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const stamps = { createdAt: new Date('2026-01-01'), updatedAt: new Date('2026-01-01'), createdBy: 'dir', updatedBy: 'dir' };
    await setDoc(doc(context.firestore(), 'students/est-c'), { name: 'Estudante', schoolInstitutionId: 'school-1', familyUid: null, active: true, ...stamps });
  });
  // Duas contas familiares disputando o mesmo estudante ao mesmo tempo.
  const family = (db, uid, actor) => {
    const auditId = newAuditId();
    const batch = writeBatch(db);
    batch.update(doc(db, 'students/est-c'), { familyUid: uid, updatedAt: serverTimestamp(), updatedBy: actor });
    batch.set(doc(db, `users/${uid}`), {
      firstName: 'Fam', lastName: uid, name: `Fam ${uid}`, email: `${uid}@exemplo.com`, role: 'family',
      schoolRole: null, healthRole: null, active: true, professionalId: null, institutionIds: [],
      studentIds: ['est-c'], createdAt: serverTimestamp(), updatedAt: serverTimestamp(), createdBy: actor,
      lastAccessAt: null, lastAuditId: auditId,
    });
    addAudit(batch, db, auditId, 'user.create', 'user', uid, actor);
    return batch.commit();
  };
  const results = await Promise.allSettled([family(db1, 'fam-x', 'admin-1'), family(db2, 'fam-y', 'admin-2')]);
  assertOneWinner(results);
  const student = await readAsAdminSdk('students/est-c');
  const winner = results[0].status === 'fulfilled' ? 'fam-x' : 'fam-y';
  if (student.familyUid !== winner) throw new Error(`familyUid inconsistente: ${student.familyUid}`);

  // Dois profissionais disputando a mesma conta ao mesmo tempo.
  await environment.withSecurityRulesDisabled((context) => setDoc(doc(context.firestore(), 'users/solo'), {
    name: 'Solo', email: 'solo@exemplo.com', role: 'escola', active: true, professionalId: null,
  }));
  const claim = (db, pid, actor) => {
    const auditId = newAuditId();
    const batch = writeBatch(db);
    batch.set(doc(db, `professionals/${pid}`), {
      name: 'Solo', userId: 'solo', institutionIds: ['school-1'], active: true,
      createdBy: actor, createdAt: serverTimestamp(), lastAuditId: auditId,
    });
    batch.update(doc(db, 'users/solo'), { professionalId: pid, institutionIds: ['school-1'], updatedAt: serverTimestamp(), lastAuditId: auditId });
    addAudit(batch, db, auditId, 'professional.create', 'professional', pid, actor);
    return batch.commit();
  };
  assertOneWinner(await Promise.allSettled([claim(db1, 'prof-solo-1', 'admin-1'), claim(db2, 'prof-solo-2', 'admin-2')]));
});

async function readAsAdminSdk(docPath) {
  let value;
  await environment.withSecurityRulesDisabled(async (context) => {
    value = (await getDoc(doc(context.firestore(), docPath))).data();
  });
  return value;
}

function assertOneWinner(results) {
  const ok = results.filter((r) => r.status === 'fulfilled').length;
  if (ok !== 1) {
    throw new Error(`esperava exatamente 1 operação aceita, obtive ${ok}: ${results.map((r) => r.status).join(', ')}`);
  }
}
