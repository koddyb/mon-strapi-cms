// Verrou par utilisateur, en mémoire : sérialise les opérations panier/commande d'un même client.
// Valable pour UN seul process Node (local / un seul dyno Heroku) ; plusieurs dynos
// nécessiteraient une garantie côté base de données.
const tails = new Map<string, Promise<unknown>>();

export function withUserLock<T>(userDocumentId: string, fn: () => Promise<T>): Promise<T> {
  const prev = tails.get(userDocumentId) ?? Promise.resolve();
  const run = prev.then(fn, fn);
  const tail = run.catch(() => undefined);
  tails.set(userDocumentId, tail);
  void tail.then(() => {
    if (tails.get(userDocumentId) === tail) tails.delete(userDocumentId);
  });
  return run;
}

export const lockCount = (): number => tails.size;
