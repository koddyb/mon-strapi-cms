import { factories } from '@strapi/strapi';
import { findCart, getOrCreateCart } from '../utils/find-cart';
import { serializeCart } from '../utils/serialize-cart';

const MAX_QTY = 99;
const isValidQty = (q: unknown): q is number =>
  typeof q === 'number' && Number.isInteger(q) && q >= 1 && q <= MAX_QTY;

export default factories.createCoreController('api::panier.panier', ({ strapi }) => {
  const userId = (ctx: any): string => ctx.state.user.documentId;

  const respond = async (_ctx: unknown, uid: string) => ({
    data: serializeCart(await findCart(strapi, uid)),
  });

  return {
    async mine(ctx: any) {
      return respond(ctx, userId(ctx));
    },

    async addLine(ctx: any) {
      const { productDocumentId, quantity } = ctx.request.body ?? {};
      if (typeof productDocumentId !== 'string' || !productDocumentId || quantity === undefined || quantity === null) {
        return ctx.badRequest('productDocumentId et quantity (1-99) sont requis.');
      }
      if (!isValidQty(quantity)) {
        return ctx.badRequest('quantity doit être un entier entre 1 et 99.');
      }

      const produit = await strapi
        .documents('api::produit.produit')
        .findOne({ documentId: productDocumentId, status: 'published' });
      if (!produit) return ctx.notFound('Produit publié introuvable.');
      if (produit.price === null || produit.price === undefined) {
        return ctx.badRequest("Ce produit n'a pas de prix.");
      }

      const cart = await getOrCreateCart(strapi, userId(ctx));
      const existing = cart.lignes.find((l) => l.produit?.documentId === productDocumentId);
      const total = (existing?.qte ?? 0) + quantity;
      if (total > MAX_QTY) return ctx.badRequest('99 unités maximum par produit.');

      if (existing) {
        await strapi
          .documents('api::ligne-panier.ligne-panier')
          .update({ documentId: existing.documentId, data: { qte: total } });
      } else {
        await strapi.documents('api::ligne-panier.ligne-panier').create({
          data: {
            qte: total,
            panier: cart.documentId,
            produit: productDocumentId,
          },
        });
      }
      return respond(ctx, userId(ctx));
    },

    async updateLine(ctx: any) {
      const { quantity } = ctx.request.body ?? {};
      if (!isValidQty(quantity)) {
        return ctx.badRequest('quantity doit être un entier entre 1 et 99.');
      }
      const cart = await findCart(strapi, userId(ctx));
      const line = cart?.lignes.find((l) => l.documentId === ctx.params.lineDocumentId);
      if (!line) return ctx.notFound('Ligne de panier introuvable.');

      await strapi
        .documents('api::ligne-panier.ligne-panier')
        .update({ documentId: line.documentId, data: { qte: quantity } });
      return respond(ctx, userId(ctx));
    },

    async removeLine(ctx: any) {
      const cart = await findCart(strapi, userId(ctx));
      const line = cart?.lignes.find((l) => l.documentId === ctx.params.lineDocumentId);
      if (!line) return ctx.notFound('Ligne de panier introuvable.');

      await strapi.documents('api::ligne-panier.ligne-panier').delete({ documentId: line.documentId });
      return respond(ctx, userId(ctx));
    },
  };
});
