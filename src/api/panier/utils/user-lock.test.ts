import { test } from 'node:test';
import assert from 'node:assert/strict';
import { withUserLock, lockCount } from './user-lock.ts';

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

test('sérialise par clé', async () => {
  const log: string[] = [];
  const job = (n: string) => async () => {
    log.push(`start ${n}`);
    await sleep(10);
    log.push(`end ${n}`);
  };
  await Promise.all([withUserLock('u', job('1')), withUserLock('u', job('2')), withUserLock('u', job('3'))]);
  assert.deepEqual(log, ['start 1', 'end 1', 'start 2', 'end 2', 'start 3', 'end 3']);
});

test('parallèle entre clés', async () => {
  const log: string[] = [];
  const job = (n: string) => async () => {
    log.push(`start ${n}`);
    await sleep(10);
    log.push(`end ${n}`);
  };
  await Promise.all([withUserLock('a', job('a')), withUserLock('b', job('b'))]);
  assert.deepEqual(log.slice(0, 2), ['start a', 'start b']);
});

test('erreur propagée sans casser la chaîne', async () => {
  const p1 = withUserLock('e', async () => {
    await sleep(5);
    throw new Error('boom');
  });
  const p2 = withUserLock('e', async () => 'ok');
  await assert.rejects(p1, /boom/);
  assert.equal(await p2, 'ok');
});

test('nettoyage de la map', async () => {
  await Promise.all([withUserLock('c', async () => 1), withUserLock('c', async () => 2)]);
  await sleep(5);
  assert.equal(lockCount(), 0);
  await assert.rejects(withUserLock('c', async () => { throw new Error('x'); }));
  await sleep(5);
  assert.equal(lockCount(), 0);
});
