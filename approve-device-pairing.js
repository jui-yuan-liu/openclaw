#!/usr/bin/env node
/**
 * 批准設備配對請求的腳本
 * 使用方法：node approve-device-pairing.js <requestId>
 */

import { readFileSync, writeFileSync } from 'fs';
import { randomBytes } from 'crypto';

function newToken() {
  return randomBytes(32).toString('hex');
}

function normalizeRole(role) {
  if (!role || typeof role !== 'string') return null;
  return role.trim() || null;
}

function normalizeScopes(scopes) {
  if (!Array.isArray(scopes)) return [];
  return scopes.filter((s) => typeof s === 'string' && s.trim()).map((s) => s.trim());
}

function mergeRoles(...args) {
  const roles = new Set();
  for (const arg of args) {
    if (Array.isArray(arg)) {
      for (const role of arg) {
        if (typeof role === 'string' && role.trim()) {
          roles.add(role.trim());
        }
      }
    } else if (typeof arg === 'string' && arg.trim()) {
      roles.add(arg.trim());
    }
  }
  return Array.from(roles);
}

function mergeScopes(...args) {
  const scopes = new Set();
  for (const arg of args) {
    if (Array.isArray(arg)) {
      for (const scope of arg) {
        if (typeof scope === 'string' && scope.trim()) {
          scopes.add(scope.trim());
        }
      }
    }
  }
  return Array.from(scopes);
}

const devicesDir = process.env.OPENCLAW_STATE_DIR 
  ? `${process.env.OPENCLAW_STATE_DIR}/devices`
  : `${process.env.HOME}/.openclaw/devices`;

const pendingPath = `${devicesDir}/pending.json`;
const pairedPath = `${devicesDir}/paired.json`;

const requestId = process.argv[2];

if (!requestId) {
  console.error('使用方法: node approve-device-pairing.js <requestId>');
  console.error('\n待處理的請求 ID:');
  try {
    const pending = JSON.parse(readFileSync(pendingPath, 'utf8'));
    for (const [id, req] of Object.entries(pending)) {
      console.error(`  ${id}: ${req.clientId} (${req.platform})`);
    }
  } catch (err) {
    console.error('無法讀取待處理請求');
  }
  process.exit(1);
}

try {
  // 讀取待處理請求
  const pendingRaw = readFileSync(pendingPath, 'utf8');
  const pending = JSON.parse(pendingRaw);
  
  const request = pending[requestId];
  if (!request) {
    console.error(`找不到請求 ID: ${requestId}`);
    process.exit(1);
  }

  // 讀取已配對設備
  let paired = {};
  try {
    const pairedRaw = readFileSync(pairedPath, 'utf8');
    paired = JSON.parse(pairedRaw);
  } catch {
    // 文件不存在，使用空對象
  }

  const now = Date.now();
  const existing = paired[request.deviceId];
  const roles = mergeRoles(existing?.roles, existing?.role, request.roles, request.role);
  const scopes = mergeScopes(existing?.scopes, request.scopes);
  const tokens = existing?.tokens ? { ...existing.tokens } : {};
  
  const roleForToken = normalizeRole(request.role);
  if (roleForToken) {
    const nextScopes = normalizeScopes(request.scopes);
    const existingToken = tokens[roleForToken];
    tokens[roleForToken] = {
      token: newToken(),
      role: roleForToken,
      scopes: nextScopes,
      createdAtMs: existingToken?.createdAtMs ?? now,
      rotatedAtMs: existingToken ? now : undefined,
      revokedAtMs: undefined,
      lastUsedAtMs: existingToken?.lastUsedAtMs,
    };
  }

  const device = {
    deviceId: request.deviceId,
    publicKey: request.publicKey,
    displayName: request.displayName,
    platform: request.platform,
    clientId: request.clientId,
    clientMode: request.clientMode,
    role: request.role,
    roles,
    scopes,
    remoteIp: request.remoteIp,
    tokens,
    createdAtMs: existing?.createdAtMs ?? now,
    approvedAtMs: now,
  };

  // 從待處理中移除
  delete pending[requestId];
  
  // 添加到已配對
  paired[device.deviceId] = device;

  // 寫回文件
  writeFileSync(pendingPath, JSON.stringify(pending, null, 2) + '\n', 'utf8');
  writeFileSync(pairedPath, JSON.stringify(paired, null, 2) + '\n', 'utf8');

  console.log(`✅ 已批准設備配對請求: ${requestId}`);
  console.log(`   設備 ID: ${device.deviceId}`);
  console.log(`   客戶端: ${device.clientId} (${device.platform})`);
  console.log(`   角色: ${device.role}`);
  console.log(`   Token: ${tokens[roleForToken]?.token}`);
  console.log('\n現在可以重新載入 UI 頁面了！');
} catch (err) {
  console.error('錯誤:', err.message);
  process.exit(1);
}
