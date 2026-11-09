import type { Core } from '@strapi/strapi';

const ROLE_UID = 'plugin::users-permissions.role';
const PERMISSION_UID = 'plugin::users-permissions.permission';

const CATALOGUE = [
  'api::produit.produit.find',
  'api::produit.produit.findOne',
  'api::category.category.find',
  'api::category.category.findOne',
];

export const WANTED_PERMISSIONS: Record<'public' | 'authenticated', string[]> = {
  public: [
    ...CATALOGUE,
    'plugin::users-permissions.auth.register',
    'plugin::users-permissions.auth.callback',
    'plugin::users-permissions.auth.refresh',
  ],
  authenticated: [
    ...CATALOGUE,
    'plugin::users-permissions.auth.logout',
    'plugin::users-permissions.user.me',
    'api::panier.panier.mine',
    'api::panier.panier.addLine',
    'api::panier.panier.updateLine',
    'api::panier.panier.removeLine',
    'api::commande.commande.checkout',
    'api::commande.commande.mine',
  ],
};

/**
 * Ajoute les permissions manquantes aux rôles Public et Authenticated.
 * N'en retire aucune : idempotent, relançable à chaque démarrage.
 */
export async function ensurePermissions(strapi: Core.Strapi): Promise<void> {
  const added: string[] = [];

  for (const [type, actions] of Object.entries(WANTED_PERMISSIONS)) {
    const [role] = await strapi.documents(ROLE_UID).findMany({
      filters: { type },
      populate: { permissions: true },
      limit: 1,
    });
    if (!role) {
      strapi.log.warn(`[permissions] rôle "${type}" introuvable, permissions ignorées.`);
      continue;
    }
    const existing = new Set(
      ((role as any).permissions ?? []).map((p: { action: string }) => p.action),
    );
    for (const action of actions) {
      if (existing.has(action)) continue;
      await strapi.documents(PERMISSION_UID).create({
        data: { action, role: role.documentId } as any,
      });
      added.push(`${type}:${action}`);
    }
  }

  if (added.length > 0) {
    strapi.log.info(`[permissions] ${added.length} permission(s) ajoutée(s) au démarrage.`);
  }
}
