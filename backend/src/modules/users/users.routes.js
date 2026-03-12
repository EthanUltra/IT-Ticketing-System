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