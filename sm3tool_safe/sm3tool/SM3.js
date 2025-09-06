#!/usr/bin/env node
const fs = require('fs');

// Minimal pure-JS SM3 implementation (operates on Buffer/Uint8Array)
// Returns hex string (lowercase)
function rotl(x, n) {
  return ((x << n) | (x >>> (32 - n))) >>> 0;
}

function toHexStr(num) {
  let s = num.toString(16);
  return ('00000000' + s).slice(-8);
}

function sm3(msg) {
  let msgBytes;
  if (Buffer.isBuffer(msg)) msgBytes = msg;
  else if (typeof msg === 'string') msgBytes = Buffer.from(msg, 'utf8');
  else if (msg instanceof Uint8Array) msgBytes = Buffer.from(msg);
  else msgBytes = Buffer.from(String(msg));

  const iv = [
    0x7380166f, 0x4914b2b9, 0x172442d7, 0xda8a0600,
    0xa96f30bc, 0x163138aa, 0xe38dee4d, 0xb0fb0e4e
  ];

  const T = new Array(64).fill(0).map((_, j) => (j < 16 ? 0x79cc4519 : 0x7a879d8a));

  // padding
  const len = msgBytes.length * 8;
  const k = (448 - (len + 1)) % 512;
  const padLen = ((k + 1) + 64) / 8;
  const padded = Buffer.concat([msgBytes, Buffer.from([0x80]), Buffer.alloc(padLen - 1 - 8), Buffer.alloc(8)]);
  // write length big-endian
  padded.writeUInt32BE(Math.floor(len / 0x100000000), padded.length - 8);
  padded.writeUInt32BE(len >>> 0, padded.length - 4);

  const n = padded.length / 64;
  let V = iv.slice();

  for (let i = 0; i < n; i++) {
    const B = padded.slice(i * 64, (i + 1) * 64);
    const W = new Array(68).fill(0);
    const W1 = new Array(64).fill(0);
    for (let j = 0; j < 16; j++) W[j] = B.readUInt32BE(j * 4);
    for (let j = 16; j < 68; j++) {
      const x = W[j - 16] ^ W[j - 9] ^ rotl(W[j - 3], 15);
      W[j] = ( (P1(x)) ^ rotl(W[j - 13], 7) ^ W[j - 6]) >>> 0;
    }
    for (let j = 0; j < 64; j++) W1[j] = (W[j] ^ W[j + 4]) >>> 0;

    let A = V[0], Bv = V[1], C = V[2], D = V[3], E = V[4], F = V[5], G = V[6], H = V[7];
    for (let j = 0; j < 64; j++) {
      const SS1 = rotl(((rotl(A, 12) + E + rotl(T[j], j)) >>> 0), 7);
      const SS2 = (SS1 ^ rotl(A, 12)) >>> 0;
      const TT1 = ( (FFj(A, Bv, C, j) + D + SS2 + W1[j]) ) >>> 0;
      const TT2 = ( (GGj(E, F, G, j) + H + SS1 + W[j]) ) >>> 0;
      D = C;
      C = rotl(Bv, 9);
      Bv = A;
      A = TT1 >>> 0;
      H = G;
      G = rotl(F, 19);
      F = E;
      E = P0(TT2) >>> 0;
    }
    V = [
      A ^ V[0], Bv ^ V[1], C ^ V[2], D ^ V[3],
      E ^ V[4], F ^ V[5], G ^ V[6], H ^ V[7]
    ].map(x => x >>> 0);
  }

  return V.map(toHexStr).join('');

  function P0(x) { return (x ^ rotl(x, 9) ^ rotl(x, 17)) >>> 0; }
  function P1(x) { return (x ^ rotl(x, 15) ^ rotl(x, 23)) >>> 0; }
  function FFj(x, y, z, j) { return j < 16 ? (x ^ y ^ z) >>> 0 : (((x & y) | (x & z) | (y & z))) >>> 0; }
  function GGj(x, y, z, j) { return j < 16 ? (x ^ y ^ z) >>> 0 : (((x & y) | ((~x) & z))) >>> 0; }
}

function computeAndPrint(data) {
  const hash = sm3(data);
  console.log(String(hash).toUpperCase());
}

function readStdin(cb) {
  const chunks = [];
  process.stdin.on('data', (d) => chunks.push(Buffer.from(d)));
  process.stdin.on('end', () => cb(Buffer.concat(chunks)));
  process.stdin.resume();
}

const args = process.argv.slice(2);
if (args.length === 0) {
  // If piped input is present, read it; otherwise show usage
  if (!process.stdin.isTTY) {
  readStdin((data) => computeAndPrint(data));
  } else {
    console.log('用法: sm3 <string|file>\n或: echo "text" | sm3\n选项: -f/--file <path>');
  }
} else {
  const first = args[0];
  if (first === '-' ) {
    // explicit stdin
    if (process.stdin.isTTY) {
      console.error('等待标准输入，但未检测到数据。');
      process.exit(1);
    }
    readStdin((data) => computeAndPrint(data));
  } else if (first === '-f' || first === '--file') {
    const path = args[1];
    if (!path) {
      console.error('缺少文件路径。');
      process.exit(2);
    }
    if (!fs.existsSync(path)) {
      console.error('文件未找到: ' + path);
      process.exit(2);
    }
    const data = fs.readFileSync(path);
    computeAndPrint(data);
  } else {
    // treat as file if exists, otherwise as string
    try {
      if (fs.existsSync(first) && fs.statSync(first).isFile()) {
        const data = fs.readFileSync(first);
        computeAndPrint(data);
      } else {
        computeAndPrint(Buffer.from(first, 'utf8'));
      }
    } catch (e) {
      // fallback to string
      computeAndPrint(Buffer.from(first, 'utf8'));
    }
  }
}