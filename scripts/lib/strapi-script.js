const path = require('path');
const fs = require('fs');

// Chargement de cms-headless/.env pour les variables non definies (en local).
// Sur Heroku il n'y a pas de .env : les variables viennent de la config de l'app.
function loadEnv() {
  const envPath = path.resolve(__dirname, '../../.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    if (!process.env[key]) process.env[key] = trimmed.slice(eqIdx + 1).trim();
  }
}

// Demarre Strapi (build TypeScript dans dist/), execute `task`, puis arrete
// Strapi proprement. Le code de sortie reflete le succes de `task`.
async function runWithStrapi(label, task) {
  loadEnv();
  const { createStrapi } = require('@strapi/strapi');
  console.log(`🚀 ${label} — initialisation de Strapi 5...`);
  const strapi = await createStrapi({
    distDir: path.resolve(__dirname, '../../dist'),
  }).load();

  let exitCode = 0;
  try {
    await task(strapi);
  } catch (err) {
    console.error(`💥 ${label} :`, err.message);
    exitCode = 1;
  }
  try {
    await strapi.destroy();
  } catch (_) {}
  process.exit(exitCode);
}

module.exports = { runWithStrapi };
