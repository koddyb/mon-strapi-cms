// Supprime, EN LOCAL UNIQUEMENT, les comptes generes par les tests automatises
// (smoke, Playwright...) : tout compte en @example.test qui n'est pas un client
// de test du seed, avec ses paniers, lignes de panier et commandes.
// Lance via `npm run cleanup:test-accounts`, qui fait un `npm run backup` avant.
const { runWithStrapi } = require('./lib/strapi-script');
const { TEST_CUSTOMERS, TEST_EMAIL_DOMAIN } = require('./lib/test-customers');

const USER_UID = 'plugin::users-permissions.user';
const CART_UID = 'api::panier.panier';
const LINE_UID = 'api::ligne-panier.ligne-panier';
const ORDER_UID = 'api::commande.commande';

if (process.env.NODE_ENV === 'production') {
  console.error('❌ Nettoyage refuse en production : ce script ne sert que pour la base locale.');
  process.exit(1);
}

const keptEmails = TEST_CUSTOMERS.map((c) => c.email);

async function deleteAll(strapi, uid, filters) {
  const docs = await strapi.documents(uid).findMany({ filters });
  for (const doc of docs) {
    await strapi.documents(uid).delete({ documentId: doc.documentId });
  }
  return docs.length;
}

runWithStrapi('Nettoyage des comptes de test', async (strapi) => {
  const users = await strapi.documents(USER_UID).findMany({
    filters: { email: { $endsWith: TEST_EMAIL_DOMAIN, $notIn: keptEmails } },
    fields: ['email'],
  });

  const totals = { comptes: 0, paniers: 0, lignes: 0, commandes: 0 };
  for (const user of users) {
    const carts = await strapi.documents(CART_UID).findMany({
      filters: { user: { documentId: user.documentId } },
    });
    for (const cart of carts) {
      totals.lignes += await deleteAll(strapi, LINE_UID, { panier: { documentId: cart.documentId } });
      await strapi.documents(CART_UID).delete({ documentId: cart.documentId });
      totals.paniers++;
    }
    totals.commandes += await deleteAll(strapi, ORDER_UID, { user: { documentId: user.documentId } });
    await strapi.documents(USER_UID).delete({ documentId: user.documentId });
    totals.comptes++;
  }

  console.log(
    `\n🧹 Supprime : ${totals.comptes} compte(s), ${totals.paniers} panier(s), ` +
      `${totals.lignes} ligne(s), ${totals.commandes} commande(s).`,
  );
  console.log(`   Conserves : ${keptEmails.join(', ')} et tout compte hors ${TEST_EMAIL_DOMAIN}.`);
});
