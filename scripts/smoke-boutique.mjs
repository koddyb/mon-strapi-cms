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

async function sectionPanier() {
  const [p1, p2] = state.produits;
  const price1 = Number(p1.price);
  const A = state.a.jwt;
  const B = state.b.jwt;
  const post = (token, productDocumentId, quantity) =>
    api('/api/mon-panier/lignes', { method: 'POST', token, body: { productDocumentId, quantity } });

  let r = await api('/api/mon-panier', { token: A });
  check('A : GET mon-panier → 200, 0 ligne', r.status === 200 && r.json?.data?.items?.length === 0, `status ${r.status}`);

  r = await post(A, p1.documentId, 2);
  const line = r.json?.data?.items?.[0];
  check(
    'A : ajoute P1 x2 → total = 2 x prix',
    r.status === 200 && line?.quantity === 2 && r.json.data.total === Math.round(2 * price1 * 100) / 100,
    `status ${r.status} ${JSON.stringify(r.json?.error ?? r.json?.data?.total)}`,
  );
  state.a.lineId = line?.documentId;

  r = await post(A, p1.documentId, 1);
  check(
    'A : même produit x1 → une ligne, quantity 3',
    r.status === 200 && r.json?.data?.items?.length === 1 && r.json.data.items[0].quantity === 3,
    `status ${r.status}`,
  );

  for (const q of [0, 100, 'abc', 1.5]) {
    r = await post(A, p1.documentId, q);
    check(`A : quantity ${JSON.stringify(q)} → 400`, r.status === 400, `status ${r.status}`);
  }
  r = await post(A, p1.documentId, 97);
  check('A : cumul 100 → 400', r.status === 400, `status ${r.status}`);

  r = await api(`/api/mon-panier/lignes/${state.a.lineId}`, { method: 'PUT', token: B, body: { quantity: 5 } });
  check('B : PUT ligne de A → 404', r.status === 404, `status ${r.status}`);
  r = await api(`/api/mon-panier/lignes/${state.a.lineId}`, { method: 'DELETE', token: B });
  check('B : DELETE ligne de A → 404', r.status === 404, `status ${r.status}`);
  r = await api('/api/mon-panier', { token: B });
  check('B : GET mon-panier → 0 ligne', r.status === 200 && r.json?.data?.items?.length === 0, `status ${r.status}`);

  r = await api(`/api/mon-panier/lignes/${state.a.lineId}`, { method: 'PUT', token: A, body: { quantity: 1 } });
  check('A : PUT ligne à 1 → quantity 1', r.status === 200 && r.json?.data?.items?.[0]?.quantity === 1, `status ${r.status}`);
  r = await post(A, p2.documentId, 1);
  check('A : ajoute P2 → 2 lignes', r.status === 200 && r.json?.data?.items?.length === 2, `status ${r.status}`);
}

async function sectionCommande() {
  const [p1, p2] = state.produits;
  const A = state.a.jwt;
  const B = state.b.jwt;
  const subtotal =
    (Math.round(Number(p1.price) * 100) + Math.round(Number(p2.price) * 100)) / 100;
  const expected = subtotal + 4;

  let r = await api('/api/checkout/commandes', { method: 'POST', token: A });
  check(
    'A : checkout frontend → 201, total avec livraison et orderId',
    r.status === 201 &&
      r.json?.data?.total === expected &&
      r.json.data.lineItems?.length === 2 &&
      r.json.data.status === 'pending' &&
      !!r.json.data.orderId,
    `status ${r.status} total ${r.json?.data?.total} attendu ${expected} ${JSON.stringify(r.json?.error ?? '')}`,
  );
  state.a.orderId = r.json?.data?.orderId;

  r = await api('/api/checkout/commandes', { method: 'POST', token: A });
  check(
    'A : checkout répété → 400 panier vide',
    r.status === 400 && r.json?.error?.message === 'Le panier est vide.',
    `status ${r.status} ${JSON.stringify(r.json?.error ?? '')}`,
  );
  r = await api('/api/mon-panier', { token: A });
  check('A : mon-panier → 0 ligne', r.status === 200 && r.json?.data?.items?.length === 0, `status ${r.status}`);
  r = await api('/api/commandes/miennes', { token: A });
  check(
    'A : commandes/miennes → 1 commande, 2 lineItems',
    r.status === 200 &&
      r.json?.data?.length === 1 &&
      r.json.data[0].lineItems?.length === 2 &&
      r.json.data[0].status === 'pending' &&
      !('user' in r.json.data[0]),
    `status ${r.status} ${JSON.stringify(r.json?.error ?? '')}`,
  );

  r = await api(`/api/mes-commandes/${state.a.orderId}`, { token: A });
  check('A : détail de sa commande → 200', r.status === 200 && r.json?.data?.status === 'pending', `status ${r.status}`);
  r = await api(`/api/mes-commandes/${state.a.orderId}`, { token: B });
  check('B : détail de la commande de A → 404', r.status === 404, `status ${r.status}`);

  r = await api(`/api/commandes/${state.a.orderId}/simulation`, { method: 'POST', token: A });
  const readyAt = Date.parse(r.json?.data?.readyAt ?? '');
  check(
    'A : démarrer simulation → readyAt dans le futur',
    r.status === 200 && Number.isFinite(readyAt) && readyAt > Date.now(),
    `status ${r.status}`,
  );
  r = await api(`/api/commandes/${state.a.orderId}/confirmer-paiement`, { method: 'POST', token: A });
  check('A : confirmation anticipée → 400', r.status === 400, `status ${r.status}`);
  if (Number.isFinite(readyAt)) {
    await new Promise((resolve) => setTimeout(resolve, Math.max(0, readyAt - Date.now() + 100)));
  }
  r = await api(`/api/commandes/${state.a.orderId}/confirmer-paiement`, { method: 'POST', token: A });
  check('A : confirmation après simulation → paid', r.status === 200 && r.json?.data?.status === 'paid', `status ${r.status}`);
  const address = {
    fullName: 'Client Smoke',
    line1: '1 rue du Test',
    postalCode: '75001',
    city: 'Paris',
    country: 'France',
  };
  r = await api(`/api/commandes/${state.a.orderId}/adresse-livraison`, {
    method: 'PUT',
    token: A,
    body: address,
  });
  check('A : enregistrer adresse après paiement → 200', r.status === 200, `status ${r.status}`);
  r = await api(`/api/commandes/${state.a.orderId}/adresse-livraison`, {
    method: 'PUT',
    token: B,
    body: address,
  });
  check('B : adresse sur commande de A → 404', r.status === 404, `status ${r.status}`);

  r = await api('/api/mes-commandes', { token: B });
  check('B : mes-commandes → 0 commande', r.status === 200 && r.json?.data?.length === 0, `status ${r.status}`);

  r = await api('/api/mon-panier/lignes', { method: 'POST', token: B, body: { productDocumentId: p1.documentId, quantity: 1 } });
  check('B : ajoute P1 → 200', r.status === 200, `status ${r.status}`);
  r = await api('/api/mon-panier/commander', { method: 'POST', token: B, body: { total: 0.01 } });
  check(
    'B : route de compatibilité → prix serveur + livraison',
    r.status === 201 && r.json?.data?.total === Number(p1.price) + 4,
    `status ${r.status} total ${r.json?.data?.total}`,
  );
  r = await api('/api/mes-commandes');
  check('mes-commandes sans jeton → 401/403', r.status === 401 || r.status === 403, `status ${r.status}`);
  r = await api('/api/commandes', { token: A });
  check('CRUD générique des commandes désactivé → 404', r.status === 404, `status ${r.status}`);
}

async function sectionConcurrence() {
  const username = `smoke-${Date.now()}-race`;
  const email = `${username}@example.test`;
  const reg = await register(username, email);
  const T = reg.json?.jwt;
  check('register utilisateur course → 200', reg.status === 200 && !!T, `status ${reg.status}`);
  const prods = state.produits.slice(0, 3);
  check('au moins 3 produits publiés pour la course', prods.length === 3, `${prods.length}`);

  const adds = await Promise.all(
    prods.map((p) =>
      api('/api/mon-panier/lignes', { method: 'POST', token: T, body: { productDocumentId: p.documentId, quantity: 1 } }),
    ),
  );
  check('3 ajouts parallèles (1er panier) → 200 x3', adds.every((a) => a.status === 200), adds.map((a) => a.status).join(','));
  let r = await api('/api/mon-panier', { token: T });
  check('mon-panier → 3 lignes après 3 ajouts parallèles', r.json?.data?.items?.length === 3, `${r.json?.data?.items?.length} lignes`);

  const outs = await Promise.all([1, 2, 3].map(() => api('/api/mon-panier/commander', { method: 'POST', token: T })));
  const codes = outs.map((o) => o.status).sort();
  check('3 commander parallèles → un seul 201, deux 400', codes.join(',') === '201,400,400', codes.join(','));
  check(
    'les 400 disent « Le panier est vide. »',
    outs.filter((o) => o.status === 400).every((o) => o.json?.error?.message === 'Le panier est vide.'),
  );
  r = await api('/api/mes-commandes', { token: T });
  check('mes-commandes → exactement 1 commande', r.status === 200 && r.json?.data?.length === 1, `${r.json?.data?.length}`);
}

try {
  await sectionCatalogue();
  await sectionComptes();
  await sectionPanierAnonyme();
  await sectionPanier();
  await sectionCommande();
  await sectionConcurrence();
} catch (e) {
  failures += 1;
  console.log(`✘ exception — ${e?.message ?? e}`);
}

console.log(failures === 0 ? '\nTous les checks passent.' : `\n${failures} check(s) en échec.`);
process.exit(failures === 0 ? 0 : 1);
