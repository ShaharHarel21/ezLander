const windowMap = new Map<string, { count: number; resetAt: number }>();

// Periodic cleanup of expired entries
setInterval(() => {
  const now = Date.now();
  windowMap.forEach((entry, key) => {
    if (now > entry.resetAt) {
      windowMap.delete(key);
    }
  });
}, 60_000);

export async function rateLimit(
  identifier: string,
  limit: number,
  windowMs: number
): Promise<{ success: boolean; remaining: number }> {
  const now = Date.now();
  const key = `${identifier}`;

  const existing = windowMap.get(key);

  if (!existing || now > existing.resetAt) {
    windowMap.set(key, { count: 1, resetAt: now + windowMs });
    return { success: true, remaining: limit - 1 };
  }

  if (existing.count >= limit) {
    return { success: false, remaining: 0 };
  }

  existing.count += 1;
  return { success: true, remaining: limit - existing.count };
}
