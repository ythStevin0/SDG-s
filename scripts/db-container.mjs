import { execFileSync } from 'node:child_process';

const CONTAINER_NAME = 'simpanjual-postgres';
const IMAGE = 'docker.io/library/postgres:17-alpine';
const VOLUME_NAME = 'simpanjual_pgdata';
const PG_PORT = process.env.PG_HOST_PORT || '5435';
const PG_USER = process.env.POSTGRES_USER || 'simpanjual';
const PG_PASS = process.env.POSTGRES_PASSWORD || 'simpanjual_dev';
const PG_DB = process.env.POSTGRES_DB || 'simpanjual';

function runPodman(args, { ignoreError = false } = {}) {
  try {
    return execFileSync('podman', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  } catch (err) {
    if (ignoreError) return null;
    const msg = err.stderr ? String(err.stderr).trim() : err.message;
    throw new Error(`podman ${args.join(' ')} failed: ${msg}`);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function up() {
  const state = runPodman(['inspect', '-f', '{{.State.Status}}', CONTAINER_NAME], { ignoreError: true });

  if (state === 'running') {
    console.log(`Kontainer ${CONTAINER_NAME} sudah berjalan di port ${PG_PORT}.`);
  } else if (state === 'exited' || state === 'stopped') {
    console.log(`Menjalankan ulang kontainer ${CONTAINER_NAME} (status sebelumnya: ${state})...`);
    runPodman(['start', CONTAINER_NAME]);
  } else {
    if (state) {
      runPodman(['rm', '-f', CONTAINER_NAME], { ignoreError: true });
    }
    console.log(`Membuat kontainer Podman ${CONTAINER_NAME} (${IMAGE}, host port ${PG_PORT})...`);
    runPodman([
      'run',
      '-d',
      '--name',
      CONTAINER_NAME,
      '--network',
      'host',
      '-e',
      `POSTGRES_USER=${PG_USER}`,
      '-e',
      `POSTGRES_PASSWORD=${PG_PASS}`,
      '-e',
      `POSTGRES_DB=${PG_DB}`,
      '-v',
      `${VOLUME_NAME}:/var/lib/postgresql/data`,
      IMAGE,
      'postgres',
      '-c',
      `port=${PG_PORT}`,
    ]);
  }

  for (let attempt = 1; attempt <= 25; attempt++) {
    const ready = runPodman(
      ['exec', CONTAINER_NAME, 'pg_isready', '-h', '127.0.0.1', '-p', PG_PORT, '-U', PG_USER, '-d', PG_DB],
      { ignoreError: true }
    );
    if (ready !== null) {
      console.log(`PostgreSQL siap menerima koneksi di 127.0.0.1:${PG_PORT}/${PG_DB}.`);
      return;
    }
    await sleep(1000);
  }
  throw new Error('Timeout menunggu PostgreSQL siap di kontainer Podman.');
}

function down() {
  const state = runPodman(['inspect', '-f', '{{.State.Status}}', CONTAINER_NAME], { ignoreError: true });
  if (!state) {
    console.log(`Kontainer ${CONTAINER_NAME} belum dibuat.`);
    return;
  }
  if (state === 'running') {
    runPodman(['stop', CONTAINER_NAME]);
    console.log(`Kontainer ${CONTAINER_NAME} dihentikan.`);
  } else {
    console.log(`Kontainer ${CONTAINER_NAME} sudah dalam keadaan ${state}.`);
  }
}

function status() {
  const out = runPodman(
    ['ps', '-a', '--filter', `name=^/${CONTAINER_NAME}$`, '--format', '{{.Names}}\t{{.Status}}\t{{.Networks}}'],
    { ignoreError: true }
  );
  console.log(out || `Kontainer ${CONTAINER_NAME} belum ada.`);
}

const cmd = process.argv[2] || 'status';
if (cmd === 'up') {
  await up();
} else if (cmd === 'down') {
  down();
} else if (cmd === 'status') {
  status();
} else {
  console.error('Gunakan: node scripts/db-container.mjs <up|down|status>');
  process.exit(1);
}
