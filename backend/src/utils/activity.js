const { prisma } = require('../lib/prisma')

async function logActivity({ ticketId, userId, action, message }) {
  return prisma.activityLog.create({
    data: {
      ticketId,
      userId,
      action,
      message,
    },
  })
}

module.exports = { logActivity }
