#!/usr/bin/env node

import { spawn } from 'node:child_process';
import dotenv from 'dotenv';
import { Pool } from 'pg';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import process from 'node:process';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: path.join(projectRoot, '.env') });

const args = new Set(process.argv.slice(2));
const runSeed = args.has('--fresh') || args.has('--seed');
const legacyMigrationsDir = path.join(projectRoot, 'db', 'migrations');

const LEGACY_MIGRATIONS_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS legacy_sql_migrations (
    filename TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
`;

const LEGACY_ALREADY_EXISTS_ERROR_CODES = new Set([
  '42701', // duplicate_column
  '42P07', // duplicate_table/relation already exists
  '42710', // duplicate_object
  '23505', // unique_violation
]);

function runCommand(command, commandArgs, label) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, commandArgs, {
      stdio: 'inherit',
      shell: process.platform === 'win32',
      env: process.env,
    });

    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${label} failed with exit code ${code}`));
    });
  });
}

function isAlreadyExistsError(error) {
  return Boolean(error?.code && LEGACY_ALREADY_EXISTS_ERROR_CODES.has(error.code));
}

async function runLegacySqlMigrations() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });

  try {
    const entries = await fs.readdir(legacyMigrationsDir, { withFileTypes: true });
    const migrationFiles = entries
      .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
      .map((entry) => entry.name)
      .sort((a, b) => a.localeCompare(b));

    if (migrationFiles.length === 0) {
      console.log('No legacy SQL migrations found in db/migrations.');
      return;
    }

    await pool.query(LEGACY_MIGRATIONS_TABLE_SQL);
    const appliedResult = await pool.query('SELECT filename FROM legacy_sql_migrations');
    const applied = new Set(appliedResult.rows.map((row) => row.filename));

    for (const fileName of migrationFiles) {
      if (applied.has(fileName)) {
        console.log(`↷ Skipping legacy migration (already applied): ${fileName}`);
        continue;
      }

      const sqlPath = path.join(legacyMigrationsDir, fileName);
      const sql = await fs.readFile(sqlPath, 'utf8');

      if (!sql.trim()) {
        console.log(`↷ Skipping empty legacy migration: ${fileName}`);
        await pool.query('INSERT INTO legacy_sql_migrations (filename) VALUES ($1) ON CONFLICT (filename) DO NOTHING', [fileName]);
        continue;
      }

      console.log(`→ Applying legacy migration: ${fileName}`);

      try {
        await pool.query('BEGIN');
        await pool.query(sql);
        await pool.query('INSERT INTO legacy_sql_migrations (filename) VALUES ($1)', [fileName]);
        await pool.query('COMMIT');
        console.log(`✓ Applied legacy migration: ${fileName}`);
      } catch (error) {
        await pool.query('ROLLBACK');

        if (isAlreadyExistsError(error)) {
          console.warn(
            `⚠ Legacy migration ${fileName} hit an already-exists condition (${error.code}). Marking as applied and continuing.`
          );
          await pool.query(
            'INSERT INTO legacy_sql_migrations (filename) VALUES ($1) ON CONFLICT (filename) DO NOTHING',
            [fileName]
          );
          continue;
        }

        throw new Error(`Legacy migration ${fileName} failed: ${error.message || error}`);
      }
    }
  } finally {
    await pool.end();
  }
}

async function main() {
  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is required before running bootstrap-db.');
    process.exit(1);
  }

  console.log('Running shared node-pg-migrate migrations...');
  await runCommand('npm', ['run', 'migrate:up'], 'migrations');

  if (runSeed) {
    console.log('Running seed data load for fresh database...');
    await runCommand('npm', ['run', 'seed'], 'seed');
    console.log('Applying legacy SQL migrations from db/migrations (post-seed)...');
    await runLegacySqlMigrations();
  } else {
    console.log('Applying legacy SQL migrations from db/migrations...');
    await runLegacySqlMigrations();
    console.log('Seed skipped. Pass --fresh or --seed to load demo data.');
  }

  console.log('Database bootstrap complete.');
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
