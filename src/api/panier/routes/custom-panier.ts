export default {
  routes: [
    { method: 'GET', path: '/mon-panier', handler: 'panier.mine', config: { auth: {} } },
    { method: 'POST', path: '/mon-panier/lignes', handler: 'panier.addLine', config: { auth: {} } },
    {
      method: 'PUT',
      path: '/mon-panier/lignes/:lineDocumentId',
      handler: 'panier.updateLine',
      config: { auth: {} },
    },
    {
      method: 'DELETE',
      path: '/mon-panier/lignes/:lineDocumentId',
      handler: 'panier.removeLine',
      config: { auth: {} },
    },
  ],
};
