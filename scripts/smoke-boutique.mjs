// Smoke test de l'API boutique. Usage : npm run smoke (Strapi doit tourner).
// Les tasks suivantes ajoutent leurs sections avant le bilan final.
const BASE = process.env.STRAPI_URL ?? 'http://localhost:1337';
const PASSWORD = 'Smoke-test-123';

let failures = 0;
function check(name, condition, detail = '') {
  if (condition) {
    console.log(`✔ ${name}`);
  } else {
    failures += 1;
    console.log(`✘ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

async function api(path, { method = 'GET', token, body } = {}) {
  const headers = {};
  if (body !== undefined) headers['content-type'] = 'application/json';
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    // corps non JSON
  }
  return { res, status: res.status, json };
}

const register = (username, email) =>
  api('/api/auth/local/register', { method: 'POST', body: { username, email, password: PASSWORD } });
const login = (identifier) =>
  api('/api/auth/local', { method: 'POST', body: { identifier, password: PASSWORD } });

// État partagé entre les sections.
const state = { a: {}, b: {} };

async function sectionCatalogue() {
  const { status, json } = await api(
    '/api/produits?populate[0]=image&populate[1]=category&pagination[pageSize]=100',
  );
  check('GET /api/produits → 200', status === 200, `status ${status}`);
  const produits = json?.data ?? [];
  check('au moins un produit', produits.length > 0, `${produits.length}`);
  check(
    'chaque produit a un price non nul',
    produits.every((p) => p.price !== null && p.price !== undefined),
  );
  check('aucun produit n\'expose panier', produits.every((p) => !('panier' in p)));
  state.produits = produits;
}

async function sectionComptes() {
  const ts = Date.now();
  for (const [key, suffix] of [['a', 'a'], ['b', 'b']]) {
    const username = `smoke-${ts}-${suffix}`;
    const email = `${username}@example.test`;
    const r = await register(username, email);
    check(
      `register ${key.toUpperCase()} → 200 (jwt, refreshToken, user.username)`,
      r.status === 200 && !!r.json?.jwt && !!r.json?.refreshToken && !!r.json?.user?.username,
      `status ${r.status} ${JSON.stringify(r.json?.error ?? '')}`,
    );
    state[key] = { username, email, jwt: r.json?.jwt };
  }
  const l = await login(state.a.email);
  const cookies = l.res.headers.getSetCookie();
  check('login A → 200 avec jwt', l.status === 200 && !!l.json?.jwt, `status ${l.status}`);
  check(
    'login A pose le cookie strapi_up_refresh',
    cookies.some((c) => c.startsWith('strapi_up_refresh=')),
  );
  if (l.json?.jwt) state.a.jwt = l.json.jwt;
}

async function sectionPanierAnonyme() {
  const { status } = await api('/api/mon-panier');
  check('GET /api/mon-panier sans jeton → 401/403', status === 401 || status === 403, `status ${status}`);
}

try {
  await sectionCatalogue();
  await sectionComptes();
  await sectionPanierAnonyme();
} catch (e) {
  failures += 1;
  console.log(`✘ exception — ${e?.message ?? e}`);
}

console.log(failures === 0 ? '\nTous les checks passent.' : `\n${failures} check(s) en échec.`);
process.exit(failures === 0 ? 0 : 1);
