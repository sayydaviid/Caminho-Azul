'use strict';

// Seed sintético — fases A e B (P0-02). Somente Firebase Emulator Suite, projeto demo-*.
// Uso: com os emuladores ativos (npm --prefix scripts run emulators),
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
//   npm --prefix scripts run seed:emulator
// Idempotente: IDs fixos com prefixo "seed-"; reexecutar sobrescreve os mesmos documentos.

const { assertEmulatorOnly, SeedGuardError } = require('./seed/guard');

let projectId;
try {
  projectId = assertEmulatorOnly(process.env);
} catch (error) {
  if (error instanceof SeedGuardError) {
    console.error(`Seed abortado: ${error.message}`);
    process.exit(1);
  }
  throw error;
}

const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const data = require('./seed/data');
const domain = require('./seed/domain');

// Fase B: SEED_DOMAIN=0 aplica só contas e cadastros (fase A).
const WITH_DOMAIN = process.env.SEED_DOMAIN !== '0';

// Senha exclusiva das contas sintéticas do emulador local. Pode ser trocada por SEED_PASSWORD.
const PASSWORD = process.env.SEED_PASSWORD || 'Sintetico#2026';

// Valores de role gravados. Desde P1-17 o app lê CANONICAL_EN (D-08).
// SEED_ROLE_VALUES=LEGACY_PT grava valores antigos para testar a normalização pelo admin.
const ROLE_VALUES_KEY = process.env.SEED_ROLE_VALUES || 'CANONICAL_EN';
const MAPPING = data.ROLE_VALUES[ROLE_VALUES_KEY];
if (!MAPPING) {
  console.error('Seed abortado: SEED_ROLE_VALUES deve ser LEGACY_PT ou CANONICAL_EN.');
  process.exit(1);
}

async function upsertAuthUser(auth, user) {
  const record = {
    email: user.email,
    password: PASSWORD,
    displayName: data.fullName(user),
    emailVerified: true,
    disabled: false,
  };
  try {
    await auth.getUser(user.uid);
    await auth.updateUser(user.uid, record);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await auth.createUser({ uid: user.uid, ...record });
  }
}

async function main() {
  initializeApp({ projectId });
  const auth = getAuth();
  const db = getFirestore();
  const now = FieldValue.serverTimestamp();
  const stamps = { createdAt: now, updatedAt: now };
  const batch = db.batch();

  for (const inst of data.institutions) {
    batch.set(db.doc(`institutions/${inst.id}`), {
      name: inst.name,
      type: inst.type,
      cnpj: null,
      email: null,
      phone: null,
      address: {
        street: 'Rua Sintética', number: '100', complement: null,
        district: 'Bairro Fictício', city: 'Cidade Sintética', state: 'PA', zipCode: '00000-000',
      },
      active: true,
      createdBy: 'seed-admin',
      ...stamps,
    });
  }

  batch.set(db.doc('localNetworks/seed-rede-1'), {
    name: 'Rede Local Sintética',
    description: 'Agrupamento fictício para demonstração.',
    institutionIds: data.institutions.map((inst) => inst.id),
    active: true,
    createdBy: 'seed-admin',
    ...stamps,
  });

  const seedUsers = WITH_DOMAIN ? [...data.users, domain.DEMO_FAMILY] : data.users;
  for (const user of seedUsers) {
    await upsertAuthUser(auth, user);
    if (user.noProfile) continue;
    batch.set(db.doc(`users/${user.uid}`), data.userDoc(user, MAPPING, stamps));

    if (data.isProfessional(user)) {
      const professionalId = data.professionalIdOf(user);
      batch.set(db.doc(`professionals/${professionalId}`), {
        firstName: user.first,
        lastName: user.last,
        name: data.fullName(user),
        email: user.email,
        phone: null,
        specialty: null,
        registrationNumber: `SINT-${professionalId.slice(-6).toUpperCase()}`,
        userId: user.uid,
        institutionIds: user.institutions,
        role: MAPPING.role[user.role],
        subrole: user.schoolRole ? MAPPING.schoolRole[user.schoolRole] : data.HEALTH_ROLE[user.healthRole],
        active: true,
        createdBy: 'seed-admin',
        ...stamps,
      });
    }
  }

  for (const { id: studentId, createdBy, ...student } of [data.student, data.unlinkedStudent]) {
    batch.set(db.doc(`students/${studentId}`), {
      ...student,
      active: true,
      createdBy,
      updatedBy: createdBy,
      ...stamps,
    });
  }

  await batch.commit();
  if (WITH_DOMAIN) await seedDomain(db);
  await verify(auth, db);
}

/// Fase B: histórias de acompanhamento coerentes (datas nos últimos dias).
async function seedDomain(db) {
  const base = Date.now() - 3 * 24 * 60 * 60 * 1000;
  const docs = domain.buildDomain((minutes) => new Date(base + minutes * 60 * 1000));
  // Limite de 500 escritas por batch.
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    for (const [path, value] of docs.slice(i, i + 400)) batch.set(db.doc(path), value);
    await batch.commit();
  }
  domainSummary = `Fase B: ${docs.length} documentos (2 casos, observações, registro, encaminhamento, `
    + `devolutiva, eventos e ${docs.filter(([p]) => p.startsWith('notifications/')).length} notificações).`;
}

let domainSummary = 'Fase B não aplicada (SEED_DOMAIN=0).';

async function verify(auth, db) {
  const problems = [];
  for (const user of data.users) {
    const record = await auth.getUser(user.uid);
    if (record.email !== user.email) problems.push(`Auth divergente: ${user.uid}`);
    const profile = await db.doc(`users/${user.uid}`).get();
    if (profile.exists === Boolean(user.noProfile)) problems.push(`Perfil inesperado: ${user.uid}`);
    if (data.isProfessional(user)) {
      const prof = await db.doc(`professionals/${profile.get('professionalId')}`).get();
      if (prof.get('userId') !== user.uid) problems.push(`Vínculo profissional inconsistente: ${user.uid}`);
      const missing = user.institutions.filter((id) => !(prof.get('institutionIds') || []).includes(id));
      if (missing.length) problems.push(`Instituição ausente no profissional: ${user.uid}`);
    }
  }
  const student = await db.doc(`students/${data.STUDENT_ID}`).get();
  const family = await db.doc(`users/${data.student.familyUid}`).get();
  if (student.get('familyUid') !== family.id || !(family.get('studentIds') || []).includes(data.STUDENT_ID)) {
    problems.push('Vínculo estudante–família inconsistente');
  }

  if (problems.length) {
    console.error(`Seed concluído com inconsistências:\n- ${problems.join('\n- ')}`);
    process.exit(1);
  }
  console.log(`Seed sintético aplicado no projeto ${projectId} (emuladores locais, roles ${ROLE_VALUES_KEY}).`);
  console.log(domainSummary);
  console.log(`Instituições: ${data.institutions.length} · Contas: ${data.users.length} (perfis: ${data.users.filter((u) => !u.noProfile).length}) · Estudantes: 2`);
  for (const user of data.users) {
    const doc = user.noProfile ? null : data.userDoc(user, MAPPING, {});
    const kind = doc ? [doc.role, doc.schoolRole, doc.healthRole].filter(Boolean).join('/') : 'sem perfil';
    console.log(`  ${user.email.padEnd(36)} ${kind}${user.active === false ? ' (inativa)' : ''}`);
  }
  console.log('Senha das contas: valor de SEED_PASSWORD ou o padrão sintético documentado em scripts/seed_emulator.js.');
}

main().catch((error) => {
  console.error('Falha no seed:', error.message);
  process.exit(1);
});
