import type { VercelRequest, VercelResponse } from '@vercel/node';
import { db } from '../../src/lib/db.js';
import { users } from '../../src/db/schema.js';
import { eq } from 'drizzle-orm';
import { verifyToken } from '../../src/lib/auth-middleware.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const authUser = verifyToken(req);
  if (!authUser) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const [user] = await db.select({
      id: users.id,
      email: users.email,
      twoFactorEnabled: users.twoFactorEnabled,
    })
    .from(users)
    .where(eq(users.id, authUser.userId));

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.status(200).json(user);
  } catch (error: any) {
    return res.status(500).json({ error: 'Internal server error' });
  }
}
