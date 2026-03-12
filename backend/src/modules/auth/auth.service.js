const argon2 = require('argon2');
const prisma = require('../../config/prisma');
const { signAccessToken, signRefreshToken, verifyRefreshToken, expiresAt } = require('../../utils/tokens');
const { AuthError, ConflictError } = require('../../utils/errors');
const env = require('../../config/env');

async function register({ email, name, password }) {
  if (await prisma.user.findUnique({ where: { email } })) throw new ConflictError('Email already in use');
  const passwordHash = await argon2.hash(password, { type: argon2.argon2id });
  return prisma.user.create({ data: { email, name, passwordHash }, select: { id: true, email: true, name: true, role: true } });
}

async function login({ email, password }) {
  const user = await prisma.user.findUnique({ where: { email } });
  const dummy = '=19=65536,t=3,p=4';
  if (!user) { await argon2.verify(dummy, password).catch(() => {}); throw new AuthError('Invalid credentials'); }
  if (user.isLocked) throw new AuthError('Account locked. Contact support.');
  const valid = await argon2.verify(user.passwordHash, password);
  if (!valid) { const f = user.failedLogins + 1; await prisma.user.update({ where: { id: user.id }, data: { failedLogins: f, isLocked: f >= 5 } }); throw new AuthError('Invalid credentials'); }
  await prisma.user.update({ where: { id: user.id }, data: { failedLogins: 0 } });
  return issueTokens(user);
}

async function refresh(incoming) {
  let decoded; try { decoded = verifyRefreshToken(incoming); } catch { throw new AuthError('Invalid refresh token'); }
  const stored = await prisma.refreshToken.findUnique({ where: { token: incoming }, include: { user: true } });
  if (!stored) throw new AuthError('Token not found');
  if (stored.isRevoked) { await prisma.refreshToken.updateMany({ where: { userId: stored.userId }, data: { isRevoked: true } }); throw new AuthError('Token reuse detected.'); }
  if (stored.expiresAt < new Date()) throw new AuthError('Token expired');
  await prisma.refreshToken.update({ where: { id: stored.id }, data: { isRevoked: true } });
  return issueTokens(stored.user);
}

async function logout(token) { if (token) await prisma.refreshToken.updateMany({ where: { token }, data: { isRevoked: true } }); }

async function issueTokens(user) {
  const accessToken = signAccessToken({ userId: user.id, role: user.role, name: user.name });
  const { token: refreshToken } = signRefreshToken({ userId: user.id });
  await prisma.refreshToken.create({ data: { token: refreshToken, userId: user.id, expiresAt: expiresAt(env.jwt.refreshExpiresIn) } });
  return { accessToken, refreshToken, user: { id: user.id, email: user.email, name: user.name, role: user.role } };
}

module.exports = { register, login, refresh, logout };