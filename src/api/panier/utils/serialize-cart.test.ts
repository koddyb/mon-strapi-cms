import { test } from 'node:test';
import assert from 'node:assert/strict';
import { serializeCart } from './serialize-cart.ts';

test('panier absent', () => {
  assert.deepEqual(serializeCart(null), { documentId: null, quantity: 0, total: 0, items: [] });
});

test('deux lignes dont une sans prix', () => {
  const p = (id: string, price: number | string | null) => ({
    documentId: id, title: id, slug: id, price, image: null, category: null,
  });
  const r = serializeCart({
    documentId: 'c1',
    lignes: [
      { documentId: 'l1', qte: 2, produit: p('p1', '12.50') },
      { documentId: 'l2', qte: 1, produit: p('p2', null) },
    ],
  });
  assert.equal(r.quantity, 3);
  assert.equal(r.total, 25);
  assert.equal(r.items[1].subtotal, 0);
  assert.equal(r.items[0].product?.price, 12.5);
});

test('aucune fuite du produit brut (id numérique, champs média)', () => {
  const raw: any = {
    id: 7, documentId: 'p1', title: 'T', slug: 's', price: 3, secret: 'x',
    image: { id: 9, url: '/u.png', hash: 'h', provider_metadata: {}, formats: {} },
    category: { id: 4, name: 'C', slug: 'c' },
  };
  const r = serializeCart({ documentId: 'c1', lignes: [{ documentId: 'l1', qte: 1, produit: raw }] });
  assert.deepEqual(r.items[0].product, {
    documentId: 'p1', title: 'T', slug: 's', price: 3, image: { url: '/u.png' }, category: { name: 'C' },
  });
});
