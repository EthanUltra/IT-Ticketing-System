const prisma = require('../../config/prisma');
const { NotFoundError } = require('../../utils/errors');
async function listUsers() { return prisma.user.findMany({ select: { id:true,name:true,email:true,role:true,createdAt:true,isLocked:true }, orderBy: { createdAt:'desc' } }); }
async function updateRole({ userId, role }) { if (!await prisma.user.findUnique({ where:{id:userId} })) throw new NotFoundError(); return prisma.user.update({ where:{id:userId}, data:{role}, select:{id:true,name:true,email:true,role:true} }); }
async function unlockUser({ userId }) { if (!await prisma.user.findUnique({ where:{id:userId} })) throw new NotFoundError(); return prisma.user.update({ where:{id:userId}, data:{isLocked:false,failedLogins:0}, select:{id:true,name:true,email:true,isLocked:true} }); }
module.exports = { listUsers, updateRole, unlockUser };