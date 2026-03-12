class AppError extends Error { constructor(message, statusCode) { super(message); this.statusCode = statusCode; this.isOperational = true; } }
class AuthError extends AppError { constructor(m = 'Unauthorized') { super(m, 401); } }
class ForbiddenError extends AppError { constructor(m = 'Forbidden') { super(m, 403); } }
class ValidationError extends AppError { constructor(m = 'Invalid input') { super(m, 400); } }
class NotFoundError extends AppError { constructor(m = 'Not found') { super(m, 404); } }
class ConflictError extends AppError { constructor(m = 'Conflict') { super(m, 409); } }
module.exports = { AppError, AuthError, ForbiddenError, ValidationError, NotFoundError, ConflictError };