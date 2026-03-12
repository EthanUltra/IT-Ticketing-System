require('dotenv').config();
const required = ['DATABASE_URL', 'JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'];
for (const key of required) { if (!process.env[key]) throw new Error('Missing env var: ' + key); }
module.exports = {
  port: parseInt(process.env.PORT || '4000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  isProd: process.env.NODE_ENV === 'production',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:5173',
  jwt: { accessSecret: process.env.JWT_ACCESS_SECRET, refreshSecret: process.env.JWT_REFRESH_SECRET, accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m', refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' },
  cookie: { secret: process.env.COOKIE_SECRET || 'dev_secret' },
};