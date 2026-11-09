import type { Core } from '@strapi/strapi';
import type { CartLineEntity } from './serialize-cart';

export type CartEntity = { documentId: string; lignes: CartLineEntity[] };

// Panier du client (Document Service uniquement), ou null s'il n'en a pas encore.
// Le produit de chaque ligne est relu en version PUBLIÉE (le populate renverrait le brouillon) ;
// un produit dépublié donne `produit: null`.
export async function findCart(
  strapi: Core.Strapi,
  userDocumentId: string,
): Promise<CartEntity | null> {
  const cart: any = await strapi.documents('api::panier.panier').findFirst({
    filters: { user: { documentId: userDocumentId } },
    sort: ['createdAt:asc', 'id:asc'],
    populate: { lignes: { populate: { produit: true } } },
  });
  if (!cart) return null;

  const lignes: CartLineEntity[] = await Promise.all(
    (cart.lignes ?? []).map(async (l: any) => {
      const produit = l.produit
        ? await strapi.documents('api::produit.produit').findOne({
            documentId: l.produit.documentId,
            status: 'published',
            populate: ['image', 'category'],
          })
        : null;
      return { documentId: l.documentId, qte: l.qte, produit: (produit as any) ?? null };
    }),
  );
  return { documentId: cart.documentId, lignes };
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
