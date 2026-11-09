export default {
  routes: [
    {
      method: 'POST',
      path: '/mon-panier/commander',
      handler: 'api::commande.commande.checkout',
      config: { auth: {} },
    },
    {
      method: 'GET',
      path: '/mes-commandes',
      handler: 'api::commande.commande.mine',
      config: { auth: {} },
    },
  ],
};
