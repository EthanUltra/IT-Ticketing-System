# setup_ticketing.ps1
# Run from inside your "IT Ticketing System" folder.
# Creates every missing file with full content.

Write-Host "Setting up IT Ticketing System..." -ForegroundColor Cyan

# ── Create folder structure ────────────────────────────────────────────────────
$dirs = @(
  "backend\prisma",
  "backend\src\config",
  "backend\src\middleware",
  "backend\src\modules\auth",
  "backend\src\modules\tickets",
  "backend\src\modules\users",
  "backend\src\utils",
  "frontend\src\api",
  "frontend\src\components\ui",
  "frontend\src\pages",
  "frontend\src\store"
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
Write-Host "  Folders created" -ForegroundColor Green

# ── Helper to write file ───────────────────────────────────────────────────────
function Write-File($path, $content) {
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) $path), $content, [System.Text.Encoding]::UTF8)
}

# ══════════════════════════════════════════════════════════════════════════════
# BACKEND FILES
# ══════════════════════════════════════════════════════════════════════════════

Write-File "backend\.env" @"
PORT=4000
NODE_ENV=development
DATABASE_URL=postgresql://postgres:password@postgres:5432/it_ticketing
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_DB=it_ticketing
JWT_ACCESS_SECRET=dev_access_secret_replace_in_production
JWT_REFRESH_SECRET=dev_refresh_secret_replace_in_production
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
COOKIE_SECRET=dev_cookie_secret
FRONTEND_URL=http://localhost:5173
"@

Write-File "backend\package.json" @"
{
  "name": "it-ticketing-backend",
  "version": "1.0.0",
  "main": "src/server.js",
  "scripts": {
    "dev": "nodemon src/server.js",
    "start": "node src/server.js",
    "db:migrate": "npx prisma migrate dev",
    "db:generate": "npx prisma generate",
    "db:seed": "node prisma/seed.js",
    "db:studio": "npx prisma studio"
  },
  "dependencies": {
    "@prisma/client": "^5.10.0",
    "argon2": "^0.31.2",
    "cookie-parser": "^1.4.6",
    "cors": "^2.8.5",
    "dotenv": "^16.4.4",
    "express": "^4.18.2",
    "express-rate-limit": "^7.2.0",
    "helmet": "^7.1.0",
    "jsonwebtoken": "^9.0.2",
    "uuid": "^9.0.0",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "nodemon": "^3.1.0",
    "prisma": "^5.10.0"
  }
}
"@

Write-File "backend\Dockerfile" @"
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npx prisma generate
EXPOSE 4000
CMD ["npm", "run", "dev"]
"@

Write-File "backend\prisma\schema.prisma" @"
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String    @id @default(uuid())
  email        String    @unique
  name         String
  passwordHash String
  role         Role      @default(USER)
  isLocked     Boolean   @default(false)
  failedLogins Int       @default(0)
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt

  createdTickets  Ticket[]       @relation("CreatedBy")
  assignedTickets Ticket[]       @relation("AssignedTo")
  comments        Comment[]
  refreshTokens   RefreshToken[]
  auditLogs       AuditLog[]

  @@map("users")
}

model Ticket {
  id          String       @id @default(uuid())
  title       String
  description String
  status      TicketStatus @default(OPEN)
  priority    Priority     @default(MEDIUM)
  category    Category     @default(OTHER)

  createdById String
  createdBy   User     @relation("CreatedBy", fields: [createdById], references: [id])

  assignedToId String?
  assignedTo   User?   @relation("AssignedTo", fields: [assignedToId], references: [id])

  comments  Comment[]
  auditLogs AuditLog[]

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("tickets")
}

model Comment {
  id         String   @id @default(uuid())
  content    String
  ticketId   String
  ticket     Ticket   @relation(fields: [ticketId], references: [id], onDelete: Cascade)
  authorId   String
  author     User     @relation(fields: [authorId], references: [id])
  isInternal Boolean  @default(false)
  createdAt  DateTime @default(now())

  @@map("comments")
}

model AuditLog {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  ticketId  String?
  ticket    Ticket?  @relation(fields: [ticketId], references: [id])
  action    String
  changes   Json?
  createdAt DateTime @default(now())

  @@map("audit_logs")
}

model RefreshToken {
  id        String   @id @default(uuid())
  token     String   @unique
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  isRevoked Boolean  @default(false)
  expiresAt DateTime
  createdAt DateTime @default(now())

  @@map("refresh_tokens")
}

enum Role         { USER AGENT ADMIN }
enum TicketStatus { OPEN IN_PROGRESS RESOLVED CLOSED }
enum Priority     { LOW MEDIUM HIGH CRITICAL }
enum Category     { HARDWARE SOFTWARE NETWORK ACCESS OTHER }
"@

Write-File "backend\prisma\seed.js" @"
const { PrismaClient } = require('@prisma/client');
const argon2 = require('argon2');
const prisma = new PrismaClient();

async function main() {
  const hash = (p) => argon2.hash(p, { type: argon2.argon2id });

  const admin = await prisma.user.upsert({ where: { email: 'admin@company.com' }, update: {}, create: { email: 'admin@company.com', name: 'Admin User', passwordHash: await hash('Admin1234!'), role: 'ADMIN' } });
  const agent = await prisma.user.upsert({ where: { email: 'agent@company.com' }, update: {}, create: { email: 'agent@company.com', name: 'Support Agent', passwordHash: await hash('Agent1234!'), role: 'AGENT' } });
  const user  = await prisma.user.upsert({ where: { email: 'user@company.com'  }, update: {}, create: { email: 'user@company.com',  name: 'Regular User',  passwordHash: await hash('User1234!'),  role: 'USER'  } });

  const tickets = [
    { title: 'Laptop not connecting to VPN', description: 'Getting timeout errors when trying to connect to company VPN from home. Started after the Windows update yesterday.', status: 'OPEN', priority: 'HIGH', category: 'NETWORK', createdById: user.id },
    { title: 'Need access to Salesforce', description: 'Starting a new project with the sales team and require read access to Salesforce CRM.', status: 'IN_PROGRESS', priority: 'MEDIUM', category: 'ACCESS', createdById: user.id, assignedToId: agent.id },
    { title: 'Printer on 3rd floor offline', description: 'The HP LaserJet on the 3rd floor has been showing offline since Monday. Multiple users affected.', status: 'OPEN', priority: 'MEDIUM', category: 'HARDWARE', createdById: user.id },
    { title: 'Outlook keeps crashing on startup', description: 'Outlook crashes immediately on launch. Tried reinstalling but issue persists. Using Office 365.', status: 'RESOLVED', priority: 'HIGH', category: 'SOFTWARE', createdById: user.id, assignedToId: agent.id },
    { title: 'New employee setup - John Smith', description: 'New hire starting Monday. Need laptop provisioned, email set up, and access to internal tools.', status: 'OPEN', priority: 'CRITICAL', category: 'ACCESS', createdById: admin.id },
    { title: 'Monitor flickering at desk 42', description: 'Dell monitor has been flickering intermittently for the past week. Checked cable connections all secure.', status: 'IN_PROGRESS', priority: 'LOW', category: 'HARDWARE', createdById: user.id, assignedToId: agent.id },
    { title: 'Cannot access shared drive', description: 'Getting access denied when trying to open the Marketing shared drive. Other team members can access it fine.', status: 'CLOSED', priority: 'MEDIUM', category: 'ACCESS', createdById: user.id },
  ];
  for (const t of tickets) { await prisma.ticket.create({ data: t }); }

  console.log('Seed complete');
  console.log('  admin@company.com / Admin1234!');
  console.log('  agent@company.com / Agent1234!');
  console.log('  user@company.com  / User1234!');
}
main().catch(console.error).finally(() => prisma.$disconnect());
"@

Write-File "backend\src\config\env.js" @"
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
"@

Write-File "backend\src\config\prisma.js" @"
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient({ log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'] });
module.exports = prisma;
"@

Write-File "backend\src\utils\errors.js" @"
class AppError extends Error { constructor(message, statusCode) { super(message); this.statusCode = statusCode; this.isOperational = true; } }
class AuthError extends AppError { constructor(m = 'Unauthorized') { super(m, 401); } }
class ForbiddenError extends AppError { constructor(m = 'Forbidden') { super(m, 403); } }
class ValidationError extends AppError { constructor(m = 'Invalid input') { super(m, 400); } }
class NotFoundError extends AppError { constructor(m = 'Not found') { super(m, 404); } }
class ConflictError extends AppError { constructor(m = 'Conflict') { super(m, 409); } }
module.exports = { AppError, AuthError, ForbiddenError, ValidationError, NotFoundError, ConflictError };
"@

Write-File "backend\src\utils\tokens.js" @"
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const env = require('../config/env');
function signAccessToken(payload) { return jwt.sign(payload, env.jwt.accessSecret, { expiresIn: env.jwt.accessExpiresIn }); }
function signRefreshToken(payload) { const jti = uuidv4(); return { token: jwt.sign({ ...payload, jti }, env.jwt.refreshSecret, { expiresIn: env.jwt.refreshExpiresIn }), jti }; }
function verifyAccessToken(token) { return jwt.verify(token, env.jwt.accessSecret); }
function verifyRefreshToken(token) { return jwt.verify(token, env.jwt.refreshSecret); }
function expiresAt(duration) { const units = { m: 60, h: 3600, d: 86400 }; const [, amount, unit] = duration.match(/^(\d+)([mhd])$/); return new Date(Date.now() + parseInt(amount) * units[unit] * 1000); }
module.exports = { signAccessToken, signRefreshToken, verifyAccessToken, verifyRefreshToken, expiresAt };
"@

Write-File "backend\src\middleware\authenticate.js" @"
const { verifyAccessToken } = require('../utils/tokens');
const { AuthError } = require('../utils/errors');
function authenticate(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) return next(new AuthError('No token provided'));
  try { const decoded = verifyAccessToken(header.split(' ')[1]); req.user = { id: decoded.userId, role: decoded.role, name: decoded.name }; next(); }
  catch (err) { next(new AuthError(err.name === 'TokenExpiredError' ? 'Token expired' : 'Invalid token')); }
}
module.exports = { authenticate };
"@

Write-File "backend\src\middleware\authorize.js" @"
const { ForbiddenError } = require('../utils/errors');
const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user?.role)) return next(new ForbiddenError('Insufficient permissions'));
  next();
};
module.exports = { authorize };
"@

Write-File "backend\src\middleware\errorHandler.js" @"
const { AppError } = require('../utils/errors');
function errorHandler(err, req, res, next) {
  if (err.name === 'ZodError') return res.status(400).json({ status: 'error', message: 'Validation failed', errors: err.errors.map(e => ({ field: e.path.join('.'), message: e.message })) });
  if (err instanceof AppError) return res.status(err.statusCode).json({ status: 'error', message: err.message });
  console.error(err);
  res.status(500).json({ status: 'error', message: process.env.NODE_ENV === 'production' ? 'Internal server error' : err.message });
}
module.exports = { errorHandler };
"@

Write-File "backend\src\app.js" @"
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const env = require('./config/env');
const { errorHandler } = require('./middleware/errorHandler');
const app = express();
app.use(helmet());
app.use(cors({ origin: env.frontendUrl, credentials: true }));
app.use(express.json({ limit: '10kb' }));
app.use(cookieParser(env.cookie.secret));
app.use('/api/auth', require('./modules/auth/auth.routes'));
app.use('/api/tickets', require('./modules/tickets/tickets.routes'));
app.use('/api/users', require('./modules/users/users.routes'));
app.get('/api/health', (_, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));
app.use((_, res) => res.status(404).json({ status: 'error', message: 'Not found' }));
app.use(errorHandler);
module.exports = app;
"@

Write-File "backend\src\server.js" @"
const app = require('./app');
const env = require('./config/env');
const prisma = require('./config/prisma');
const server = app.listen(env.port, () => console.log('API running on port ' + env.port));
const shutdown = async (sig) => { console.log(sig + ' shutting down'); server.close(async () => { await prisma.$disconnect(); process.exit(0); }); };
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
"@

Write-File "backend\src\modules\auth\auth.service.js" @"
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
  const dummy = '$argon2id$v=19$m=65536,t=3,p=4$placeholder';
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
"@

Write-File "backend\src\modules\auth\auth.controller.js" @"
const { z } = require('zod');
const authService = require('./auth.service');
const env = require('../../config/env');
const cookieOpts = { httpOnly: true, secure: env.isProd, sameSite: 'strict', maxAge: 7 * 24 * 60 * 60 * 1000, path: '/api/auth/refresh' };
const registerSchema = z.object({ email: z.string().email(), name: z.string().min(2), password: z.string().min(8) });
const loginSchema = z.object({ email: z.string().email(), password: z.string().min(1) });

exports.register = async (req, res, next) => { try { const body = registerSchema.parse(req.body); const user = await authService.register(body); res.status(201).json({ status: 'success', data: { user } }); } catch (e) { next(e); } };
exports.login    = async (req, res, next) => { try { const body = loginSchema.parse(req.body); const { accessToken, refreshToken, user } = await authService.login(body); res.cookie('refreshToken', refreshToken, cookieOpts); res.json({ status: 'success', data: { accessToken, user } }); } catch (e) { next(e); } };
exports.refresh  = async (req, res, next) => { try { const token = req.cookies?.refreshToken; if (!token) return res.status(401).json({ status: 'error', message: 'No refresh token' }); const { accessToken, refreshToken, user } = await authService.refresh(token); res.cookie('refreshToken', refreshToken, cookieOpts); res.json({ status: 'success', data: { accessToken, user } }); } catch (e) { next(e); } };
exports.logout   = async (req, res, next) => { try { await authService.logout(req.cookies?.refreshToken); res.clearCookie('refreshToken', { path: '/api/auth/refresh' }); res.json({ status: 'success', message: 'Logged out' }); } catch (e) { next(e); } };
exports.me = (req, res) => res.json({ status: 'success', data: { user: req.user } });
"@

Write-File "backend\src\modules\auth\auth.routes.js" @"
const { Router } = require('express');
const c = require('./auth.controller');
const { authenticate } = require('../../middleware/authenticate');
const rateLimit = require('express-rate-limit');
const loginLimit = rateLimit({ windowMs: 15 * 60 * 1000, max: 10 });
const router = Router();
router.post('/register', c.register);
router.post('/login', loginLimit, c.login);
router.post('/refresh', c.refresh);
router.post('/logout', c.logout);
router.get('/me', authenticate, c.me);
module.exports = router;
"@

Write-File "backend\src\modules\tickets\tickets.service.js" @"
const prisma = require('../../config/prisma');
const { NotFoundError, ForbiddenError } = require('../../utils/errors');

const INCLUDE = { createdBy: { select: { id:true,name:true,email:true,role:true } }, assignedTo: { select: { id:true,name:true,email:true,role:true } }, comments: { orderBy: { createdAt: 'asc' }, include: { author: { select: { id:true,name:true,role:true } } } }, _count: { select: { comments: true } } };

async function listTickets({ userId, role, status, priority, category, page=1, limit=20 }) {
  const where = {};
  if (role === 'USER') where.createdById = userId;
  if (status) where.status = status;
  if (priority) where.priority = priority;
  if (category) where.category = category;
  const [tickets, total] = await Promise.all([
    prisma.ticket.findMany({ where, include: { createdBy: { select: {id:true,name:true,email:true} }, assignedTo: { select: {id:true,name:true} }, _count: { select: { comments:true } } }, orderBy: [{ priority:'desc' },{ createdAt:'desc' }], skip: (page-1)*limit, take: +limit }),
    prisma.ticket.count({ where })
  ]);
  return { tickets, total, page, pages: Math.ceil(total/limit) };
}

async function getTicket({ ticketId, userId, role }) {
  const ticket = await prisma.ticket.findUnique({ where: { id: ticketId }, include: INCLUDE });
  if (!ticket) throw new NotFoundError('Ticket not found');
  if (role === 'USER' && ticket.createdById !== userId) throw new ForbiddenError('Access denied');
  if (role === 'USER') ticket.comments = ticket.comments.filter(c => !c.isInternal);
  return ticket;
}

async function createTicket({ userId, data }) {
  const ticket = await prisma.ticket.create({ data: { ...data, createdById: userId }, include: INCLUDE });
  await audit(userId, ticket.id, 'TICKET_CREATED', { title: ticket.title });
  return ticket;
}

async function updateTicket({ ticketId, userId, role, data }) {
  if (!await prisma.ticket.findUnique({ where: { id: ticketId } })) throw new NotFoundError('Ticket not found');
  if (role === 'USER') throw new ForbiddenError('Users cannot update tickets');
  const updated = await prisma.ticket.update({ where: { id: ticketId }, data, include: INCLUDE });
  await audit(userId, ticketId, 'TICKET_UPDATED', data);
  return updated;
}

async function deleteTicket({ ticketId, userId, role }) {
  if (!await prisma.ticket.findUnique({ where: { id: ticketId } })) throw new NotFoundError('Ticket not found');
  if (role !== 'ADMIN') throw new ForbiddenError('Only admins can delete tickets');
  await prisma.ticket.delete({ where: { id: ticketId } });
}

async function addComment({ ticketId, userId, role, content, isInternal }) {
  const ticket = await prisma.ticket.findUnique({ where: { id: ticketId } });
  if (!ticket) throw new NotFoundError('Ticket not found');
  if (role === 'USER' && ticket.createdById !== userId) throw new ForbiddenError('Access denied');
  const comment = await prisma.comment.create({ data: { content, ticketId, authorId: userId, isInternal: Boolean(isInternal) && role !== 'USER' }, include: { author: { select: {id:true,name:true,role:true} } } });
  return comment;
}

async function getStats() {
  const [byStatus, byPriority, recentTickets] = await Promise.all([
    prisma.ticket.groupBy({ by: ['status'], _count: true }),
    prisma.ticket.groupBy({ by: ['priority'], _count: true }),
    prisma.ticket.findMany({ orderBy: { createdAt: 'desc' }, take: 5, include: { createdBy: { select: { name:true } } } }),
  ]);
  return { byStatus, byPriority, recentTickets };
}

async function audit(userId, ticketId, action, changes) { await prisma.auditLog.create({ data: { userId, ticketId, action, changes } }).catch(()=>{}); }

module.exports = { listTickets, getTicket, createTicket, updateTicket, deleteTicket, addComment, getStats };
"@

Write-File "backend\src\modules\tickets\tickets.controller.js" @"
const { z } = require('zod');
const svc = require('./tickets.service');

const createSchema = z.object({ title: z.string().min(5).max(120), description: z.string().min(10), priority: z.enum(['LOW','MEDIUM','HIGH','CRITICAL']).optional(), category: z.enum(['HARDWARE','SOFTWARE','NETWORK','ACCESS','OTHER']).optional() });
const updateSchema = z.object({ title: z.string().min(5).max(120).optional(), description: z.string().min(10).optional(), status: z.enum(['OPEN','IN_PROGRESS','RESOLVED','CLOSED']).optional(), priority: z.enum(['LOW','MEDIUM','HIGH','CRITICAL']).optional(), category: z.enum(['HARDWARE','SOFTWARE','NETWORK','ACCESS','OTHER']).optional(), assignedToId: z.string().uuid().nullable().optional() });
const commentSchema = z.object({ content: z.string().min(1).max(2000), isInternal: z.boolean().optional() });

exports.list       = async (req,res,next) => { try { res.json({ status:'success', data: await svc.listTickets({ userId:req.user.id, role:req.user.role, ...req.query }) }); } catch(e){next(e);} };
exports.get        = async (req,res,next) => { try { res.json({ status:'success', data: { ticket: await svc.getTicket({ ticketId:req.params.id, userId:req.user.id, role:req.user.role }) } }); } catch(e){next(e);} };
exports.create     = async (req,res,next) => { try { const data = createSchema.parse(req.body); res.status(201).json({ status:'success', data: { ticket: await svc.createTicket({ userId:req.user.id, data }) } }); } catch(e){next(e);} };
exports.update     = async (req,res,next) => { try { const data = updateSchema.parse(req.body); res.json({ status:'success', data: { ticket: await svc.updateTicket({ ticketId:req.params.id, userId:req.user.id, role:req.user.role, data }) } }); } catch(e){next(e);} };
exports.remove     = async (req,res,next) => { try { await svc.deleteTicket({ ticketId:req.params.id, userId:req.user.id, role:req.user.role }); res.json({ status:'success', message:'Ticket deleted' }); } catch(e){next(e);} };
exports.addComment = async (req,res,next) => { try { const { content, isInternal } = commentSchema.parse(req.body); res.status(201).json({ status:'success', data: { comment: await svc.addComment({ ticketId:req.params.id, userId:req.user.id, role:req.user.role, content, isInternal }) } }); } catch(e){next(e);} };
exports.stats      = async (req,res,next) => { try { res.json({ status:'success', data: await svc.getStats() }); } catch(e){next(e);} };
"@

Write-File "backend\src\modules\tickets\tickets.routes.js" @"
const { Router } = require('express');
const c = require('./tickets.controller');
const { authenticate } = require('../../middleware/authenticate');
const { authorize } = require('../../middleware/authorize');
const router = Router();
router.use(authenticate);
router.get('/stats', authorize('ADMIN','AGENT'), c.stats);
router.get('/', c.list);
router.post('/', c.create);
router.get('/:id', c.get);
router.patch('/:id', authorize('ADMIN','AGENT'), c.update);
router.delete('/:id', authorize('ADMIN'), c.remove);
router.post('/:id/comments', c.addComment);
module.exports = router;
"@

Write-File "backend\src\modules\users\users.service.js" @"
const prisma = require('../../config/prisma');
const { NotFoundError } = require('../../utils/errors');
async function listUsers() { return prisma.user.findMany({ select: { id:true,name:true,email:true,role:true,createdAt:true,isLocked:true }, orderBy: { createdAt:'desc' } }); }
async function updateRole({ userId, role }) { if (!await prisma.user.findUnique({ where:{id:userId} })) throw new NotFoundError(); return prisma.user.update({ where:{id:userId}, data:{role}, select:{id:true,name:true,email:true,role:true} }); }
async function unlockUser({ userId }) { if (!await prisma.user.findUnique({ where:{id:userId} })) throw new NotFoundError(); return prisma.user.update({ where:{id:userId}, data:{isLocked:false,failedLogins:0}, select:{id:true,name:true,email:true,isLocked:true} }); }
module.exports = { listUsers, updateRole, unlockUser };
"@

Write-File "backend\src\modules\users\users.routes.js" @"
const { z } = require('zod');
const svc = require('./users.service');
const { Router } = require('express');
const { authenticate } = require('../../middleware/authenticate');
const { authorize } = require('../../middleware/authorize');

const list       = async (req,res,next) => { try { res.json({ status:'success', data:{ users: await svc.listUsers() } }); } catch(e){next(e);} };
const updateRole = async (req,res,next) => { try { const { role } = z.object({ role: z.enum(['USER','AGENT','ADMIN']) }).parse(req.body); res.json({ status:'success', data:{ user: await svc.updateRole({ userId:req.params.id, role }) } }); } catch(e){next(e);} };
const unlock     = async (req,res,next) => { try { res.json({ status:'success', data:{ user: await svc.unlockUser({ userId:req.params.id }) } }); } catch(e){next(e);} };

const router = Router();
router.use(authenticate, authorize('ADMIN','AGENT'));
router.get('/', list);
router.patch('/:id/role', authorize('ADMIN'), updateRole);
router.patch('/:id/unlock', authorize('ADMIN'), unlock);
module.exports = router;
"@

Write-Host "  Backend files created" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
# FRONTEND FILES
# ══════════════════════════════════════════════════════════════════════════════

Write-File "frontend\Dockerfile" @"
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host"]
"@

Write-File "frontend\package.json" @"
{
  "name": "it-ticketing-frontend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios": "^1.6.7",
    "date-fns": "^3.3.1",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.22.2",
    "zustand": "^4.5.1"
  },
  "devDependencies": {
    "@tailwindcss/forms": "^0.5.7",
    "@vitejs/plugin-react": "^4.2.1",
    "autoprefixer": "^10.4.17",
    "postcss": "^8.4.35",
    "tailwindcss": "^3.4.1",
    "vite": "^5.1.3"
  }
}
"@

Write-File "frontend\vite.config.js" @"
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, host: true, proxy: { '/api': { target: 'http://backend:4000', changeOrigin: true } } },
});
"@

Write-File "frontend\tailwind.config.js" @"
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: { extend: { fontFamily: { sans: ['"DM Sans"', 'sans-serif'], mono: ['"JetBrains Mono"', 'monospace'] }, colors: { surface: { 50:'#f4f4f5',100:'#e4e4e7',800:'#18181b',900:'#0f0f11',950:'#09090b' }, accent: { DEFAULT:'#f97316', dark:'#ea580c' } } } },
  plugins: [],
};
"@

Write-File "frontend\postcss.config.js" @"
export default { plugins: { tailwindcss: {}, autoprefixer: {} } };
"@

Write-File "frontend\index.html" @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>IT Help Desk</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet" />
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.jsx"></script>
</body>
</html>
"@

Write-File "frontend\src\index.css" @"
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base { body { @apply bg-surface-950 text-surface-50 font-sans antialiased; } }
@layer components {
  .btn-primary { @apply bg-accent hover:bg-accent-dark text-white font-medium px-4 py-2 rounded-lg transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed; }
  .btn-ghost   { @apply text-surface-100 hover:bg-surface-800 font-medium px-4 py-2 rounded-lg transition-colors text-sm; }
  .card        { @apply bg-surface-900 border border-surface-800 rounded-xl; }
  .input       { @apply bg-surface-800 border border-surface-800 text-surface-50 rounded-lg px-3 py-2 text-sm w-full focus:outline-none focus:border-accent focus:ring-1 focus:ring-accent placeholder:text-surface-100/40; }
  .label       { @apply block text-xs font-medium text-surface-100/60 mb-1.5 uppercase tracking-wider; }
}
@keyframes fadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }
.animate-fade-in { animation: fadeIn 0.2s ease-out forwards; }
"@

Write-File "frontend\src\main.jsx" @"
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';
ReactDOM.createRoot(document.getElementById('root')).render(<React.StrictMode><App /></React.StrictMode>);
"@

Write-File "frontend\src\store\authStore.js" @"
import { create } from 'zustand';
import api from '../api/client';
export const useAuthStore = create((set, get) => ({
  user: null, accessToken: null, loading: true,
  setAuth: (user, accessToken) => set({ user, accessToken }),
  logout: async () => { await api.post('/auth/logout').catch(() => {}); set({ user: null, accessToken: null }); },
  refresh: async () => { try { const { data } = await api.post('/auth/refresh'); set({ user: data.data.user, accessToken: data.data.accessToken, loading: false }); return data.data.accessToken; } catch { set({ user: null, accessToken: null, loading: false }); return null; } },
  init: async () => { await get().refresh(); },
}));
"@

Write-File "frontend\src\api\client.js" @"
import axios from 'axios';
const api = axios.create({ baseURL: '/api', withCredentials: true });
api.interceptors.request.use((config) => {
  try { const { useAuthStore } = require('./authStore'); const token = useAuthStore.getState().accessToken; if (token) config.headers.Authorization = 'Bearer ' + token; } catch {}
  return config;
});
let isRefreshing = false, queue = [];
api.interceptors.response.use((res) => res, async (err) => {
  const original = err.config;
  if (err.response?.status === 401 && !original._retry) {
    if (isRefreshing) return new Promise((resolve, reject) => queue.push({ resolve, reject })).then(token => { original.headers.Authorization = 'Bearer ' + token; return api(original); });
    original._retry = true; isRefreshing = true;
    try { const { useAuthStore } = await import('../store/authStore'); const token = await useAuthStore.getState().refresh(); if (!token) throw new Error(); queue.forEach(({ resolve }) => resolve(token)); queue = []; original.headers.Authorization = 'Bearer ' + token; return api(original); }
    catch { queue.forEach(({ reject }) => reject(err)); queue = []; window.location.href = '/login'; }
    finally { isRefreshing = false; }
  }
  return Promise.reject(err);
});
export default api;
"@

Write-File "frontend\src\api\tickets.js" @"
import api from './client';
export const ticketsApi = {
  list: (params) => api.get('/tickets', { params }),
  get: (id) => api.get('/tickets/' + id),
  create: (data) => api.post('/tickets', data),
  update: (id, data) => api.patch('/tickets/' + id, data),
  delete: (id) => api.delete('/tickets/' + id),
  addComment: (id, data) => api.post('/tickets/' + id + '/comments', data),
  stats: () => api.get('/tickets/stats'),
};
export const usersApi = {
  list: () => api.get('/users'),
  updateRole: (id, role) => api.patch('/users/' + id + '/role', { role }),
  unlock: (id) => api.patch('/users/' + id + '/unlock'),
};
"@

Write-File "frontend\src\components\ui\Badge.jsx" @"
const STATUS_STYLES   = { OPEN:'bg-blue-500/10 text-blue-400 border-blue-500/20', IN_PROGRESS:'bg-amber-500/10 text-amber-400 border-amber-500/20', RESOLVED:'bg-emerald-500/10 text-emerald-400 border-emerald-500/20', CLOSED:'bg-zinc-500/10 text-zinc-400 border-zinc-500/20' };
const PRIORITY_STYLES = { LOW:'bg-zinc-500/10 text-zinc-400 border-zinc-500/20', MEDIUM:'bg-sky-500/10 text-sky-400 border-sky-500/20', HIGH:'bg-orange-500/10 text-orange-400 border-orange-500/20', CRITICAL:'bg-red-500/10 text-red-400 border-red-500/20' };
const ROLE_STYLES     = { ADMIN:'bg-purple-500/10 text-purple-400 border-purple-500/20', AGENT:'bg-teal-500/10 text-teal-400 border-teal-500/20', USER:'bg-zinc-500/10 text-zinc-400 border-zinc-500/20' };

export const StatusBadge   = ({ status })   => <span className={'inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium border font-mono ' + (STATUS_STYLES[status]   || STATUS_STYLES.OPEN)}>{status?.replace('_',' ')}</span>;
export const PriorityBadge = ({ priority }) => <span className={'inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs font-medium border font-mono ' + (PRIORITY_STYLES[priority] || PRIORITY_STYLES.MEDIUM)}>● {priority}</span>;
export const RoleBadge     = ({ role })     => <span className={'inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium border font-mono ' + (ROLE_STYLES[role]     || ROLE_STYLES.USER)}>{role}</span>;
export const Spinner = ({ size='md' }) => { const s = { sm:'w-4 h-4', md:'w-6 h-6', lg:'w-10 h-10' }; return <div className={s[size] + ' border-2 border-surface-700 border-t-accent rounded-full animate-spin'} />; };
export const EmptyState = ({ icon, title, description, action }) => <div className="flex flex-col items-center justify-center py-16 text-center"><div className="text-4xl mb-4 opacity-40">{icon}</div><h3 className="text-surface-50 font-medium mb-1">{title}</h3><p className="text-surface-100/50 text-sm mb-6">{description}</p>{action}</div>;
"@

Write-File "frontend\src\components\Layout.jsx" @"
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';
const NAV = [
  { to:'/dashboard', label:'Dashboard',  icon:'⬡', roles:['USER','AGENT','ADMIN'] },
  { to:'/tickets',   label:'Tickets',    icon:'⊡', roles:['USER','AGENT','ADMIN'] },
  { to:'/new',       label:'New Ticket', icon:'+', roles:['USER','AGENT','ADMIN'] },
  { to:'/users',     label:'Users',      icon:'⊕', roles:['AGENT','ADMIN'] },
];
export default function Layout({ children }) {
  const { user, logout } = useAuthStore();
  const navigate = useNavigate();
  const handleLogout = async () => { await logout(); navigate('/login'); };
  const links = NAV.filter(n => n.roles.includes(user?.role));
  return (
    <div className="flex min-h-screen">
      <aside className="w-56 flex-shrink-0 bg-surface-900 border-r border-surface-800 flex flex-col">
        <div className="px-5 py-5 border-b border-surface-800">
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 bg-accent rounded-lg flex items-center justify-center text-white text-sm font-bold">H</div>
            <div><p className="text-sm font-semibold text-surface-50 leading-none">HelpDesk</p><p className="text-xs text-surface-100/40 font-mono mt-0.5">IT SYSTEM</p></div>
          </div>
        </div>
        <nav className="flex-1 px-3 py-4 space-y-1">
          {links.map(({ to, label, icon }) => (
            <NavLink key={to} to={to} className={({ isActive }) => 'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ' + (isActive ? 'bg-accent/10 text-accent font-medium' : 'text-surface-100/60 hover:text-surface-50 hover:bg-surface-800')}>
              <span className="font-mono text-base w-5 text-center">{icon}</span>{label}
            </NavLink>
          ))}
        </nav>
        <div className="px-3 py-4 border-t border-surface-800">
          <div className="px-3 py-2.5 rounded-lg bg-surface-800/50 mb-2">
            <p className="text-xs font-medium text-surface-50 truncate">{user?.name}</p>
            <p className="text-xs text-surface-100/40 font-mono truncate">{user?.role}</p>
          </div>
          <button onClick={handleLogout} className="btn-ghost w-full text-left text-surface-100/50 hover:text-red-400 text-xs">Sign out →</button>
        </div>
      </aside>
      <main className="flex-1 overflow-auto">{children}</main>
    </div>
  );
}
"@

Write-File "frontend\src\App.jsx" @"
import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './store/authStore';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import TicketsPage from './pages/TicketsPage';
import TicketDetailPage from './pages/TicketDetailPage';
import CreateTicketPage from './pages/CreateTicketPage';
import UsersPage from './pages/UsersPage';
import { Spinner } from './components/ui/Badge';

function PrivateRoute({ children, roles }) {
  const { user } = useAuthStore();
  if (!user) return <Navigate to="/login" replace />;
  if (roles && !roles.includes(user.role)) return <Navigate to="/dashboard" replace />;
  return <Layout>{children}</Layout>;
}

export default function App() {
  const { init, loading } = useAuthStore();
  useEffect(() => { init(); }, []);
  if (loading) return <div className="min-h-screen bg-surface-950 flex items-center justify-center"><Spinner size="lg" /></div>;
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<PrivateRoute><DashboardPage /></PrivateRoute>} />
        <Route path="/tickets"   element={<PrivateRoute><TicketsPage /></PrivateRoute>} />
        <Route path="/tickets/:id" element={<PrivateRoute><TicketDetailPage /></PrivateRoute>} />
        <Route path="/new"       element={<PrivateRoute><CreateTicketPage /></PrivateRoute>} />
        <Route path="/users"     element={<PrivateRoute roles={['AGENT','ADMIN']}><UsersPage /></PrivateRoute>} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
"@

Write-File "frontend\src\pages\LoginPage.jsx" @"
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api/client';
import { useAuthStore } from '../store/authStore';
import { Spinner } from '../components/ui/Badge';

export default function LoginPage() {
  const [form, setForm] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { setAuth } = useAuthStore();
  const navigate = useNavigate();

  const handle = async (e) => {
    e.preventDefault(); setLoading(true); setError('');
    try { const { data } = await api.post('/auth/login', form); setAuth(data.data.user, data.data.accessToken); navigate('/dashboard'); }
    catch (err) { setError(err.response?.data?.message || 'Login failed'); }
    finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen bg-surface-950 flex items-center justify-center px-4">
      <div className="absolute inset-0 bg-[linear-gradient(rgba(249,115,22,0.03)_1px,transparent_1px),linear-gradient(90deg,rgba(249,115,22,0.03)_1px,transparent_1px)] bg-[size:60px_60px]" />
      <div className="relative w-full max-w-sm animate-fade-in">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-12 h-12 bg-accent rounded-xl mb-4"><span className="text-white text-xl font-bold">H</span></div>
          <h1 className="text-2xl font-semibold text-surface-50">IT Help Desk</h1>
          <p className="text-surface-100/50 text-sm mt-1">Sign in to your account</p>
        </div>
        <div className="card p-3 mb-4 text-xs font-mono text-surface-100/40 space-y-1">
          <p className="text-surface-100/60 font-sans font-medium text-xs mb-2">Demo accounts</p>
          <p>admin@company.com / Admin1234!</p>
          <p>agent@company.com / Agent1234!</p>
          <p>user@company.com  / User1234!</p>
        </div>
        <div className="card p-6">
          <form onSubmit={handle} className="space-y-4">
            <div><label className="label">Email</label><input className="input" type="email" placeholder="you@company.com" required value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} /></div>
            <div><label className="label">Password</label><input className="input" type="password" placeholder="••••••••" required value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} /></div>
            {error && <div className="bg-red-500/10 border border-red-500/20 text-red-400 text-sm px-3 py-2 rounded-lg">{error}</div>}
            <button type="submit" className="btn-primary w-full flex items-center justify-center gap-2" disabled={loading}>{loading && <Spinner size="sm" />}{loading ? 'Signing in...' : 'Sign in'}</button>
          </form>
        </div>
      </div>
    </div>
  );
}
"@

Write-File "frontend\src\pages\DashboardPage.jsx" @"
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ticketsApi } from '../api/tickets';
import { useAuthStore } from '../store/authStore';
import { StatusBadge, PriorityBadge, Spinner } from '../components/ui/Badge';
import { formatDistanceToNow } from 'date-fns';

export default function DashboardPage() {
  const { user } = useAuthStore();
  const [stats, setStats] = useState(null);
  const [recent, setRecent] = useState([]);
  const [loading, setLoading] = useState(true);
  const isAgent = user?.role !== 'USER';

  useEffect(() => {
    (async () => {
      try {
        if (isAgent) { const { data } = await ticketsApi.stats(); setStats(data.data.byStatus); setRecent(data.data.recentTickets); }
        else { const { data } = await ticketsApi.list({ limit: 5 }); setRecent(data.data.tickets); }
      } catch(e) { console.error(e); } finally { setLoading(false); }
    })();
  }, []);

  if (loading) return <div className="flex items-center justify-center h-64"><Spinner size="lg" /></div>;

  const statMap = {};
  if (stats) stats.forEach(s => { statMap[s.status] = s._count; });
  const h = new Date().getHours();
  const greet = h < 12 ? 'morning' : h < 17 ? 'afternoon' : 'evening';

  return (
    <div className="p-8 animate-fade-in">
      <div className="mb-8">
        <h1 className="text-2xl font-semibold text-surface-50">Good {greet}, {user?.name?.split(' ')[0]}</h1>
        <p className="text-surface-100/50 text-sm mt-1">{new Date().toLocaleDateString('en-GB', { weekday:'long', day:'numeric', month:'long' })}</p>
      </div>
      {isAgent && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          {['OPEN','IN_PROGRESS','RESOLVED','CLOSED'].map(s => (
            <div key={s} className="card p-5">
              <p className="text-xs font-mono text-surface-100/40 uppercase tracking-wider mb-2">{s.replace('_',' ')}</p>
              <p className={'text-3xl font-semibold ' + {OPEN:'text-blue-400',IN_PROGRESS:'text-amber-400',RESOLVED:'text-emerald-400',CLOSED:'text-zinc-400'}[s]}>{statMap[s] ?? 0}</p>
            </div>
          ))}
        </div>
      )}
      <div className="card">
        <div className="flex items-center justify-between px-6 py-4 border-b border-surface-800">
          <h2 className="text-sm font-medium text-surface-50">{isAgent ? 'Recent Tickets' : 'Your Tickets'}</h2>
          <Link to="/tickets" className="text-xs text-accent hover:underline">View all →</Link>
        </div>
        {recent.length === 0 ? <div className="px-6 py-10 text-center text-surface-100/40 text-sm">No tickets yet.</div> : (
          <div className="divide-y divide-surface-800">
            {recent.map(t => (
              <Link key={t.id} to={'/tickets/' + t.id} className="flex items-center gap-4 px-6 py-4 hover:bg-surface-800/40 transition-colors">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-surface-50 truncate">{t.title}</p>
                  <p className="text-xs text-surface-100/40 mt-0.5 font-mono">#{t.id.slice(0,8)} · {formatDistanceToNow(new Date(t.createdAt), { addSuffix:true })}</p>
                </div>
                <div className="flex items-center gap-2 flex-shrink-0"><PriorityBadge priority={t.priority} /><StatusBadge status={t.status} /></div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
"@

Write-File "frontend\src\pages\TicketsPage.jsx" @"
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ticketsApi } from '../api/tickets';
import { useAuthStore } from '../store/authStore';
import { StatusBadge, PriorityBadge, Spinner, EmptyState } from '../components/ui/Badge';
import { formatDistanceToNow } from 'date-fns';

export default function TicketsPage() {
  const { user } = useAuthStore();
  const [tickets, setTickets] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({ status:'', priority:'', category:'' });
  const isAgent = user?.role !== 'USER';

  useEffect(() => {
    setLoading(true);
    const params = Object.fromEntries(Object.entries(filters).filter(([,v]) => v));
    ticketsApi.list(params).then(({ data }) => { setTickets(data.data.tickets); setTotal(data.data.total); }).catch(console.error).finally(() => setLoading(false));
  }, [filters]);

  return (
    <div className="p-8 animate-fade-in">
      <div className="flex items-center justify-between mb-6">
        <div><h1 className="text-2xl font-semibold text-surface-50">Tickets</h1><p className="text-surface-100/50 text-sm mt-0.5">{loading ? '—' : total + ' ticket' + (total !== 1 ? 's' : '')}</p></div>
        <Link to="/new" className="btn-primary">+ New Ticket</Link>
      </div>
      <div className="flex gap-3 mb-6 flex-wrap">
        {[['status',['OPEN','IN_PROGRESS','RESOLVED','CLOSED']],['priority',['CRITICAL','HIGH','MEDIUM','LOW']],['category',['HARDWARE','SOFTWARE','NETWORK','ACCESS','OTHER']]].map(([key,opts]) => (
          <select key={key} value={filters[key]} onChange={e => setFilters(f => ({...f,[key]:e.target.value}))} className="input !w-auto text-xs font-mono">
            <option value="">{key.charAt(0).toUpperCase()+key.slice(1)}</option>
            {opts.map(o => <option key={o} value={o}>{o.replace('_',' ')}</option>)}
          </select>
        ))}
        {Object.values(filters).some(Boolean) && <button onClick={() => setFilters({status:'',priority:'',category:''})} className="btn-ghost text-xs text-surface-100/40">Clear</button>}
      </div>
      <div className="card overflow-hidden">
        {loading ? <div className="flex justify-center py-16"><Spinner size="lg" /></div>
        : tickets.length === 0 ? <EmptyState icon="⊡" title="No tickets found" description="Try adjusting your filters." action={<Link to="/new" className="btn-primary">Create a ticket</Link>} />
        : <table className="w-full text-sm">
            <thead><tr className="border-b border-surface-800 text-xs font-mono text-surface-100/40 uppercase tracking-wider">
              <th className="text-left px-6 py-3 font-medium">Ticket</th>
              <th className="text-left px-4 py-3 font-medium">Category</th>
              <th className="text-left px-4 py-3 font-medium">Priority</th>
              <th className="text-left px-4 py-3 font-medium">Status</th>
              {isAgent && <th className="text-left px-4 py-3 font-medium">Assigned</th>}
              <th className="text-left px-4 py-3 font-medium">Created</th>
            </tr></thead>
            <tbody className="divide-y divide-surface-800">
              {tickets.map(t => (
                <tr key={t.id} className="hover:bg-surface-800/30 transition-colors">
                  <td className="px-6 py-4"><Link to={'/tickets/'+t.id} className="hover:text-accent transition-colors"><p className="font-medium text-surface-50 truncate max-w-xs">{t.title}</p><p className="text-xs text-surface-100/40 font-mono mt-0.5">#{t.id.slice(0,8)}</p></Link></td>
                  <td className="px-4 py-4"><span className="text-xs font-mono text-surface-100/50">{t.category}</span></td>
                  <td className="px-4 py-4"><PriorityBadge priority={t.priority} /></td>
                  <td className="px-4 py-4"><StatusBadge status={t.status} /></td>
                  {isAgent && <td className="px-4 py-4"><span className="text-xs text-surface-100/50">{t.assignedTo?.name ?? '—'}</span></td>}
                  <td className="px-4 py-4 text-xs text-surface-100/40 font-mono">{formatDistanceToNow(new Date(t.createdAt), { addSuffix:true })}</td>
                </tr>
              ))}
            </tbody>
          </table>}
      </div>
    </div>
  );
}
"@

Write-File "frontend\src\pages\CreateTicketPage.jsx" @"
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ticketsApi } from '../api/tickets';
import { Spinner } from '../components/ui/Badge';

export default function CreateTicketPage() {
  const navigate = useNavigate();
  const [form, setForm] = useState({ title:'', description:'', priority:'MEDIUM', category:'OTHER' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const set = (k,v) => setForm(f => ({...f,[k]:v}));
  const submit = async (e) => {
    e.preventDefault(); setLoading(true); setError('');
    try { const { data } = await ticketsApi.create(form); navigate('/tickets/' + data.data.ticket.id); }
    catch (err) { setError(err.response?.data?.message || 'Failed to create ticket'); }
    finally { setLoading(false); }
  };
  return (
    <div className="p-8 max-w-2xl animate-fade-in">
      <button onClick={() => navigate('/tickets')} className="text-sm text-surface-100/40 hover:text-surface-50 mb-6 flex items-center gap-1 transition-colors">← Back</button>
      <h1 className="text-2xl font-semibold text-surface-50 mb-1">New Ticket</h1>
      <p className="text-sm text-surface-100/50 mb-8">Describe your issue and we'll assign someone to help.</p>
      <div className="card p-6">
        <form onSubmit={submit} className="space-y-5">
          <div><label className="label">Title *</label><input className="input" placeholder="Brief summary of the issue" required value={form.title} onChange={e => set('title', e.target.value)} /></div>
          <div><label className="label">Description *</label><textarea className="input resize-none" rows={5} required placeholder="Describe the issue in detail..." value={form.description} onChange={e => set('description', e.target.value)} /></div>
          <div className="grid grid-cols-2 gap-4">
            <div><label className="label">Category</label><select className="input font-mono text-xs" value={form.category} onChange={e => set('category',e.target.value)}>{['HARDWARE','SOFTWARE','NETWORK','ACCESS','OTHER'].map(c => <option key={c}>{c}</option>)}</select></div>
            <div><label className="label">Priority</label><select className="input font-mono text-xs" value={form.priority} onChange={e => set('priority',e.target.value)}>{['LOW','MEDIUM','HIGH','CRITICAL'].map(p => <option key={p}>{p}</option>)}</select></div>
          </div>
          {error && <div className="bg-red-500/10 border border-red-500/20 text-red-400 text-sm px-3 py-2 rounded-lg">{error}</div>}
          <div className="flex justify-end gap-3 pt-2">
            <button type="button" onClick={() => navigate(-1)} className="btn-ghost">Cancel</button>
            <button type="submit" disabled={loading} className="btn-primary flex items-center gap-2">{loading && <Spinner size="sm" />}{loading ? 'Submitting...' : 'Submit Ticket'}</button>
          </div>
        </form>
      </div>
    </div>
  );
}
"@

Write-File "frontend\src\pages\TicketDetailPage.jsx" @"
import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ticketsApi, usersApi } from '../api/tickets';
import { useAuthStore } from '../store/authStore';
import { StatusBadge, PriorityBadge, RoleBadge, Spinner } from '../components/ui/Badge';
import { formatDistanceToNow, format } from 'date-fns';

export default function TicketDetailPage() {
  const { id } = useParams(); const { user } = useAuthStore(); const navigate = useNavigate();
  const [ticket, setTicket] = useState(null); const [agents, setAgents] = useState([]); const [loading, setLoading] = useState(true);
  const [comment, setComment] = useState(''); const [isInternal, setIsInternal] = useState(false);
  const [submitting, setSubmitting] = useState(false); const [updating, setUpdating] = useState(false);
  const isAgent = user?.role !== 'USER';

  useEffect(() => {
    (async () => {
      try {
        const [tRes, uRes] = await Promise.all([ticketsApi.get(id), isAgent ? usersApi.list() : null]);
        setTicket(tRes.data.data.ticket);
        if (uRes) setAgents(uRes.data.data.users.filter(u => u.role !== 'USER'));
      } catch(e) { if (e.response?.status === 404) navigate('/tickets'); }
      finally { setLoading(false); }
    })();
  }, [id]);

  const updateField = async (field, value) => { setUpdating(true); try { const { data } = await ticketsApi.update(id, { [field]:value }); setTicket(data.data.ticket); } catch(e){console.error(e);} finally{setUpdating(false);} };

  const submitComment = async (e) => {
    e.preventDefault(); if (!comment.trim()) return; setSubmitting(true);
    try { const { data } = await ticketsApi.addComment(id, { content:comment, isInternal }); setTicket(t => ({...t, comments:[...t.comments, data.data.comment]})); setComment(''); }
    catch(e){console.error(e);} finally{setSubmitting(false);}
  };

  if (loading) return <div className="flex justify-center py-32"><Spinner size="lg" /></div>;
  if (!ticket) return null;

  return (
    <div className="p-8 max-w-5xl animate-fade-in">
      <button onClick={() => navigate('/tickets')} className="text-sm text-surface-100/40 hover:text-surface-50 mb-6 flex items-center gap-1 transition-colors">← Back to tickets</button>
      <div className="flex gap-6">
        <div className="flex-1 min-w-0">
          <div className="card p-6 mb-4">
            <div className="flex items-start justify-between gap-4 mb-4">
              <div className="flex-1"><p className="text-xs font-mono text-surface-100/40 mb-1">#{ticket.id.slice(0,8)}</p><h1 className="text-xl font-semibold text-surface-50">{ticket.title}</h1></div>
              <div className="flex items-center gap-2 flex-shrink-0"><PriorityBadge priority={ticket.priority} /><StatusBadge status={ticket.status} /></div>
            </div>
            <p className="text-surface-100/70 text-sm leading-relaxed whitespace-pre-wrap">{ticket.description}</p>
            <div className="flex items-center gap-4 mt-4 pt-4 border-t border-surface-800 text-xs text-surface-100/40 font-mono">
              <span>By {ticket.createdBy?.name}</span><span>·</span><span>{format(new Date(ticket.createdAt),'dd MMM yyyy HH:mm')}</span><span>·</span><span>{ticket.category}</span>
            </div>
          </div>
          <div className="card overflow-hidden mb-4">
            <div className="px-6 py-4 border-b border-surface-800 flex items-center justify-between"><h2 className="text-sm font-medium">Activity</h2><span className="text-xs font-mono text-surface-100/40">{ticket.comments.length} comments</span></div>
            {ticket.comments.length === 0 ? <p className="px-6 py-8 text-center text-sm text-surface-100/30">No comments yet.</p> : (
              <div className="divide-y divide-surface-800">
                {ticket.comments.map(c => (
                  <div key={c.id} className={'px-6 py-4 ' + (c.isInternal ? 'bg-amber-500/5 border-l-2 border-amber-500/30' : '')}>
                    <div className="flex items-center gap-2 mb-2">
                      <div className="w-7 h-7 rounded-full bg-surface-800 flex items-center justify-center text-xs font-medium">{c.author.name[0]}</div>
                      <span className="text-sm font-medium text-surface-50">{c.author.name}</span>
                      <RoleBadge role={c.author.role} />
                      {c.isInternal && <span className="text-xs font-mono text-amber-500/60 bg-amber-500/10 px-1.5 py-0.5 rounded">internal</span>}
                      <span className="text-xs text-surface-100/30 font-mono ml-auto">{formatDistanceToNow(new Date(c.createdAt),{addSuffix:true})}</span>
                    </div>
                    <p className="text-sm text-surface-100/80 leading-relaxed pl-9">{c.content}</p>
                  </div>
                ))}
              </div>
            )}
            <form onSubmit={submitComment} className="px-6 py-4 border-t border-surface-800 space-y-3">
              <textarea className="input resize-none" rows={3} placeholder="Add a comment..." value={comment} onChange={e => setComment(e.target.value)} />
              <div className="flex items-center justify-between">
                {isAgent && <label className="flex items-center gap-2 text-xs text-surface-100/50 cursor-pointer"><input type="checkbox" checked={isInternal} onChange={e => setIsInternal(e.target.checked)} className="rounded border-surface-700 bg-surface-800" /> Internal note</label>}
                <div className="ml-auto"><button type="submit" className="btn-primary" disabled={submitting || !comment.trim()}>{submitting ? 'Posting...' : 'Post comment'}</button></div>
              </div>
            </form>
          </div>
        </div>
        <div className="w-64 flex-shrink-0 space-y-4">
          {isAgent && (
            <div className="card p-4 space-y-4">
              <p className="text-xs font-mono text-surface-100/40 uppercase tracking-wider">Manage</p>
              <div><label className="label">Status</label><select className="input text-xs font-mono" value={ticket.status} onChange={e => updateField('status',e.target.value)} disabled={updating}>{['OPEN','IN_PROGRESS','RESOLVED','CLOSED'].map(s => <option key={s} value={s}>{s.replace('_',' ')}</option>)}</select></div>
              <div><label className="label">Priority</label><select className="input text-xs font-mono" value={ticket.priority} onChange={e => updateField('priority',e.target.value)} disabled={updating}>{['LOW','MEDIUM','HIGH','CRITICAL'].map(p => <option key={p}>{p}</option>)}</select></div>
              <div><label className="label">Assigned to</label><select className="input text-xs font-mono" value={ticket.assignedToId ?? ''} onChange={e => updateField('assignedToId',e.target.value||null)} disabled={updating}><option value="">Unassigned</option>{agents.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
              {updating && <div className="flex items-center gap-2 text-xs text-surface-100/40"><Spinner size="sm" /> Saving...</div>}
            </div>
          )}
          <div className="card p-4 space-y-3">
            <p className="text-xs font-mono text-surface-100/40 uppercase tracking-wider">Details</p>
            {[['Category',ticket.category],['Reporter',ticket.createdBy?.name],['Created',format(new Date(ticket.createdAt),'dd MMM yyyy')],['Updated',formatDistanceToNow(new Date(ticket.updatedAt),{addSuffix:true})]].map(([l,v]) => <div key={l}><p className="text-xs text-surface-100/30 font-mono">{l}</p><p className="text-sm text-surface-100/70 mt-0.5">{v}</p></div>)}
          </div>
          {user?.role === 'ADMIN' && (
            <div className="card p-4 border-red-500/10">
              <p className="text-xs font-mono text-red-400/60 uppercase tracking-wider mb-3">Danger</p>
              <button onClick={async () => { if (confirm('Delete this ticket?')) { await ticketsApi.delete(id); navigate('/tickets'); } }} className="text-xs text-red-400 hover:text-red-300 transition-colors">Delete ticket</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
"@

Write-File "frontend\src\pages\UsersPage.jsx" @"
import { useEffect, useState } from 'react';
import { usersApi } from '../api/tickets';
import { RoleBadge, Spinner } from '../components/ui/Badge';
import { formatDistanceToNow } from 'date-fns';
import { useAuthStore } from '../store/authStore';

export default function UsersPage() {
  const { user: me } = useAuthStore();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => { usersApi.list().then(({ data }) => setUsers(data.data.users)).catch(console.error).finally(() => setLoading(false)); }, []);

  const updateRole = (id, role) => usersApi.updateRole(id, role).then(() => setUsers(us => us.map(u => u.id===id ? {...u,role} : u))).catch(console.error);
  const unlock = (id) => usersApi.unlock(id).then(() => setUsers(us => us.map(u => u.id===id ? {...u,isLocked:false} : u))).catch(console.error);

  if (loading) return <div className="flex justify-center py-32"><Spinner size="lg" /></div>;

  return (
    <div className="p-8 animate-fade-in">
      <div className="mb-6"><h1 className="text-2xl font-semibold text-surface-50">Users</h1><p className="text-surface-100/50 text-sm mt-0.5">{users.length} accounts</p></div>
      <div className="card overflow-hidden">
        <table className="w-full text-sm">
          <thead><tr className="border-b border-surface-800 text-xs font-mono text-surface-100/40 uppercase tracking-wider">
            <th className="text-left px-6 py-3">User</th><th className="text-left px-4 py-3">Role</th><th className="text-left px-4 py-3">Status</th><th className="text-left px-4 py-3">Joined</th>
            {me?.role==='ADMIN' && <th className="text-left px-4 py-3">Actions</th>}
          </tr></thead>
          <tbody className="divide-y divide-surface-800">
            {users.map(u => (
              <tr key={u.id} className="hover:bg-surface-800/30 transition-colors">
                <td className="px-6 py-4"><div className="flex items-center gap-3"><div className="w-8 h-8 rounded-full bg-surface-800 flex items-center justify-center text-xs font-medium">{u.name[0]}</div><div><p className="font-medium text-surface-50">{u.name}</p><p className="text-xs text-surface-100/40 font-mono">{u.email}</p></div></div></td>
                <td className="px-4 py-4"><RoleBadge role={u.role} /></td>
                <td className="px-4 py-4">{u.isLocked ? <span className="text-xs font-mono text-red-400 bg-red-500/10 border border-red-500/20 px-2 py-0.5 rounded-md">LOCKED</span> : <span className="text-xs font-mono text-emerald-400">Active</span>}</td>
                <td className="px-4 py-4 text-xs text-surface-100/40 font-mono">{formatDistanceToNow(new Date(u.createdAt),{addSuffix:true})}</td>
                {me?.role==='ADMIN' && <td className="px-4 py-4"><div className="flex items-center gap-2">{u.id!==me?.id && <select value={u.role} onChange={e => updateRole(u.id,e.target.value)} className="input !w-auto text-xs font-mono py-1">{['USER','AGENT','ADMIN'].map(r=><option key={r}>{r}</option>)}</select>}{u.isLocked && <button onClick={() => unlock(u.id)} className="text-xs text-emerald-400 hover:underline">Unlock</button>}</div></td>}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
"@

Write-Host "  Frontend files created" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
# docker-compose.yml (fix backend proxy target)
# ══════════════════════════════════════════════════════════════════════════════

Write-File "docker-compose.yml" @"
services:
  postgres:
    image: postgres:16-alpine
    container_name: ticketing_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: it_ticketing
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    container_name: ticketing_api
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    env_file: ./backend/.env
    environment:
      DATABASE_URL: postgresql://postgres:password@postgres:5432/it_ticketing
    ports:
      - "4000:4000"
    volumes:
      - ./backend:/app
      - /app/node_modules

  frontend:
    build: ./frontend
    container_name: ticketing_ui
    restart: unless-stopped
    depends_on:
      - backend
    ports:
      - "5173:5173"
    volumes:
      - ./frontend:/app
      - /app/node_modules

volumes:
  postgres_data:
"@

Write-Host ""
Write-Host "All files created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. docker-compose up --build"
Write-Host "  2. (new terminal) docker exec ticketing_api npx prisma migrate dev --name init"
Write-Host "  3. docker exec ticketing_api node prisma/seed.js"
Write-Host "  4. Open http://localhost:5173"
Write-Host ""
Write-Host "Demo logins:" -ForegroundColor Cyan
Write-Host "  admin@company.com / Admin1234!"
Write-Host "  agent@company.com / Agent1234!"
Write-Host "  user@company.com  / User1234!"