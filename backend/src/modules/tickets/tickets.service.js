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