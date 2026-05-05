import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const servicesDir = path.join(repoRoot, 'services');
const testsDir = path.join(repoRoot, 'tests', 'unit');

function readDirSafe(dirPath) {
  try {
    return fs.readdirSync(dirPath, { withFileTypes: true });
  } catch {
    return [];
  }
}

const keyServices = [
  'api-gateway',
  'auth-service',
  'user-service',
  'trip-service',
  'booking-service',
  'payment-service',
  'notification-service',
  'cost-calculation-service',
];

const availableServices = new Set(
  readDirSafe(servicesDir)
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
);

const serviceNames = keyServices.filter((name) => availableServices.has(name));

const testFiles = readDirSafe(testsDir)
  .filter((entry) => entry.isFile() && entry.name.endsWith('.test.ts'))
  .map((entry) => path.join(testsDir, entry.name));

const missingCoverage = [];

for (const serviceName of serviceNames) {
  const importNeedle = `services/${serviceName}/src/`;
  const covered = testFiles.some((filePath) => {
    const text = fs.readFileSync(filePath, 'utf8');
    return text.includes(importNeedle);
  });

  if (!covered) {
    missingCoverage.push(serviceName);
  }
}

if (missingCoverage.length > 0) {
  console.error('Service test coverage check failed. Missing unit test references for:');
  for (const serviceName of missingCoverage) {
    console.error(`- ${serviceName}`);
  }
  process.exit(1);
}

console.log('Service test coverage check passed for all services.');
