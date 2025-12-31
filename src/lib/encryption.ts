import crypto from 'crypto';
import logger from './logger.js';

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY; // 必须是 32 字节 (256 bits)

export function encrypt(text: string): string {
  if (!ENCRYPTION_KEY) {
    logger.error('ENCRYPTION_KEY is missing, returning plain text (UNSAFE!)');
    return text;
  }

  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-gcm', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
  
  const encrypted = Buffer.concat([cipher.update(text, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();

  return Buffer.concat([iv, tag, encrypted]).toString('base64');
}

export function decrypt(data: string): string {
  if (!ENCRYPTION_KEY) return data;

  try {
    const buffer = Buffer.from(data, 'base64');
    const iv = buffer.subarray(0, 16);
    const tag = buffer.subarray(16, 32);
    const text = buffer.subarray(32);

    const decipher = crypto.createDecipheriv('aes-256-gcm', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
    decipher.setAuthTag(tag);

    return decipher.update(text) + decipher.final('utf8');
  } catch (error) {
    logger.error('Decryption failed');
    throw new Error('Failed to decrypt data');
  }
}
