export default {
  routes: [
    {
      method: 'POST',
      path: '/mon-panier/commander',
      handler: 'api::commande.commande.checkout',
      config: { auth: {} },
    },
    {
      method: 'POST',
      path: '/checkout/commandes',
      handler: 'api::commande.commande.checkout',
      config: { auth: {} },
    },
    {
      method: 'GET',
      path: '/mes-commandes',
      handler: 'api::commande.commande.mine',
      config: { auth: {} },
    },
    {
      method: 'GET',
      path: '/commandes/miennes',
      handler: 'api::commande.commande.mine',
      config: { auth: {} },
    },
    {
      method: 'GET',
      path: '/mes-commandes/:documentId',
      handler: 'api::commande.commande.findOneMine',
      config: { auth: {} },
    },
    {
      method: 'POST',
      path: '/commandes/:documentId/simulation',
      handler: 'api::commande.commande.startSimulation',
      config: { auth: {} },
    },
    {
      method: 'POST',
      path: '/commandes/:documentId/confirmer-paiement',
      handler: 'api::commande.commande.confirmSimulation',
      config: { auth: {} },
    },
    {
      method: 'PUT',
      path: '/commandes/:documentId/adresse-livraison',
      handler: 'api::commande.commande.saveShippingAddress',
      config: { auth: {} },
    },
  ],
};
