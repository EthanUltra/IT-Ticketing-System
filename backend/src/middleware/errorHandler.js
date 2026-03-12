const { AppError } = require('../utils/errors');
function errorHandler(err, req, res, next) {
  if (err.name === 'ZodError') return res.status(400).json({ status: 'error', message: 'Validation failed', errors: err.errors.map(e => ({ field: e.path.join('.'), message: e.message })) });
  if (err instanceof AppError) return res.status(err.statusCode).json({ status: 'error', message: err.message });
  console.error(err);
  res.status(500).json({ status: 'error', message: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message });
}
module.exports = { errorHandler };