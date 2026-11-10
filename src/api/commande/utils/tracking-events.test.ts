import { test } from 'node:test';
import assert from 'node:assert/strict';
import { appendTrackingEvent } from './tracking-events.ts';

test('ajoute un événement sans supprimer l’historique', () => {
  const events = appendTrackingEvent(
    [{ status: 'awaiting_payment', happenedAt: '2025-01-01T10:00:00.000Z' }],
    'payment_confirmed',
    '2025-01-01T10:00:10.000Z',
  );
  assert.deepEqual(events, [
    { status: 'awaiting_payment', happenedAt: '2025-01-01T10:00:00.000Z' },
    { status: 'payment_confirmed', happenedAt: '2025-01-01T10:00:10.000Z' },
  ]);
});

test('refuse un historique de suivi mal formé', () => {
  assert.throws(
    () => appendTrackingEvent([{ status: 'paid' }], 'payment_confirmed', '2025-01-01'),
    /événements de suivi/,
  );
});
