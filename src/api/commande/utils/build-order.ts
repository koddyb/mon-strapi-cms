export type OrderInputLine = {
  productDocumentId: string;
  title: string;
  unitPrice: number | string | null;
  quantity: number;
};

export type OrderLineItem = {
  productDocumentId: string;
  title: string;
  unitPrice: number;
  quantity: number;
  subtotal: number;
};

export type BuiltOrder = { lineItems: OrderLineItem[]; total: number };

export function toCents(value: number | string | null): number | null {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? Math.round(n * 100) : null;
}

export function buildOrder(lines: OrderInputLine[]): BuiltOrder {
  if (lines.length === 0) throw new Error('EMPTY_CART');

  let totalCents = 0;
  const lineItems = lines.map((line) => {
    const cents = toCents(line.unitPrice);
    if (cents === null || cents <= 0) {
      throw new Error(`MISSING_PRICE:${line.productDocumentId}`);
    }
    const subtotalCents = cents * line.quantity;
    totalCents += subtotalCents;
    return {
      productDocumentId: line.productDocumentId,
      title: line.title,
      unitPrice: cents / 100,
      quantity: line.quantity,
      subtotal: subtotalCents / 100,
    };
  });

  return { lineItems, total: totalCents / 100 };
}
