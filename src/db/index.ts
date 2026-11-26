import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';

const connectionString =
  process.env.DATABASE_URL || 'postgresql://simpanjual:simpanjual_dev@127.0.0.1:5435/simpanjual';

const globalForDb = globalThis as unknown as {
  pgClient: ReturnType<typeof postgres> | undefined;
};

export const pgClient =
  globalForDb.pgClient ??
  postgres(connectionString, {
    max: 10,
    idle_timeout: 20,
    connect_timeout: 10,
  });

if (process.env.NODE_ENV !== 'production') {
  globalForDb.pgClient = pgClient;
}

export const db = drizzle(pgClient, { schema });
