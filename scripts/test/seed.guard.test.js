'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { assertEmulatorOnly, SeedGuardError } = require('../seed/guard');

const local = {
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
};

test('aceita emuladores locais e usa demo-caminhoazul por padrão', () => {
  assert.equal(assertEmulatorOnly(local), 'demo-caminhoazul');
  assert.equal(
    assertEmulatorOnly({ ...local, FIRESTORE_EMULATOR_HOST: 'localhost:8080' }),
    'demo-caminhoazul',
  );
});

test('recusa execução sem as variáveis dos emuladores', () => {
  assert.throws(() => assertEmulatorOnly({}), SeedGuardError);
  assert.throws(
    () => assertEmulatorOnly({ FIRESTORE_EMULATOR_HOST: local.FIRESTORE_EMULATOR_HOST }),
    SeedGuardError,
  );
  assert.throws(
    () => assertEmulatorOnly({ FIREBASE_AUTH_EMULATOR_HOST: local.FIREBASE_AUTH_EMULATOR_HOST }),
    SeedGuardError,
  );
});

test('recusa hosts que não sejam da máquina local', () => {
  assert.throws(
    () => assertEmulatorOnly({ ...local, FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' }),
    SeedGuardError,
  );
  assert.throws(
    () => assertEmulatorOnly({ ...local, FIREBASE_AUTH_EMULATOR_HOST: '192.168.0.10:9099' }),
    SeedGuardError,
  );
});

test('recusa projetos que não sejam demo-*', () => {
  assert.throws(() => assertEmulatorOnly({ ...local, SEED_PROJECT_ID: 'caminhoazul' }), SeedGuardError);
  assert.throws(() => assertEmulatorOnly({ ...local, GCLOUD_PROJECT: 'caminhoazul' }), SeedGuardError);
  assert.throws(
    () => assertEmulatorOnly({ ...local, SEED_PROJECT_ID: 'demo-x', GCLOUD_PROJECT: 'caminhoazul' }),
    SeedGuardError,
  );
  assert.equal(assertEmulatorOnly({ ...local, SEED_PROJECT_ID: 'demo-outro' }), 'demo-outro');
});

test('recusa execução com credencial de conta de serviço no ambiente', () => {
  assert.throws(
    () => assertEmulatorOnly({ ...local, GOOGLE_APPLICATION_CREDENTIALS: 'C:/x.json' }),
    SeedGuardError,
  );
});
