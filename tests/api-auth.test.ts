import { describe, it, expect, vi, beforeEach } from 'vitest';
import handler from '../api/auth/[...route]';
import { AuthService } from '../src/lib/auth-service';
import { TwoFactorService } from '../src/lib/two-factor-service';
import { db } from '../src/lib/db';
import { verifyToken } from '../src/lib/auth-middleware';
import { ZodError } from 'zod';

vi.mock('../src/lib/auth-service');
vi.mock('../src/lib/two-factor-service');
vi.mock('../src/lib/db', () => ({
  db: {
    select: vi.fn().mockReturnThis(),
    from: vi.fn().mockReturnThis(),
    where: vi.fn().mockReturnThis(),
  }
}));
vi.mock('../src/lib/auth-middleware');
vi.mock('../src/lib/rate-limit', () => ({
  rateLimit: vi.fn().mockResolvedValue(true)
}));

describe('Auth Unified Handler', () => {
  let req: any;
  let res: any;

  beforeEach(() => {
    vi.clearAllMocks();
    res = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };
  });

  it('should return 404 for unknown route', async () => {
    req = { query: { route: ['unknown'] }, method: 'POST' };
    await handler(req, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('should handle login', async () => {
    req = { 
      query: { route: ['login'] }, 
      method: 'POST', 
      body: { email: 'test@example.com', password: 'password' },
      headers: {}
    };
    const mockResult = { token: 'jwt', user: { id: 1 } };
    (AuthService.login as any).mockResolvedValue(mockResult);

    await handler(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(mockResult);
  });

  it('should handle register', async () => {
    req = { 
      query: { route: ['register'] }, 
      method: 'POST', 
      body: { email: 'test@example.com', password: 'password' },
      headers: {}
    };
    const mockUser = { id: 1, email: 'test@example.com' };
    (AuthService.register as any).mockResolvedValue(mockUser);

    await handler(req, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith({ message: 'User created successfully', user: mockUser });
  });

  it('should handle /me', async () => {
    req = { query: { route: ['me'] }, method: 'GET', headers: {} };
    (verifyToken as any).mockReturnValue({ userId: 1 });
    (db.select().from().where as any).mockResolvedValue([{ id: 1, email: 't@e.com', twoFactorEnabled: false }]);

    await handler(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('should handle 2fa/setup', async () => {
    req = { query: { route: ['2fa', 'setup'] }, method: 'POST', headers: {} };
    (verifyToken as any).mockReturnValue({ userId: 1, email: 't@e.com' });
    (TwoFactorService.setup as any).mockResolvedValue({ secret: 'secret' });

    await handler(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('should handle 2fa/enable', async () => {
    req = { 
      query: { route: ['2fa', 'enable'] }, 
      method: 'POST', 
      body: { token: '123456' },
      headers: {} 
    };
    (verifyToken as any).mockReturnValue({ userId: 1 });
    (TwoFactorService.enable as any).mockResolvedValue(undefined);

    await handler(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ message: '2FA enabled successfully' });
  });

  it('should handle 2fa/verify-login', async () => {
    req = { 
      query: { route: ['2fa', 'verify-login'] }, 
      method: 'POST', 
      body: { userId: 1, token: '123456' },
      headers: {} 
    };
    const mockResult = { token: 'jwt', user: { id: 1 } };
    (AuthService.verify2FAAndLogin as any).mockResolvedValue(mockResult);

    await handler(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(mockResult);
  });

  it('should handle ZodError', async () => {
    req = { query: { route: ['login'] }, method: 'POST', body: {}, headers: {} };
    const zodError = new ZodError([{ message: 'Invalid email', path: ['email'], code: 'custom' }]);
    (AuthService.login as any).mockRejectedValue(zodError);

    await handler(req, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: 'Invalid email' });
  });
});
