const cache = new Map<string, { count: number; expires: number }>();

export function rateLimit(ip: string, limit: number, windowMs: number) {
  const now = Date.now();
  const record = cache.get(ip);

  if (!record || now > record.expires) {
    cache.set(ip, { count: 1, expires: now + windowMs });
    return true;
  }

  if (record.count >= limit) {
    return false;
  }

  record.count++;
  return true;
}
