import http from 'node:http';
import type { AddressInfo } from 'node:net';

export async function startTestServer(app: http.RequestListener): Promise<{
  baseUrl: string;
  close: () => Promise<void>;
}> {
  const server = http.createServer(app);

  await new Promise<void>((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve());
  });

  const address = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${address.port}`;

  return {
    baseUrl,
    close: async () => {
      await new Promise<void>((resolve, reject) => {
        server.close((error) => {
          if (error) {
            reject(error);
            return;
          }
          resolve();
        });
      });
    },
  };
}

export async function requestJson<T = unknown>(args: {
  baseUrl: string;
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  path: string;
  body?: unknown;
  headers?: Record<string, string>;
  query?: Record<string, string | number | boolean | null | undefined>;
}): Promise<{ status: number; body: T }> {
  const url = new URL(args.path, args.baseUrl);

  if (args.query) {
    for (const [key, value] of Object.entries(args.query)) {
      if (value === undefined || value === null) {
        continue;
      }

      url.searchParams.set(key, String(value));
    }
  }

  const bodyText = args.body ? JSON.stringify(args.body) : undefined;

  const response = await fetch(url, {
    method: args.method,
    headers: {
      'content-type': 'application/json',
      ...(args.headers ?? {}),
    },
    body: bodyText,
  });

  const json = (await response.json()) as T;
  return {
    status: response.status,
    body: json,
  };
}
