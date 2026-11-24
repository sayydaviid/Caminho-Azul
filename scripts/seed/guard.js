'use strict';

// Proteções do seed sintético: só roda contra o Firebase Emulator Suite local,
// com projeto demo-*. Qualquer violação aborta antes de inicializar o SDK.

const LOOPBACK_HOSTS = new Set(['127.0.0.1', 'localhost', '[::1]', '::1']);
const DEFAULT_PROJECT_ID = 'demo-caminhoazul';

class SeedGuardError extends Error {}

function hostOf(value) {
  const text = String(value || '').trim();
  if (text.startsWith('[')) return text.slice(0, text.indexOf(']') + 1);
  return text.split(':')[0];
}

function assertLoopback(name, value) {
  if (!value) {
    throw new SeedGuardError(`${name} não definido. O seed só roda contra os emuladores locais.`);
  }
  if (!LOOPBACK_HOSTS.has(hostOf(value))) {
    throw new SeedGuardError(`${name}=${value} não aponta para a máquina local.`);
  }
}

/**
 * Valida o ambiente e devolve o projectId seguro a ser usado.
 * @param {Record<string, string | undefined>} env
 */
function assertEmulatorOnly(env) {
  assertLoopback('FIRESTORE_EMULATOR_HOST', env.FIRESTORE_EMULATOR_HOST);
  assertLoopback('FIREBASE_AUTH_EMULATOR_HOST', env.FIREBASE_AUTH_EMULATOR_HOST);

  if (env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new SeedGuardError(
      'GOOGLE_APPLICATION_CREDENTIALS está definido. Remova a credencial antes de rodar o seed.',
    );
  }

  const candidates = [env.SEED_PROJECT_ID, env.GCLOUD_PROJECT, env.GOOGLE_CLOUD_PROJECT]
    .filter((value) => value && value.trim());
  const projectId = (candidates[0] || DEFAULT_PROJECT_ID).trim();
  for (const value of [projectId, ...candidates]) {
    if (!value.trim().startsWith('demo-')) {
      throw new SeedGuardError(`Projeto "${value}" recusado: use somente IDs demo-*.`);
    }
  }
  return projectId;
}

module.exports = { assertEmulatorOnly, SeedGuardError, DEFAULT_PROJECT_ID };
