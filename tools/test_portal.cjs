/* Optional isolated DOM integration test; no browser or user profile is opened.
 * Install: npm.cmd install --prefix tmp/portal-test jsdom@29.1.1 --no-audit --no-fund
 * Run: node tools/test_portal.cjs
 * Override Python with BIBLIOTECA_TEST_PYTHON when .venv is unavailable.
 */
'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
let JSDOM, VirtualConsole;
try {
  ({ JSDOM, VirtualConsole } = require(path.join(root, 'tmp/portal-test/node_modules/jsdom')));
} catch {
  console.error('Install the optional dependency: npm.cmd install --prefix tmp/portal-test jsdom@29.1.1 --no-audit --no-fund');
  process.exit(1);
}

const temporary = path.join(root, 'tmp');
fs.mkdirSync(temporary, { recursive: true });
const runDir = fs.mkdtempSync(path.join(temporary, 'portal-test-'));
const dbPath = path.join(runDir, 'test.sqlite3');
const python = process.env.BIBLIOTECA_TEST_PYTHON || path.join(
  root, '.venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python'
);
const adminName = 'portal_admin';
const adminPassword = crypto.randomUUID() + '!LocalTest';
const environment = { ...process.env, BIBLIOTECA_DB_PATH: dbPath, PORTAL_ADMIN_PASSWORD: adminPassword };
const checks = [];
let server, dom, serverLog = '', failNextHoldRead = false;

function check(condition, message) {
  assert.ok(condition, message);
  checks.push(message);
  console.log('PASS: ' + message);
}

async function waitFor(predicate, description, timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await predicate()) return;
    await new Promise(resolve => setTimeout(resolve, 25));
  }
  throw Error('Timed out: ' + description);
}

async function unusedPort() {
  const listener = net.createServer();
  await new Promise((resolve, reject) => {
    listener.once('error', reject);
    listener.listen(0, '127.0.0.1', resolve);
  });
  const port = listener.address().port;
  await new Promise(resolve => listener.close(resolve));
  return port;
}

async function main() {
  const bootstrap = spawnSync(python, ['-c',
    'import os; from api.database import Database; from api.auth import AuthService; ' +
    'db=Database(os.environ["BIBLIOTECA_DB_PATH"]); db.initialize(); ' +
    'auth=AuthService(db); auth.initialize(); ' +
    'auth.create_user("portal_admin",os.environ["PORTAL_ADMIN_PASSWORD"],role="admin")'
  ], { cwd: root, env: environment, encoding: 'utf8', windowsHide: true });
  assert.equal(bootstrap.status, 0, bootstrap.stderr || bootstrap.stdout);
  const port = await unusedPort();
  const base = 'http://127.0.0.1:' + port;
  server = spawn(python, ['-m', 'uvicorn', 'api.main:app', '--host', '127.0.0.1', '--port', String(port)], {
    cwd: root, env: environment, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']
  });
  server.stdout.on('data', data => { serverLog += data; });
  server.stderr.on('data', data => { serverLog += data; });
  await waitFor(async () => {
    if (server.exitCode !== null) throw Error('Temporary API stopped: ' + serverLog);
    try { return (await fetch(base + '/api/health')).ok; } catch { return false; }
  }, 'temporary API startup');

  const errors = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on('jsdomError', error => errors.push(error.message));
  virtualConsole.on('error', (...items) => errors.push(items.join(' ')));
  const html = await (await fetch(base + '/portal')).text();
  dom = new JSDOM(html, {
    url: base + '/portal',
    runScripts: 'dangerously',
    virtualConsole,
    beforeParse(window) {
      window.fetch = async (input, options = {}) => {
        const url = new URL(input, base);
        if (failNextHoldRead && /^\/api\/reservations\/[^/]+$/.test(url.pathname) &&
            (!options.method || options.method === 'GET')) {
          failNextHoldRead = false;
          return new Response(JSON.stringify({ detail: 'Temporary test failure' }), {
            status: 503, headers: { 'Content-Type': 'application/json' }
          });
        }
        return fetch(url, options);
      };
      Object.defineProperty(window.crypto, 'randomUUID', { value: crypto.randomUUID });
    }
  });
  const window = dom.window;
  const document = window.document;
  const el = id => document.getElementById(id);
  const noticeHas = phrase => el('notice').textContent.includes(phrase);
  const submit = (form, button) => form.dispatchEvent(new window.SubmitEvent('submit', {
    bubbles: true, cancelable: true, submitter: button
  }));
  const storedHolds = () => JSON.parse(window.sessionStorage.getItem('bibliotecaHolds') || '[]');

  check(!el('auth').hidden && el('store').hidden, 'Initial page shows local login');
  el('username').value = adminName;
  el('password').value = adminPassword;
  submit(el('auth-form'), el('auth-form').querySelector('button[type=submit]'));
  await waitFor(() => noticeHas('Bem-vindo'), 'administrator login');
  check(!el('store').hidden && !el('admin-tab').hidden, 'Administrator sees catalog and administration');
  el('admin-tab').click();
  check(!el('admin').hidden, 'Administration tab opens settings');
  el('shop-title').value = 'Livraria do teste DOM';
  el('starting-money').value = '150';
  el('max-customers').value = '4';
  submit(el('settings-form'), el('settings-form').querySelector('button'));
  await waitFor(() => noticeHas('Configurações salvas'), 'settings save');
  const settings = await (await fetch(base + '/api/settings')).json();
  check(settings.shop_title === 'Livraria do teste DOM' && settings.starting_money === 150 &&
    settings.max_customers_per_day === 4, 'Administrator settings persist through real HTTP');
  el('logout').click();
  await waitFor(() => !el('auth').hidden && el('store').hidden, 'administrator logout');

  el('username').value = 'portal_player_' + Date.now();
  el('password').value = crypto.randomUUID() + '!LocalTest';
  el('register').click();
  await waitFor(() => noticeHas('Conta criada'), 'player registration');
  check(el('admin-tab').hidden && el('admin').hidden && !el('catalog').hidden,
    'Administrator logout and player registration reset restricted tabs');
  check(el('balance').textContent === '150 moedas', 'New player receives the configured coin balance');
  const playerToken = window.sessionStorage.getItem('bibliotecaToken');
  const forbidden = await fetch(base + '/api/settings', {
    method: 'PATCH', headers: { Authorization: 'Bearer ' + playerToken, 'Content-Type': 'application/json' },
    body: JSON.stringify({ starting_money: 999 })
  });
  check(forbidden.status === 403, 'Player cannot change administrator settings');

  const card = [...document.querySelectorAll('#books .book')].find(book => !book.querySelector('button').disabled);
  assert.ok(card, 'Catalog needs an available book');
  const title = card.querySelector('h3').textContent;
  const price = Number.parseInt(card.querySelector('.price').textContent, 10);
  card.querySelector('button').click();
  await waitFor(() => noticeHas('Exemplar reservado') && storedHolds().length === 1, 'book reservation');
  const originalHold = storedHolds()[0];
  check(Boolean(originalHold.id && originalHold.idempotency_key) &&
    document.querySelectorAll('#holds .reserve').length === 1, 'Reservation appears with a stable checkout key');
  check(document.querySelector('[data-expires]').textContent.startsWith('Vence em'),
    'Reservation countdown uses the server deadline');
  failNextHoldRead = true;
  await window.refreshHolds();
  check(storedHolds()[0].id === originalHold.id &&
    storedHolds()[0].idempotency_key === originalHold.idempotency_key &&
    noticeHas('preservada'), 'Temporary HTTP 503 preserves reservation and checkout key');

  document.querySelector('#holds .reserve button').click();
  await waitFor(() => noticeHas('Pagamento concluído'), 'coin checkout');
  check(storedHolds().length === 0 && el('balance').textContent === (150 - price) + ' moedas',
    'Checkout consumes the reservation and debits the displayed coin price once');
  document.querySelector('[data-tab=library]').click();
  await waitFor(() => el('owned').textContent.includes(title) &&
    el('payments').textContent.includes('paid'), 'purchased library and payment history');
  check(!el('library').hidden && el('owned').textContent.includes(title),
    'Purchased book appears in the player library');
  check(el('payments').textContent.includes(price + ' moedas'), 'Payment history shows the purchase amount');
  el('logout').click();
  await waitFor(() => !el('auth').hidden && el('store').hidden, 'player logout');
  check(!window.sessionStorage.getItem('bibliotecaToken') && storedHolds().length === 0,
    'Logout clears the local session');
  check(errors.length === 0, 'Portal JavaScript finishes without DOM runtime errors: ' + errors.join('; '));
}

(async () => {
  let failure;
  try {
    await main();
  } catch (error) {
    failure = error;
    console.error(error.stack || error);
  } finally {
    if (dom) dom.window.close();
    if (server) {
      const closed = new Promise(resolve => server.once('close', resolve));
      server.kill();
      await Promise.race([closed, new Promise(resolve => setTimeout(resolve, 5000))]);
    }
    fs.writeFileSync(path.join(runDir, 'server.log'), serverLog);
    fs.writeFileSync(path.join(temporary, 'portal_test_results.json'), JSON.stringify({
      test: 'isolated jsdom DOM with temporary local HTTP API',
      jsdom_version: require(path.join(root, 'tmp/portal-test/node_modules/jsdom/package.json')).version,
      passed: checks.length, checks, failed: Boolean(failure), error: failure ? String(failure) : null
    }, null, 2));
    console.log('RESULT: ' + checks.length + ' passed; ' + (failure ? '1 failure' : '0 failures'));
    process.exitCode = failure ? 1 : 0;
  }
})();
