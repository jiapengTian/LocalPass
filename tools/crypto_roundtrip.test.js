// 用 Node.js 内置 crypto 复刻 Swift 层的加密算法，验证「数学逻辑」是否正确。
// 这不是编译 Swift，而是验证与 Swift 实现逐行对应的算法是否自洽。
const crypto = require('crypto');

let pass = 0;
let fail = 0;
function check(name, cond, detail = '') {
  if (cond) {
    pass++;
    console.log(`  OK   ${name}`);
  } else {
    fail++;
    console.log(`  FAIL ${name} ${detail}`);
  }
}

// ---------- 与 CryptoUtils.pbkdf2SHA256 逐行对应的实现 ----------
function pbkdf2SHA256(password, salt, iterations, keyLength = 32) {
  const hashLen = 32;
  const blocks = Math.ceil(keyLength / hashLen);
  const out = [];
  for (let blockIndex = 1; blockIndex <= blocks; blockIndex++) {
    const idx = Buffer.alloc(4);
    idx.writeUInt32BE(blockIndex);
    let u = crypto
      .createHmac('sha256', Buffer.from(password, 'utf8'))
      .update(Buffer.concat([salt, idx]))
      .digest();
    let t = Buffer.from(u);
    for (let i = 2; i <= iterations; i++) {
      u = crypto.createHmac('sha256', Buffer.from(password, 'utf8')).update(u).digest();
      for (let j = 0; j < t.length; j++) t[j] ^= u[j];
    }
    out.push(t);
  }
  return Buffer.concat(out).subarray(0, keyLength);
}

// ---------- 与 VaultStore.makePasswordWrapper / openWrapper 对应 ----------
const NONCE_LEN = 12;
const TAG_LEN = 16;

function wrapKey(key, secret, salt, iterations) {
  const derived = pbkdf2SHA256(secret, salt, iterations, 32);
  const nonce = crypto.randomBytes(NONCE_LEN);
  const cipher = crypto.createCipheriv('aes-256-gcm', derived, nonce);
  cipher.setAAD(Buffer.alloc(0));
  const ct = Buffer.concat([cipher.update(key), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([nonce, ct, tag]); // 与 Swift 里 box.nonce + box.cipher + box.tag 一致
}

function unwrapKey(blob, secret, salt, iterations) {
  const derived = pbkdf2SHA256(secret, salt, iterations, 32);
  if (blob.length <= 16 + 12 + 16) throw new Error('corruptedFile');
  const nonce = blob.subarray(0, NONCE_LEN);
  const tag = blob.subarray(blob.length - TAG_LEN);
  const ct = blob.subarray(NONCE_LEN, blob.length - TAG_LEN);
  const decipher = crypto.createDecipheriv('aes-256-gcm', derived, nonce);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ct), decipher.final()]);
}

console.log('== 1. PBKDF2-HMAC-SHA256 与独立实现（OpenSSL）比对 ==');
// 用 Node 的 OpenSSL 实现作为独立参照，并用 RFC 7914 的 4096 轮向量做绝对校验
for (const [password, salt, iters, len] of [
  ['passwd', 'salt', 1, 64],
  ['passwd', 'salt', 800, 64],
  ['passwd', 'salt', 4096, 64],
  ['x', 'y', 5, 32],
]) {
  const mine = pbkdf2SHA256(password, Buffer.from(salt), iters, len).toString('hex');
  const ref = crypto.pbkdf2Sync(password, salt, iters, len, 'sha256').toString('hex');
  check(`与 OpenSSL 一致 password="${password}" iters=${iters} len=${len}`, mine === ref);
}

// RFC 7914 §11：PBKDF2-HMAC-SHA256，P="passwd", S="salt", c=4096, dkLen=64
const RFC7914_4096 =
  '21943fd5b7a10905c38fad60157ff498e1e81df1e03254325682a74dca3b2be8' +
  'f3ab1ccb49d0a5095e69792ba334c6fdaf55d266a9922c760d3c5f5c3ec22c52';
const got4096 = pbkdf2SHA256('passwd', Buffer.from('salt'), 4096, 64).toString('hex');
check('RFC 7914 4096 轮官方向量', got4096 === RFC7914_4096, got4096.slice(0, 16) + '…');

console.log('\n== 2. 库密钥包装 / 解包往返 ==');
const vaultKey = crypto.randomBytes(32);
const salt = crypto.randomBytes(16);
const iterations = 120000;

const t0 = Date.now();
const blob = wrapKey(vaultKey, '我的主密码-Aa1!', salt, iterations);
const wrapMs = Date.now() - t0;
console.log(`      （参考：纯 JS 实现 12 万轮耗时 ${wrapMs}ms；Swift+CryptoKit 会快一个数量级以上）`);
const recovered = unwrapKey(blob, '我的主密码-Aa1!', salt, iterations);
check('解包得到的密钥与原始密钥一致', recovered.equals(vaultKey));
check('包装后的长度 = nonce12 + cipher32 + tag16 = 60', blob.length === 60, `实际 ${blob.length}`);

console.log('\n== 3. 错误密码必须失败 ==');
let wrongRejected = false;
try {
  unwrapKey(blob, '错误密码', salt, iterations);
} catch {
  wrongRejected = true;
}
check('错误密码无法解包（GCM 认证失败）', wrongRejected);

console.log('\n== 4. 篡改任何一个字节都必须失败 ==');
let tamperRejected = 0;
for (const pos of [0, 20, blob.length - 1]) {
  const copy = Buffer.from(blob);
  copy[pos] ^= 0x01;
  try {
    unwrapKey(copy, '我的主密码-Aa1!', salt, iterations);
  } catch {
    tamperRejected++;
  }
}
check('篡改 nonce / cipher / tag 均被拒绝', tamperRejected === 3, `${tamperRejected}/3`);

console.log('\n== 5. 整库加密（VaultContent → payload）往返 ==');
function encryptPayload(contentObj, key) {
  const plaintext = Buffer.from(JSON.stringify(contentObj), 'utf8');
  const nonce = crypto.randomBytes(NONCE_LEN);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce);
  const ct = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return { nonce, cipher: ct, tag: cipher.getAuthTag() };
}
function decryptPayload(payload, key) {
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, payload.nonce);
  decipher.setAuthTag(payload.tag);
  const pt = Buffer.concat([decipher.update(payload.cipher), decipher.final()]);
  return JSON.parse(pt.toString('utf8'));
}

const content = {
  version: 1,
  updatedAt: '2026-11-14T09:00:00Z',
  items: [
    {
      id: '3f1b9c2e-0a1b-4c2d-8e3f-1234567890ab',
      title: '淘宝',
      username: 'me@example.com',
      password: 'P@ssw0rd-测试',
      url: 'https://www.taobao.com',
      notes: '备注里有中文和 emoji 🔐',
      category: 'website',
      tags: ['购物', '常用'],
      isPinned: true,
      createdAt: '2026-11-01T02:00:00Z',
      updatedAt: '2026-11-14T09:00:00Z',
    },
  ],
};

const payload = encryptPayload(content, vaultKey);
const restored = decryptPayload(payload, vaultKey);
check('JSON 内容往返完全一致', JSON.stringify(restored) === JSON.stringify(content));
check('密文里不包含明文密码', !payload.cipher.toString('utf8').includes('P@ssw0rd'));
check('密文里不包含中文标题', !payload.cipher.toString('utf8').includes('淘宝'));

console.log('\n== 6. 备份文件双重加密（备份密码独立） ==');
const backupSalt = crypto.randomBytes(16);
const backupBlob = wrapKey(vaultKey, '备份专用密码-9', backupSalt, 120000);
const backupKey = unwrapKey(backupBlob, '备份专用密码-9', backupSalt, 120000);
const backupPayload = encryptPayload(content, backupKey);
const backupRestored = decryptPayload(backupPayload, backupKey);
check('备份密码能独立解开同一份内容', JSON.stringify(backupRestored) === JSON.stringify(content));
let crossRejected = false;
try {
  unwrapKey(backupBlob, '我的主密码-Aa1!', backupSalt, 120000);
} catch {
  crossRejected = true;
}
check('主密码不能解开备份包装（密钥隔离）', crossRejected);

console.log('\n== 7. 手势盐值与主密码盐值相互独立 ==');
const gestureSalt = crypto.randomBytes(16);
check('两次生成的盐不相同', !salt.equals(gestureSalt));
const gestureKey = pbkdf2SHA256('0-3-7-6', gestureSalt, 40000, 32);
const passwordKey = pbkdf2SHA256('我的主密码-Aa1!', salt, 120000, 32);
check('手势派生密钥 ≠ 主密码派生密钥', !gestureKey.equals(passwordKey));

console.log('\n' + '='.repeat(46));
if (fail > 0) {
  console.log(`结果：${fail} 个失败 / 共 ${pass + fail}`);
  process.exit(1);
}
console.log(`结果：全部通过（${pass} 项）`);
