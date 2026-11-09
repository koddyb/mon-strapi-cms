export type CartLineEntity = {
  documentId: string;
  qte: number;
  produit: {
    documentId: string;
    title: string;
    slug: string | null;
    price: number | string | null;
    image: { url: string } | null;
    category: { name: string } | null;
  } | null;
};

export type SerializedCart = {
  documentId: string | null;
  quantity: number;
  total: number;
  items: {
    documentId: string;
    quantity: number;
    subtotal: number;
    product: {
      documentId: string;
      title: string;
      slug: string | null;
      price: number | null;
      image: { url: string } | null;
      category: { name: string } | null;
    } | null;
  }[];
};

// Même règle que toCents de build-order.ts (dupliqué : pas d'import entre fichiers purs).
const cents = (v: number | string | null): number | null => {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n * 100) : null;
};

export function serializeCart(
  cart: { documentId: string; lignes: CartLineEntity[] } | null,
): SerializedCart {
  if (!cart) return { documentId: null, quantity: 0, total: 0, items: [] };

  let quantity = 0;
  let totalCents = 0;
  const items = cart.lignes.map((l) => {
    const unit = l.produit ? cents(l.produit.price) : null;
    const subtotalCents = (unit ?? 0) * l.qte;
    quantity += l.qte;
    totalCents += subtotalCents;
    return {
      documentId: l.documentId,
      quantity: l.qte,
      subtotal: subtotalCents / 100,
      product: l.produit
        ? {
            documentId: l.produit.documentId,
            title: l.produit.title,
            slug: l.produit.slug ?? null,
            price: unit === null ? null : unit / 100,
            image: l.produit.image ? { url: l.produit.image.url } : null,
            category: l.produit.category ? { name: l.produit.category.name } : null,
          }
        : null,
    };
  });

  return { documentId: cart.documentId, quantity, total: totalCents / 100, items };
}
