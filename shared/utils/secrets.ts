import fs from 'node:fs';
import path from 'node:path';

const DEFAULT_SECRET_MOUNT_PATH = '/mnt/secrets-store';

/**
 * Get a secret value from environment variables or mounted secret file
 * Checks environment variables first, then falls back to mounted secret files
 * (e.g., AWS Secrets Manager CSI driver, Kubernetes secrets)
 *
 * @param key Secret key/name to look up
 * @param fallback Optional fallback value if secret not found
 * @returns Secret value or undefined if not found (and no fallback provided)
 * @example
 * ```ts
 * const jwtSecret = getSecretValue('JWT_SECRET');
 * const dbUrl = getSecretValue('DATABASE_URL', 'default-url');
 * ```
 */
export function getSecretValue(key: string, fallback?: string): string | undefined {
  const envValue = process.env[key];
  if (envValue && envValue.length > 0) {
    return envValue;
  }

  const secretMountPath = process.env.SECRET_MOUNT_PATH || DEFAULT_SECRET_MOUNT_PATH;
  const secretFilePath = path.join(secretMountPath, key);

  if (fs.existsSync(secretFilePath)) {
    return fs.readFileSync(secretFilePath, 'utf8').trim();
  }

  return fallback;
}