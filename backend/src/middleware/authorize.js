const { ForbiddenError } = require('../utils/errors');
const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user?.role)) return next(new ForbiddenError('Insufficient permissions'));
  next();
};
module.exports = { authorize };