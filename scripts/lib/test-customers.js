// Comptes clients fictifs utilises pour tester le front.
// Domaine @example.test : reserve (RFC 2606), aucun e-mail reel ne peut y arriver.
const TEST_CUSTOMERS = [
  { username: 'alice.martin', email: 'alice.martin@example.test' },
  { username: 'bruno.leroy', email: 'bruno.leroy@example.test' },
  { username: 'chloe.dubois', email: 'chloe.dubois@example.test' },
];

const TEST_EMAIL_DOMAIN = '@example.test';

module.exports = { TEST_CUSTOMERS, TEST_EMAIL_DOMAIN };
