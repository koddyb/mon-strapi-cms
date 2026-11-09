import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildOrder } from './build-order.ts';

test('calcule sous-totaux et total en centimes', () => {
  const r = buildOrder([
    { productDocumentId: 'a', title: 'A', unitPrice: 19.99, quantity: 3 },
    { productDocumentId: 'b', title: 'B', unitPrice: 5, quantity: 1 },
  ]);
  assert.equal(r.lineItems[0].subtotal, 59.97);
  assert.equal(r.lineItems[1].subtotal, 5);
  assert.equal(r.total, 64.97);
});

test('accepte un prix en chaîne', () => {
  const r = buildOrder([{ productDocumentId: 'a', title: 'A', unitPrice: '10.10', quantity: 2 }]);
  assert.equal(r.lineItems[0].subtotal, 20.2);
  assert.equal(r.lineItems[0].unitPrice, 10.1);
});

test('panier vide refusé', () => {
  assert.throws(() => buildOrder([]), /EMPTY_CART/);
});

test('prix nul refusé', () => {
  assert.throws(
    () => buildOrder([{ productDocumentId: 'abc', title: 'A', unitPrice: null, quantity: 1 }]),
    /MISSING_PRICE:abc/,
  );
});

test('prix zéro refusé', () => {
  assert.throws(
    () => buildOrder([{ productDocumentId: 'abc', title: 'A', unitPrice: 0, quantity: 1 }]),
    /MISSING_PRICE:abc/,
  );
});
