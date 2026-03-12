const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const env = require('../config/env');
function signAccessToken(payload) { return jwt.sign(payload, env.jwt.accessSecret, { expiresIn: env.jwt.accessExpiresIn }); }
function signRefreshToken(payload) { const jti = uuidv4(); return { token: jwt.sign({ ...payload, jti }, env.jwt.refreshSecret, { expiresIn: env.jwt.refreshExpiresIn }), jti }; }
function verifyAccessToken(token) { return jwt.verify(token, env.jwt.accessSecret); }
function verifyRefreshToken(token) { return jwt.verify(token, env.jwt.refreshSecret); }
function expiresAt(duration) { const units = { m: 60, h: 3600, d: 86400 }; const [, amount, unit] = duration.match(/^(\d+)([mhd])$/); return new Date(Date.now() + parseInt(amount) * units[unit] * 1000); }
module.exports = { signAccessToken, signRefreshToken, verifyAccessToken, verifyRefreshToken, expiresAt };