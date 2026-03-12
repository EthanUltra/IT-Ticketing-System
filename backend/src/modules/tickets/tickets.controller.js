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