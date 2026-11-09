import { factories } from '@strapi/strapi';
import { findCart } from '../../panier/utils/find-cart';
import { withUserLock } from '../../panier/utils/user-lock';
import { buildOrder } from '../utils/build-order';

const toDto = (c: any) => ({
  documentId: c.documentId,
  total: Number(c.total),
  lineItems: c.lineItems,
  createdAt: c.createdAt,
});

export default factories.createCoreController('api::commande.commande', ({ strapi }) => ({
  // Le corps de la requête est ignoré : les prix viennent de la base.
  async checkout(ctx: any) {
    const userDocumentId: string = ctx.state.user.documentId;
    return withUserLock(userDocumentId, async () => {
      const cart = await findCart(strapi, userDocumentId);

      let order;
      try {
        order = buildOrder(
          (cart?.lignes ?? []).map((l) => ({
            productDocumentId: l.produit?.documentId ?? l.documentId,
            title: l.produit?.title ?? '',
            unitPrice: l.produit ? ((l.produit as any).price ?? null) : null,
            quantity: l.qte,
          })),
        );
      } catch (e: any) {
        if (e?.message === 'EMPTY_CART') return ctx.badRequest('Le panier est vide.');
        if (typeof e?.message === 'string' && e.message.startsWith('MISSING_PRICE')) {
          return ctx.badRequest("Un produit du panier n'a pas de prix.");
        }
        throw e;
      }

      const created: any = await strapi.documents('api::commande.commande').create({
        data: { total: order.total, lineItems: order.lineItems as any, user: userDocumentId },
      });

      for (const l of cart!.lignes) {
        await strapi.documents('api::ligne-panier.ligne-panier').delete({ documentId: l.documentId });
      }

      ctx.status = 201;
      return { data: toDto(created) };
    });
  },

  async mine(ctx: any) {
    const commandes: any[] = await strapi.documents('api::commande.commande').findMany({
      filters: { user: { documentId: ctx.state.user.documentId } },
      sort: 'createdAt:desc',
    });
    return { data: commandes.map(toDto) };
  },
}));
