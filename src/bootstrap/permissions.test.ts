import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Core } from '@strapi/strapi';
import { ensurePermissions, WANTED_PERMISSIONS } from './permissions.ts';

const roleUid = 'plugin::users-permissions.role';
const permissionUid = 'plugin::users-permissions.permission';

test('synchronise les permissions boutique et retire le CRUD commande non autorisé', async () => {
  const roles: Record<
    string,
    { documentId: string; permissions: { documentId: string; action: string }[] }
  > = {
    public: {
      documentId: 'public-role',
      permissions: [
        { documentId: 'public-command-create', action: 'api::commande.commande.create' },
      ],
    },
    authenticated: {
      documentId: 'authenticated-role',
      permissions: [
        { documentId: 'authenticated-cart-find', action: 'api::panier.panier.find' },
        { documentId: 'authenticated-command-mine', action: 'api::commande.commande.mine' },
      ],
    },
  };
  const deleted: string[] = [];
  const created: { role: string; action: string }[] = [];

  const strapi = {
    documents(uid: string) {
      if (uid === roleUid) {
        return {
          findMany: async ({ filters }: { filters: { type: string } }) => [
            { ...roles[filters.type] },
          ],
        };
      }
      assert.equal(uid, permissionUid);
      return {
        create: async ({ data }: { data: { action: string; role: string } }) => {
          const targetRole = Object.values(roles).find(
            (role) => role.documentId === data.role,
          );
          assert.ok(targetRole);
          const permission = {
            documentId: `permission-${created.length}`,
            action: data.action,
          };
          targetRole.permissions.push(permission);
          created.push({ role: data.role, action: data.action });
        },
        delete: async ({ documentId }: { documentId: string }) => {
          deleted.push(documentId);
          for (const role of Object.values(roles)) {
            role.permissions = role.permissions.filter(
              (permission) => permission.documentId !== documentId,
            );
          }
        },
      };
    },
    log: { info() {}, warn() {} },
  } as unknown as Core.Strapi;

  await ensurePermissions(strapi);

  assert.deepEqual(deleted, ['public-command-create', 'authenticated-cart-find']);
  assert.ok(
    created.some(
      ({ role, action }) =>
        role === 'authenticated-role' &&
        action === 'api::commande.commande.startSimulation',
    ),
  );
  assert.ok(
    created.some(
      ({ role, action }) =>
        role === 'authenticated-role' &&
        action === 'api::commande.commande.saveShippingAddress',
    ),
  );
  assert.ok(
    roles.authenticated.permissions.some(
      ({ action }) => action === 'api::commande.commande.mine',
    ),
  );
  assert.ok(WANTED_PERMISSIONS.public.includes('plugin::users-permissions.auth.register'));

  const createdCount = created.length;
  await ensurePermissions(strapi);
  assert.equal(created.length, createdCount);
  assert.equal(deleted.length, 2);
});
