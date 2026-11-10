export type TrackingEvent = {
  status: string;
  happenedAt: string;
};

export function appendTrackingEvent(
  existing: unknown,
  status: string,
  happenedAt: string,
): TrackingEvent[] {
  if (existing != null && !Array.isArray(existing)) {
    throw new Error('Les événements de suivi de commande sont invalides.');
  }
  const events = (existing ?? []) as unknown[];
  if (
    !events.every(
      (event) =>
        typeof event === 'object' &&
        event !== null &&
        !Array.isArray(event) &&
        typeof (event as Record<string, unknown>).status === 'string' &&
        typeof (event as Record<string, unknown>).happenedAt === 'string',
    )
  ) {
    throw new Error('Les événements de suivi de commande sont invalides.');
  }
  return [...(events as TrackingEvent[]), { status, happenedAt }];
}
