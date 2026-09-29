// Exercise the release WASM through the same sync FRB bridge as the app.
// Compilation and native tests cannot catch unsupported browser clocks.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const pkg = process.argv[2];
assert.ok(pkg, 'usage: node wasm_smoke.mjs <built WASM pkg directory>');
globalThis.self = globalThis;
const glue = readFileSync(join(pkg, 'happy_core.js'), 'utf8');
const api = new Function(`${glue}\nreturn wasm_bindgen;`)();
api.initSync({ module: readFileSync(join(pkg, 'happy_core_bg.wasm')) });

// FRB 2.13 SSE uses unaligned little-endian lengths followed by raw bytes.
const int = (value) => {
  const bytes = Buffer.alloc(4);
  bytes.writeInt32LE(value);
  return bytes;
};
const bool = (value) => Buffer.from([value ? 1 : 0]);
const bytes = (value) => Buffer.concat([int(value.length), value]);
const string = (value) => bytes(Buffer.from(value, 'utf8'));
const list = (values, encode) =>
  Buffer.concat([int(values.length), ...values.map(encode)]);

class Reader {
  constructor(data) {
    this.data = Buffer.from(data);
    this.offset = 0;
  }

  byte() {
    assert.ok(this.offset < this.data.length, 'truncated SSE response');
    return this.data[this.offset++];
  }

  uint() {
    const value = this.data.readUInt32LE(this.offset);
    this.offset += 4;
    return value;
  }

  bytes() {
    const length = this.uint();
    const end = this.offset + length;
    assert.ok(end <= this.data.length, 'truncated SSE byte list');
    const value = this.data.subarray(this.offset, end);
    this.offset = end;
    return value;
  }

  optionalList(decode) {
    return Array.from({ length: this.uint() }, () =>
      this.byte() ? decode() : null);
  }

  done() {
    assert.equal(this.offset, this.data.length, 'unexpected SSE response tail');
  }
}

// Function IDs and layouts come from lib/core/native/generated/frb_generated.dart.
function callSync(id, input) {
  const output = api.frb_pde_ffi_dispatcher_sync(
    id, new Uint8Array(input), input.length, input.length,
  );
  const reader = new Reader(output);
  assert.equal(reader.byte(), 0, `FRB function ${id} did not succeed`);
  return reader;
}

function row(id, uuid, parentUuid, isSidechain) {
  return Buffer.concat([
    ...[id, uuid, parentUuid, '', '', '', '',
      isSidechain ? 'text' : 'tool-call', isSidechain ? '' : 'Task'].map(string),
    bool(isSidechain), bool(false), bool(true), string(''), list([], string),
  ]);
}

const rows = [
  row('task', 'task-uuid', '', false),
  row('child', 'child-uuid', 'task-uuid', true),
  row('orphan', 'orphan-uuid', 'missing', true),
];
// Repeat after crypto: a liveness probe alone missed the production panic.
function checkSidechains() {
  const result = callSync(9, list(rows, (value) => value));
  const assignments = result.optionalList(() => result.bytes().toString('utf8'));
  assert.deepEqual(assignments, [null, 'task', null]);
  result.uint(); // plan_micros
  result.done();
}
checkSidechains();

const key = Buffer.alloc(32, 7);
const plaintexts = ['{"text":"caffè ☕"}', '{"nested":[1,true,null]}'];
const nonces = [Buffer.alloc(12, 1), Buffer.alloc(12, 2)];
const associatedData = Buffer.from('wasm-smoke');
const encrypted = callSync(6, Buffer.concat([
  bytes(key), list(plaintexts, string), list(nonces, bytes), bytes(associatedData),
]));
const envelopes = encrypted.optionalList(() => encrypted.bytes());
assert.equal(envelopes.length, plaintexts.length);
assert.ok(envelopes.every((value) => value !== null));
encrypted.uint(); // encrypt_micros
encrypted.done();

const decrypted = callSync(4, Buffer.concat([
  bytes(key), list(envelopes, bytes), bytes(associatedData),
]));
assert.deepEqual(
  decrypted.optionalList(() => decrypted.bytes().toString('utf8')), plaintexts,
);
decrypted.done();
checkSidechains();
console.log('Release WASM sidechain planning and AES-GCM roundtrip passed.');
