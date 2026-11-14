// Extract the inline script from web/index.html and test it in Node.
// Sections: structure / syntax / crypto / brand recognition / media vault.
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');

const htmlPath = path.join(__dirname, '..', 'web', 'index.html');
const html = fs.readFileSync(htmlPath, 'utf8');

let pass = 0, fail = 0;
const check = (name, ok, detail = '') => {
  if (ok) { pass++; console.log(`  OK   ${name}`); }
  else { fail++; console.log(`  FAIL ${name} ${detail}`); }
};

// ---------- 1. structure ----------
console.log('== 1. HTML structure ==');
check('starts with <!DOCTYPE html>', /^<!DOCTYPE html>/i.test(html.trim()));
check('lang=zh-CN', html.includes('<html lang="zh-CN">'));
check('exactly one inline <script>', (html.match(/<script>/g) || []).length === 1);
check('no external http(s) references', !/src="https?:|href="https?:/.test(html));
const ids = ['lockScreen','setupScreen','homeScreen','detailScreen','settingsScreen','pwInput','btnUnlock',
  'patternWrap','newPw','btnCreate','list','detailBody','settingsBody','sheet','toast','privacy','search',
  'vaultTitle','passwordPane','mediaPane','mediaGrid','mediaFilter','btnMediaAdd','viewer','vBody','importBox'];
for (const id of ids) check(`#${id} exists`, html.includes(`id="${id}"`));
check('two vault tabs', html.includes('data-vault="passwords"') && html.includes('data-vault="media"'));
check('media module inlined', html.includes('importMediaFiles') && html.includes('openViewer'));
check('uses IndexedDB for media blobs', html.includes('indexedDB.open'));
check('lock screen has forgot-password entry', html.includes('id="btnForgot"') && html.includes('忘记主密码'));
check('reset flow offers restore + wipe', html.includes('showResetSheet') && html.includes('recoverFromBackup') && html.includes('wipeAndRestart'));

// ---------- 2. syntax ----------
console.log('\n== 2. script syntax ==');
const scriptStart = html.indexOf('<script>') + '<script>'.length;
const scriptEnd = html.lastIndexOf('</script>');
const script = html.slice(scriptStart, scriptEnd);
check('script not empty', script.trim().length > 5000);
try {
  new vm.Script(script, { filename: 'index-inline.js' });
  check('V8 parses the inline script (no syntax error)', true);
} catch (e) {
  check('V8 parses the inline script (no syntax error)', false, e.message);
}

function extract(name) {
  const marker = `function ${name}(`;
  const idx = script.indexOf(marker);
  if (idx < 0) throw new Error('not found: ' + name);
  const start = script.slice(Math.max(0, idx - 6), idx) === 'async ' ? idx - 6 : idx;
  let i = script.indexOf('{', idx), depth = 0;
  for (let j = i; j < script.length; j++) {
    if (script[j] === '{') depth++;
    else if (script[j] === '}') { depth--; if (depth === 0) return script.slice(start, j + 1); }
  }
  throw new Error('unterminated: ' + name);
}
for (const fn of ['pbkdf2','aesEncrypt','aesDecrypt','wrapKey','unwrapKey','strengthOf','esc','bioSecret',
                  'registerBiometric','brandImpl','domainOf','hashColor','hexA','iconHTML','catById',
                  'openCategoryEditor','bindCategoryLongPress','updateHeaderStats','showResetSheet','wipeAndRestart','recoverFromBackup','catalogOf','importMediaFiles','openViewer','switchVault','fmtBytes','fmtDuration'])
  check(`function ${fn} present`, script.includes(`function ${fn}(`));
check('no stale CATS references', !/\bCATS\.map|\bcatOf\(/.test(script));

const sandbox = { crypto: crypto.webcrypto, TextEncoder, TextDecoder, Uint8Array, Array, JSON, Math, console, btoa, atob, Date, Promise, URL };
sandbox.window = sandbox;
vm.createContext(sandbox);
const helpers = `
const enc = new TextEncoder();
const dec = new TextDecoder();
const b64 = {
  enc(buffer) {
    const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
    let out = '';
    const CHUNK = 0x8000;
    for (let i = 0; i < bytes.length; i += CHUNK) {
      out += String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK));
    }
    return btoa(out);
  },
  dec(str) {
    const bin = atob(str);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  },
};
const rand = n => crypto.getRandomValues(new Uint8Array(n));
const toHex = b => [...b].map(x => x.toString(16).padStart(2, '0')).join('');
const KDF_PW = 120000, KDF_GESTURE = 40000, KDF_BACKUP = 120000;
globalThis.__api = (async () => {
${extract('pbkdf2')}
${extract('aesKey')}
${extract('aesEncrypt')}
${extract('aesDecrypt')}
${extract('wrapKey')}
${extract('unwrapKey')}
${extract('probeVault')}
${extract('strengthOf')}
${extract('esc')}
  return { pbkdf2, aesKey, aesEncrypt, aesDecrypt, wrapKey, unwrapKey, strengthOf, esc, b64, rand };
})();
globalThis.__probe = (async () => {
  const { pbkdf2, aesDecrypt } = await globalThis.__api;
  const probeVault = ${extract('probeVault').replace(/^async function probeVault/, 'async function')};
  return probeVault;
})();
`;
vm.runInContext(helpers, sandbox);

// ---------- 3. brand recognition ----------
console.log('\n== 3. brand recognition ==');
const brandCtx = { crypto: crypto.webcrypto, TextEncoder, TextDecoder, Uint8Array, Array, JSON, Math, console, btoa, atob, Date, Promise, URL };
vm.createContext(brandCtx);
const brandSrc = `
const DEFAULT_CATS = [
  { id: 'website', name: 'website', icon: 'W', color: '#3378F5' },
  { id: 'other', name: 'other', icon: 'O', color: '#767A86' },
];
const FALLBACK_CAT = DEFAULT_CATS[1];
const CAT_COLORS = ['#111111', '#222222', '#333333'];
const CAT_COLORS_DARK = { website: '#4C8DFF', other: '#8C93A6' };
const State = { store: null, settings: { siteIcons: true } };
function loadCategories() { return null; }
function catById(id) {
  const cats = (State.store && State.store.categories) || loadCategories() || DEFAULT_CATS;
  return cats.find(c => c.id === id) || FALLBACK_CAT;
}
${extract('domainOf')}
${script.slice(script.indexOf('const BRANDS = ['), script.indexOf('function hashColor'))}
${script.slice(script.indexOf('const BRAND_ICON = {'), script.indexOf('const CAT_COLORS_DARK'))}
${extract('hashColor')}
${extract('hexA')}
${extract('faviconCandidates')}
${extract('faviconURL')}
${extract('brandImpl')}
${extract('iconHTML')}
${extract('esc')}
globalThis.__brand = { brandImpl, domainOf, hashColor, hexA, iconHTML, esc, faviconURL };
globalThis.__state = State;
`;
vm.runInContext(brandSrc, brandCtx);
const { brandImpl, domainOf, iconHTML, esc: escFn } = brandCtx.__brand;

const b1 = brandImpl({ title: 'taobao', url: 'https://www.taobao.com/login', category: 'website' });
check('taobao.com -> brand sym bag', b1.kind === 'brand' && b1.sym === 'bag', JSON.stringify(b1));
const b2 = brandImpl({ title: 'GitHub', url: '', category: 'app' });
check('title GitHub -> brand code', b2.kind === 'brand' && b2.sym === 'code', JSON.stringify(b2));
const b3 = brandImpl({ title: 'blog', url: 'https://blog.example.org', category: 'website' });
check('unknown domain -> letter icon', b3.kind === 'letter' && b3.letter === 'B', JSON.stringify(b3));
const b4 = brandImpl({ title: '某网站', url: '', category: 'other' });
check('no url match -> first letter', b4.kind === 'letter' && b4.letter === '某', JSON.stringify(b4));
check('domainOf strips www and path', domainOf('www.qq.com/a/b') === 'qq.com');
check('domainOf handles bare host', domainOf('qq.com') === 'qq.com');
check('domainOf handles bad input', domainOf('not a url') === '');
check('hexA turns hex into rgba', brandCtx.__brand.hexA('#FF5000', .2) === 'rgba(255,80,0,0.2)');
check('iconHTML renders an avatar', iconHTML({ title: 'taobao', url: 'taobao.com' }, 40).includes('class="avatar"'));
check('iconHTML uses b- symbol for brands', iconHTML({ title: 'taobao', url: 'taobao.com' }, 40).includes('#b-bag'));

// favicon 跟随网址
const fv = brandCtx.__brand.faviconURL;
check('faviconURL: https + 域名', fv('https://www.taobao.com/login') === 'https://taobao.com/favicon.ico', fv('https://www.taobao.com/login'));
check('faviconURL: 无协议按 https', fv('taobao.com') === 'https://taobao.com/favicon.ico', fv('taobao.com'));
check('faviconURL: http 保留协议', fv('http://intranet.local:8080/x') === 'http://intranet.local/favicon.ico', fv('http://intranet.local:8080/x'));
check('faviconURL: 无网址返回空', fv('') === '');
const withLogo = iconHTML({ title: 'taobao', url: 'taobao.com' }, 40);
check('有网址时叠加 site-logo 图层', withLogo.includes('class="site-logo"') && withLogo.includes('https://taobao.com/favicon.ico'));
check('favicon 失败时自动隐藏或换 www', withLogo.includes("this.style.display='none'") || withLogo.includes('data-alt'));
check('无 www 域名会准备 www 兜底', withLogo.includes('data-alt="https://www.taobao.com/favicon.ico"'), withLogo.slice(0, 200));
const custom = iconHTML({ title: 'taobao', url: 'taobao.com', icon: 'data:image/png;base64,AAA' }, 40);
check('手动上传的图标优先', custom.includes('data:image/png;base64,AAA') && !custom.includes('favicon.ico'));
brandCtx.__state.settings.siteIcons = false;
const noNet = iconHTML({ title: 'taobao', url: 'taobao.com' }, 40);
check('关闭联网后不请求 favicon', !noNet.includes('favicon.ico') && noNet.includes('#b-bag'));
brandCtx.__state.settings.siteIcons = true;

check('esc still escapes', escFn('<x>') === '&lt;x&gt;');

// ---------- 4. media helpers (pure) ----------
console.log('\n== 4. media helpers ==');
const mediaCtx = { crypto: crypto.webcrypto, TextEncoder, TextDecoder, Uint8Array, Array, JSON, Math, console, btoa, atob, Date, Promise, URL };
vm.createContext(mediaCtx);
const mediaSrc = `
${extract('fmtBytes')}
${extract('fmtDuration')}
globalThis.__media = { fmtBytes, fmtDuration };
`;
vm.runInContext(mediaSrc, mediaCtx);
const m = mediaCtx.__media;
check('fmtBytes 1024 -> 1 KB', m.fmtBytes(1024) === '1 KB', m.fmtBytes(1024));
check('fmtBytes 1536 -> 2 KB', m.fmtBytes(1536) === '2 KB', m.fmtBytes(1536));
check('fmtBytes 1MB', m.fmtBytes(1024 * 1024) === '1.0 MB', m.fmtBytes(1024 * 1024));
check('fmtBytes 0', m.fmtBytes(0) === '0 B');
check('fmtDuration 65 -> 1:05', m.fmtDuration(65) === '1:05', m.fmtDuration(65));
check('fmtDuration 9 -> 0:09', m.fmtDuration(9) === '0:09');
check('fmtDuration undefined -> empty', m.fmtDuration(undefined) === '');

// ---------- 4b. password variants ----------
const pvCtx = { TextEncoder, TextDecoder, Uint8Array, Array, JSON, Math, console, Date, Promise, String };
vm.createContext(pvCtx);
vm.runInContext(`
${extract('toHalfWidth')}
${extract('passwordVariants')}
globalThis.__pv = { toHalfWidth, passwordVariants };
`, pvCtx);
const { toHalfWidth, passwordVariants } = pvCtx.__pv;

check('全角数字转半角', toHalfWidth('１１１１１１１１') === '11111111', toHalfWidth('１１１１１１１１'));
check('全角字母转半角', toHalfWidth('ＡＢＣ') === 'ABC');
check('全角空格转换', toHalfWidth('a　b') === 'a b');
const vAllDigits = passwordVariants('11111111');
check('纯数字密码去重后只剩 1 个变体', vAllDigits.length === 1, JSON.stringify(vAllDigits.map(v => v.label)));
const vFull = passwordVariants('１１１１１１１１');
check('全角密码能生成半角变体', vFull.some(v => v.value === '11111111'), JSON.stringify(vFull.map(v => v.label)));
const vSpace = passwordVariants('  abcd1234  ');
check('带空格密码能生成 trim 变体', vSpace.some(v => v.value === 'abcd1234'));
const vCase = passwordVariants('Abcd1234');
check('大小写变体齐全', vCase.some(v => v.value === 'abcd1234') && vCase.some(v => v.value === 'ABCD1234'));
check('空密码不生成变体', passwordVariants('').length === 0);

// ---------- 5. async crypto + media payload ----------
(async () => {
  console.log('\n== 5. crypto + media payload ==');
  const sb = await sandbox.__api;

  const salt = new Uint8Array(16).fill(7);
  const mine = await sb.pbkdf2('passwd', salt, 1000);
  const ref = crypto.pbkdf2Sync('passwd', Buffer.from(salt), 1000, 32, 'sha256');
  check('PBKDF2 matches OpenSSL', Buffer.from(mine).equals(ref));

  const vaultKey = sb.rand(32);
  const wrapped = await sb.wrapKey(vaultKey, 'master-Aa1!', sb.rand(16), 1000);
  const back = await sb.unwrapKey(wrapped, 'master-Aa1!');
  check('wrap/unwrap round trip', back && Buffer.from(back).equals(Buffer.from(vaultKey)));
  check('wrapped has alg/iterations/salt/iv/data', ['alg','iterations','salt','iv','data'].every(k => k in wrapped));
  check('wrong password returns null', (await sb.unwrapKey(wrapped, 'wrong')) === null);

  const tampered = JSON.parse(JSON.stringify(wrapped));
  const bytes = sb.b64.dec(tampered.data);
  bytes[3] ^= 1;
  tampered.data = sb.b64.enc(bytes);
  check('tampered ciphertext rejected', (await sb.unwrapKey(tampered, 'master-Aa1!')) === null);

  const store = { version: 1, items: [{ id: 'x', title: 'taobao', username: 'me@example.com', password: 'P@ss1' }] };
  const box = await sb.aesEncrypt(vaultKey, new TextEncoder().encode(JSON.stringify(store)));
  const plain = await sb.aesDecrypt(vaultKey, box);
  check('vault JSON round trip', JSON.stringify(JSON.parse(new TextDecoder().decode(plain))) === JSON.stringify(store));

  // 媒体：2MB 二进制 -> 加密 -> 存储结构 -> 解密
  const mediaKey = sb.rand(32);
  const original = new Uint8Array(crypto.randomBytes(2 * 1024 * 1024));
  const mbox = await sb.aesEncrypt(mediaKey, original);
  const stored = JSON.parse(JSON.stringify({ v: 1, ...mbox }));
  check('media stored as v/iv/data', ['v','iv','data'].every(k => k in stored));
  const mplain = await sb.aesDecrypt(mediaKey, stored);
  check('2MB media round trip', Buffer.from(mplain).equals(Buffer.from(original)));

  const mbad = JSON.parse(JSON.stringify(stored));
  const mb = sb.b64.dec(mbad.data);
  mb[100] ^= 0xFF;
  mbad.data = sb.b64.enc(mb);
  let mediaRejected = false;
  try { await sb.aesDecrypt(mediaKey, mbad); } catch { mediaRejected = true; }
  check('tampered media rejected', mediaRejected);

  let wrongKeyRejected = false;
  try { await sb.aesDecrypt(sb.rand(32), stored); } catch { wrongKeyRejected = true; }
  check('wrong key cannot decrypt media', wrongKeyRejected);

  // ---------- 7. probeVault: 区分密码错 / 数据坏 ----------
  console.log('\n== 7. unlock diagnostics ==');
  const pv = await sandbox.__probe;
  const goodWrap = await sb.wrapKey(sb.rand(32), 'mypass-123', sb.rand(16), 1000);

  const p1 = await pv('mypass-123', goodWrap);
  check('probe: 正确密码 -> ok', p1.ok === true && p1.key && p1.key.length === 32);

  const p2 = await pv('wrong-pass', goodWrap);
  check('probe: 错误密码 -> auth', p2.ok === false && p2.reason === 'auth', JSON.stringify(p2));

  const p3 = await pv('x', null);
  check('probe: 缺少包装段 -> format', p3.reason === 'format');

  const p4 = await pv('x', { iv: 'YQ==', data: 'YQ==' });
  check('probe: 缺少 salt -> format', p4.reason === 'format');

  const p5 = await pv('x', { salt: 'not-base64!!', iv: 'YQ==', data: 'YQ==', iterations: 1000 });
  check('probe: 非法 salt -> format', p5.reason === 'format');

  const p6 = await pv('x', { ...goodWrap, iterations: 0 });
  check('probe: 迭代次数异常 -> format', p6.reason === 'format');

  const p7 = await pv('x', { ...goodWrap, data: goodWrap.data.slice(0, 20) });
  check('probe: 密文被截断 -> auth（认证失败）', p7.reason === 'auth', JSON.stringify(p7));

  const cases = [['', 1], ['abc', 1], ['abcdefgh', 1], ['abcdefgh1!', 2], ['Abcdefgh12345678', 3]];
  for (const [pw, n] of cases) {
    const s = sb.strengthOf(pw);
    check(`strength("${pw}") = ${n}`, s.n === n, `got ${s.n}`);
  }

  // ---------- 6. backup envelope (forgot-password recovery path) ----------
  console.log('\n== 6. backup envelope ==');
  const backupPw = 'backup-pass-9';
  const bSalt = sb.rand(16);
  const bKek = await sb.pbkdf2(backupPw, bSalt, 1000);
  const storeSnapshot = { version: 1, items: [{ id: 'a', title: 'x' }], categories: [] };
  const bBox = await sb.aesEncrypt(bKek, new TextEncoder().encode(JSON.stringify(storeSnapshot)));
  const envelope = { format: 'LocalPass-Backup', version: 1, kdf: 'PBKDF2-HMAC-SHA256', iterations: 1000, salt: sb.b64.enc(bSalt), ...bBox };
  check('envelope carries format + kdf + salt + iv + data',
    ['format','kdf','iterations','salt','iv','data'].every(k => k in envelope));
  const bKek2 = await sb.pbkdf2(backupPw, sb.b64.dec(envelope.salt), envelope.iterations);
  const restored = JSON.parse(new TextDecoder().decode(await sb.aesDecrypt(bKek2, { iv: envelope.iv, data: envelope.data })));
  check('backup restores the exact snapshot', JSON.stringify(restored) === JSON.stringify(storeSnapshot));
  const bKek3 = await sb.pbkdf2('wrong-backup-pass', sb.b64.dec(envelope.salt), envelope.iterations);
  let backupRejected = false;
  try { await sb.aesDecrypt(bKek3, { iv: envelope.iv, data: envelope.data }); } catch { backupRejected = true; }
  check('wrong backup password rejected', backupRejected);

  console.log('\n' + '='.repeat(46));
  if (fail) { console.log(`RESULT: ${fail} failed / ${pass + fail}`); process.exit(1); }
  console.log(`RESULT: all passed (${pass} checks)`);
})();
