#!/usr/bin/env node

const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'caminhoazul';
const email = normalizeEmail(process.env.ADMIN_EMAIL);
const password = process.env.ADMIN_PASSWORD;
const name = (process.env.ADMIN_NAME || 'Administrador Caminho Azul').trim();
const uid = process.env.ADMIN_UID;

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});

async function main() {
  validateInput();

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });

  const auth = admin.auth();
  const firestore = admin.firestore();
  const user = await runStep('Auth: localizar ou criar usuario', () =>
    findOrCreateUser(auth),
  );
  const existingClaims = user.customClaims || {};

  await runStep('Auth: definir custom claim admin', () =>
    auth.setCustomUserClaims(user.uid, {
      ...existingClaims,
      role: 'admin',
    }),
  );

  const profileRef = firestore.collection('users').doc(user.uid);
  const profileSnapshot = await runStep('Firestore: ler perfil users/{uid}', () =>
    profileRef.get(),
  );
  const now = admin.firestore.FieldValue.serverTimestamp();
  const nameParts = name.split(/\s+/).filter(Boolean);
  const profile = {
    firstName: nameParts.shift() || name,
    lastName: nameParts.join(' '),
    name,
    email: user.email || email,
    role: 'admin',
    active: true,
    updatedAt: now,
  };

  if (!profileSnapshot.exists) {
    profile.createdAt = now;
    profile.createdBy = user.uid;
    profile.professionalId = null;
    profile.lastAccessAt = null;
  }

  await runStep('Firestore: criar ou atualizar perfil admin', () =>
    profileRef.set(profile, { merge: true }),
  );

  console.log(`Administrador configurado: ${user.uid}`);
  console.log('Saia e entre novamente no app para renovar o token.');
}

async function runStep(label, action) {
  process.stdout.write(`${label}... `);

  try {
    const result = await action();
    console.log('OK');
    return result;
  } catch (error) {
    console.log('FALHOU');
    console.error(`Etapa com falha: ${label}`);
    throw error;
  }
}

async function findOrCreateUser(auth) {
  if (uid) {
    return auth.getUser(uid);
  }

  try {
    return await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
  }

  return auth.createUser({
    email,
    password,
    displayName: name,
    disabled: false,
  });
}

function validateInput() {
  if (!uid && !email) {
    throw new Error('Defina ADMIN_EMAIL ou ADMIN_UID.');
  }

  if (!uid && (!password || password.length < 6)) {
    throw new Error('Defina ADMIN_PASSWORD com pelo menos 6 caracteres.');
  }
}

function normalizeEmail(value) {
  return value ? value.trim().toLowerCase() : undefined;
}
