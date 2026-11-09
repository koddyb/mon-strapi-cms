// Cree les comptes clients de test (scripts/lib/test-customers.js), confirmes,
// avec le role Authenticated. Idempotent : un compte existant n'est pas modifie.
//
// Le mot de passe commun n'est jamais versionne : il vient de SEED_CUSTOMER_PASSWORD.
//   SEED_CUSTOMER_PASSWORD='...' npm run seed:customers
//   heroku run -e SEED_CUSTOMER_PASSWORD='...' npm run seed:customers --app mon-strapi-cms
const { runWithStrapi } = require('./lib/strapi-script');
const { TEST_CUSTOMERS } = require('./lib/test-customers');

const USER_UID = 'plugin::users-permissions.user';
const ROLE_UID = 'plugin::users-permissions.role';
const MIN_PASSWORD_LENGTH = 8;

const password = process.env.SEED_CUSTOMER_PASSWORD;
if (!password || password.length < MIN_PASSWORD_LENGTH) {
  console.error(
    `❌ SEED_CUSTOMER_PASSWORD doit etre defini (${MIN_PASSWORD_LENGTH} caracteres minimum).\n` +
      "   Exemple : SEED_CUSTOMER_PASSWORD='un-mot-de-passe-de-test' npm run seed:customers",
  );
  process.exit(1);
}

runWithStrapi('Seed des clients de test', async (strapi) => {
  const role = await strapi.documents(ROLE_UID).findFirst({ filters: { type: 'authenticated' } });
  if (!role) throw new Error('role "authenticated" introuvable');

  let created = 0;
  for (const customer of TEST_CUSTOMERS) {
    const existing = await strapi.documents(USER_UID).findFirst({
      filters: { $or: [{ email: customer.email }, { username: customer.username }] },
    });
    if (existing) {
      console.log(`   ℹ️ Deja present : ${customer.email}`);
      continue;
    }
    // Le Document Service hache lui-meme les attributs de type password.
    await strapi.documents(USER_UID).create({
      data: {
        username: customer.username,
        email: customer.email,
        password,
        provider: 'local',
        confirmed: true,
        blocked: false,
        role: role.documentId,
      },
    });
    console.log(`   ✨ Cree : ${customer.email}`);
    created++;
  }
  console.log(`\n🎉 Termine : ${created} compte(s) cree(s), ${TEST_CUSTOMERS.length - created} deja present(s).`);
});
