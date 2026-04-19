#!/usr/bin/env node

import { spawn } from 'node:child_process';
import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import process from 'node:process';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: path.join(projectRoot, '.env') });

const args = new Set(process.argv.slice(2));
const runSeed = args.has('--fresh') || args.has('--seed');

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

async function main() {
  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is required before running bootstrap-db.');
    process.exit(1);
  }

  console.log('Running database migrations...');
  await runCommand('npm', ['run', 'migrate:up'], 'migrations');

  if (runSeed) {
    console.log('Running seed data load for fresh database...');
    await runCommand('npm', ['run', 'seed'], 'seed');
  } else {
    console.log('Seed skipped. Pass --fresh or --seed to load demo data.');
  }

  console.log('Database bootstrap complete.');
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
