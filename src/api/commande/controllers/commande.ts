import { factories } from '@strapi/strapi';
import { findCart } from '../../panier/utils/find-cart';
import { withUserLock } from '../../panier/utils/user-lock';
import { buildOrder, type BuiltOrder } from '../utils/build-order';

const ORDER_UID = 'api::commande.commande';
const LINE_UID = 'api::ligne-panier.ligne-panier';
const SHIPPING_AMOUNT = 4;
const PAYMENT_SIMULATION_DURATION_MS = 10_000;

type OrderEntity = {
  id?: number;
  documentId: string;
  total: number | string;
  status: string;
  lineItems?: unknown;
  createdAt?: string;
  paymentSimulationStartedAt?: string | Date | null;
};

type ShippingAddress = {
  fullName: string;
  line1: string;
  line2?: string;
  postalCode: string;
  city: string;
  country: string;
  phone?: string;
};

function toDto(order: OrderEntity) {
  return {
    documentId: order.documentId,
    status: order.status,
    total: Number(order.total),
    lineItems: order.lineItems,
    createdAt: order.createdAt,
  };
}

function isRequiredAddressField(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= 120;
}

function isOptionalAddressField(value: unknown): value is string | undefined {
  return value === undefined || (typeof value === 'string' && value.length <= 120);
}

function parseShippingAddress(body: unknown): ShippingAddress | null {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return null;
  const address = body as Record<string, unknown>;
  const requiredFields = ['fullName', 'line1', 'postalCode', 'city', 'country'];
  if (
    !requiredFields.every((field) => isRequiredAddressField(address[field])) ||
    !isOptionalAddressField(address.line2) ||
    !isOptionalAddressField(address.phone)
  ) {
    return null;
  }
  return {
    fullName: (address.fullName as string).trim(),
    line1: (address.line1 as string).trim(),
    ...(address.line2 === undefined ? {} : { line2: (address.line2 as string).trim() }),
    postalCode: (address.postalCode as string).trim(),
    city: (address.city as string).trim(),
    country: (address.country as string).trim(),
    ...(address.phone === undefined ? {} : { phone: (address.phone as string).trim() }),
  };
}

export default factories.createCoreController(ORDER_UID, ({ strapi }) => ({
  async checkout(ctx: any) {
    const user = ctx.state.user;
    if (!user?.documentId) return ctx.unauthorized();

    return withUserLock(user.documentId, async () => {
      const cart = await findCart(strapi, user.documentId);
      let order: BuiltOrder;
      try {
        order = buildOrder(
          (cart?.lignes ?? []).map((line) => ({
            productDocumentId: line.produit?.documentId ?? line.documentId,
            title: line.produit?.title ?? '',
            unitPrice: line.produit?.price ?? null,
            quantity: line.qte,
          })),
        );
      } catch (error) {
        if (error instanceof Error && error.message === 'EMPTY_CART') {
          return ctx.badRequest('Le panier est vide.');
        }
        if (error instanceof Error && error.message.startsWith('MISSING_PRICE')) {
          return ctx.badRequest("Un produit du panier n'a pas de prix.");
        }
        throw error;
      }

      const created = (await strapi.db.transaction(async () => {
        const createdOrder = await strapi.documents(ORDER_UID).create({
          data: {
            status: 'pending',
            currency: 'eur',
            subtotal: order.total,
            shippingAmount: SHIPPING_AMOUNT,
            total: order.total + SHIPPING_AMOUNT,
            lineItems: order.lineItems,
            customerEmail: user.email,
            user: user.documentId,
          },
        });
        for (const line of cart!.lignes) {
          await strapi.documents(LINE_UID).delete({ documentId: line.documentId });
        }
        return createdOrder;
      })) as OrderEntity;

      ctx.status = 201;
      return {
        data: {
          ...toDto(created),
          orderId: created.documentId,
        },
      };
    });
  },

  async mine(ctx: any) {
    const user = ctx.state.user;
    if (!user?.documentId) return ctx.unauthorized();
    const orders = (await strapi.documents(ORDER_UID).findMany({
      filters: { user: { documentId: user.documentId } },
      sort: 'createdAt:desc',
    })) as OrderEntity[];
    return { data: orders.map(toDto) };
  },

  async findOneMine(ctx: any) {
    const user = ctx.state.user;
    if (!user?.documentId) return ctx.unauthorized();
    const order = (await strapi.documents(ORDER_UID).findFirst({
      filters: {
        documentId: ctx.params.documentId,
        user: { documentId: user.documentId },
      },
    })) as OrderEntity | null;
    if (!order) return ctx.notFound('Commande introuvable.');
    return { data: toDto(order) };
  },

  async startSimulation(ctx: any) {
    const user = ctx.state.user;
    if (!user?.documentId) return ctx.unauthorized();
    const order = (await strapi.documents(ORDER_UID).findFirst({
      filters: {
        documentId: ctx.params.documentId,
        user: { documentId: user.documentId },
      },
    })) as OrderEntity | null;
    if (!order) return ctx.notFound('Commande introuvable.');
    if (order.status !== 'pending') {
      return ctx.badRequest('Seules les commandes en attente peuvent être simulées.');
    }

    let startedAt = order.paymentSimulationStartedAt;
    if (startedAt == null) {
      startedAt = new Date();
      await strapi.documents(ORDER_UID).update({
        documentId: order.documentId,
        data: { paymentSimulationStartedAt: startedAt },
      });
    }
    const startedAtMs =
      startedAt instanceof Date ? startedAt.getTime() : Date.parse(startedAt);
    if (!Number.isFinite(startedAtMs)) {
      throw new Error('La date de début de simulation de paiement est invalide.');
    }
    return {
      data: {
        readyAt: new Date(startedAtMs + PAYMENT_SIMULATION_DURATION_MS).toISOString(),
      },
    };
  },

  async confirmSimulation(ctx: any) {
    const user = ctx.state.user;
    if (!user?.documentId) return ctx.unauthorized();
    const order = (await strapi.documents(ORDER_UID).findFirst({
      filters: {
        documentId: ctx.params.documentId,
        user: { documentId: user.documentId },
      },
    })) as OrderEntity | null;
    if (!order) return ctx.notFound('Commande introuvable.');
    if (order.status === 'paid') return { data: toDto(order) };
    if (order.status !== 'pending' || !order.paymentSimulationStartedAt) {
      return ctx.badRequest('Commencez la simulation de paiement avant de la confirmer.');
    }

    const startedAtMs =
      order.paymentSimulationStartedAt instanceof Date
        ? order.paymentSimulationStartedAt.getTime()
        : Date.parse(order.paymentSimulationStartedAt);
    if (!Number.isFinite(startedAtMs)) {
      throw new Error('La date de début de simulation de paiement est invalide.');
    }
    if (Date.now() - startedAtMs < PAYMENT_SIMULATION_DURATION_MS) {
      return ctx.badRequest('La simulation de paiement n’est pas encore terminée.');
    }

    const paid = (await strapi.documents(ORDER_UID).update({
      documentId: order.documentId,
      data: { status: 'paid' },
    })) as OrderEntity;
    return { data: toDto(paid) };
  },

  async saveShippingAddress(ctx: any) {
    const user = ctx.state.user;
    if (!user?.documentId) return ctx.unauthorized();
    const address = parseShippingAddress(ctx.request.body);
    if (!address) return ctx.badRequest('Une adresse de livraison valide est requise.');

    const order = (await strapi.documents(ORDER_UID).findFirst({
      filters: {
        documentId: ctx.params.documentId,
        user: { documentId: user.documentId },
      },
    })) as OrderEntity | null;
    if (!order) return ctx.notFound('Commande introuvable.');
    if (order.status !== 'paid') {
      return ctx.badRequest('L’adresse de livraison nécessite une commande payée.');
    }

    await strapi.documents(ORDER_UID).update({
      documentId: order.documentId,
      data: { shippingAddress: address },
    });
    ctx.status = 200;
    ctx.body = { data: { documentId: order.documentId, status: order.status } };
  },
}));
