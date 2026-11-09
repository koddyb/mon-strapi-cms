import type { Core } from '@strapi/strapi';
import type { CartLineEntity } from './serialize-cart';

export type CartEntity = { documentId: string; lignes: CartLineEntity[] };

const CART_POPULATE: any = {
  lignes: { populate: { produit: { populate: ['image', 'category'] } } },
};

// Panier du client (Document Service uniquement), ou null s'il n'en a pas encore.
export async function findCart(
  strapi: Core.Strapi,
  userDocumentId: string,
): Promise<CartEntity | null> {
  const cart = await strapi.documents('api::panier.panier').findFirst({
    filters: { user: { documentId: userDocumentId } },
    populate: CART_POPULATE,
  });
  return (cart as unknown as CartEntity | null) ?? null;
}

export async function getOrCreateCart(
  strapi: Core.Strapi,
  userDocumentId: string,
): Promise<CartEntity> {
  const existing = await findCart(strapi, userDocumentId);
  if (existing) return existing;
  const created = await strapi.documents('api::panier.panier').create({
    data: { user: userDocumentId },
  });
  return { documentId: created.documentId, lignes: [] };
}
