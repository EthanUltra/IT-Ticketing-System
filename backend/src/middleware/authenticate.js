const { verifyAccessToken } = require('../utils/tokens');
const { AuthError } = require('../utils/errors');
function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) return next(new AuthError('No token provided'));
  try { const decoded = verifyAccessToken(header.split(' ')[1]); req.user = { id: decoded.userId, role: decoded.role, name: decoded.name }; next(); }
  catch (err) { next(new AuthError(err.name === 'TokenExpiredError' ? 'Token expired' : 'Invalid token')); }
}
module.exports = { authenticate };