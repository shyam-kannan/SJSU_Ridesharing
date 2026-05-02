import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const originalEnv = { ...process.env };
let tmpDir = '';

beforeEach(() => {
  vi.resetModules();
  process.env = { ...originalEnv };
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lessgo-secrets-test-'));
});

afterEach(() => {
  process.env = { ...originalEnv };
  // Clean up temp directory
  try {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  } catch {
    // ignore cleanup errors
  }
});

async function importGetSecretValue() {
  const module = await import('../../shared/utils/secrets');
  return module.getSecretValue;
}

describe('shared/utils/secrets > getSecretValue', () => {
  it('returns the environment variable when it is set', async () => {
    process.env.MY_SECRET = 'env-value';
    const getSecretValue = await importGetSecretValue();

    expect(getSecretValue('MY_SECRET')).toBe('env-value');
  });

  it('reads the secret from the mounted file when the env var is absent', async () => {
    delete process.env.MY_FILE_SECRET;
    const secretFile = path.join(tmpDir, 'MY_FILE_SECRET');
    fs.writeFileSync(secretFile, '  file-value  ');

    process.env.SECRET_MOUNT_PATH = tmpDir;
    const getSecretValue = await importGetSecretValue();

    expect(getSecretValue('MY_FILE_SECRET')).toBe('file-value');
  });

  it('returns the fallback when neither env var nor file is present', async () => {
    delete process.env.MISSING_SECRET;
    process.env.SECRET_MOUNT_PATH = tmpDir;
    const getSecretValue = await importGetSecretValue();

    expect(getSecretValue('MISSING_SECRET', 'fallback-value')).toBe('fallback-value');
  });

  it('returns undefined when nothing is available and no fallback is given', async () => {
    delete process.env.TOTALLY_ABSENT;
    process.env.SECRET_MOUNT_PATH = tmpDir;
    const getSecretValue = await importGetSecretValue();

    expect(getSecretValue('TOTALLY_ABSENT')).toBeUndefined();
  });

  it('prefers the env var over a mounted file when both exist', async () => {
    process.env.OVERLAPPING = 'env-wins';
    const secretFile = path.join(tmpDir, 'OVERLAPPING');
    fs.writeFileSync(secretFile, 'file-should-lose');

    process.env.SECRET_MOUNT_PATH = tmpDir;
    const getSecretValue = await importGetSecretValue();

    expect(getSecretValue('OVERLAPPING')).toBe('env-wins');
  });

  it('ignores an empty-string env var and falls back to the file', async () => {
    process.env.EMPTY_ENV = '';
    const secretFile = path.join(tmpDir, 'EMPTY_ENV');
    fs.writeFileSync(secretFile, 'file-value');

    process.env.SECRET_MOUNT_PATH = tmpDir;
    const getSecretValue = await importGetSecretValue();

    expect(getSecretValue('EMPTY_ENV')).toBe('file-value');
  });
});
