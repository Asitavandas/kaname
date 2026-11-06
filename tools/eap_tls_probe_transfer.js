'use strict';
// Private pilot SFTP transfer. Password arrives once on stdin; never saved.
const { Client } = require('../ssh-bridge/node_modules/ssh2');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const readline = require('node:readline');
const { pipeline } = require('node:stream/promises');
const assert = require('node:assert/strict');
const hostKey = Buffer.from('AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPhn+EYJy3uTA/Jpu07eW/WJTx43hchS161OW05ZLakSoq1Isi1lJzxWznBMvHNuJvA/dxXEw1noLOfWLjG1/S8=', 'base64');
const rl = readline.createInterface({ input: process.stdin, terminal: false });
console.log(JSON.stringify({ event: 'AUTHWIRE_PRIVATE_SFTP_INPUT_READY' }));
rl.once('line', line => {
  rl.close(); process.stdin.pause();
  const cfg = JSON.parse(line), run = path.basename(__dirname);
  assert(/^20261106-negative-[0-9a-f]{16}$/.test(run));
  assert(/^[a-f0-9]{64}$/.test(cfg.bundle_sha256));
  const conn = new Client(); let verified = false;
  const deadline = setTimeout(() => { conn.destroy(); process.exitCode = 2; }, 30000);
  conn.on('ready', () => conn.sftp(async (error, sftp) => {
    try {
      assert(!error && verified, 'Pinned SFTP session required');
      for (const file of ['bundle.json', 'manifest.json']) {
        const target = path.join(__dirname, file);
        const remote = '/home/segmentiq/' + run + '/' + file;
        const info = await new Promise((resolve, reject) => sftp.stat(remote, (err, result) => err ? reject(err) : resolve(result)));
        assert(info.size > 0 && info.size <= 65536 && (info.mode & 0o077) === 0, 'Private bounded source required');
        await pipeline(sftp.createReadStream(remote), fs.createWriteStream(target, { flags: 'wx', mode: 0o600 }));
        const hash = crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex');
        if (file === 'bundle.json') assert.equal(hash, cfg.bundle_sha256, 'Credential bundle hash mismatch');
        console.log(JSON.stringify({ event: 'AUTHWIRE_PRIVATE_SFTP_VERIFIED', file, sha256: hash, bytes: info.size }));
      }
    } catch (error) { console.log(JSON.stringify({ event: 'AUTHWIRE_PRIVATE_SFTP_FAILED', category: error.code || error.name })); process.exitCode = 2; }
    finally { cfg.password = ''; conn.end(); }
  }));
  conn.on('error', error => { console.log(JSON.stringify({ event: 'AUTHWIRE_PRIVATE_SFTP_FAILED', category: error.level || error.code })); process.exitCode = 2; });
  conn.on('close', () => { cfg.password = ''; clearTimeout(deadline); });
  conn.connect({ host: '10.35.50.246', port: 22, username: 'segmentiq', password: cfg.password,
    readyTimeout: 10000, algorithms: { serverHostKey: ['ecdsa-sha2-nistp256'] },
    hostVerifier: key => { verified = Buffer.isBuffer(key) && key.length === hostKey.length && crypto.timingSafeEqual(key, hostKey); return verified; } });
});
