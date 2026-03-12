const { PrismaClient } = require('@prisma/client')
const argon2 = require('argon2')
const prisma = new PrismaClient()

async function main() {
  const hash = (p) => argon2.hash(p, { type: argon2.argon2id })

  const admin = await prisma.user.upsert({
    where: { email: 'admin@company.com' },
    update: {},
    create: {
      email: 'admin@company.com',
      name: 'Admin User',
      passwordHash: await hash('Admin1234!'),
      role: 'ADMIN',
    },
  })
  const agent = await prisma.user.upsert({
    where: { email: 'agent@company.com' },
    update: {},
    create: {
      email: 'agent@company.com',
      name: 'Support Agent',
      passwordHash: await hash('Agent1234!'),
      role: 'AGENT',
    },
  })
  const user = await prisma.user.upsert({
    where: { email: 'user@company.com' },
    update: {},
    create: {
      email: 'user@company.com',
      name: 'Regular User',
      passwordHash: await hash('User1234!'),
      role: 'USER',
    },
  })

  const tickets = [
    {
      title: 'Laptop not connecting to VPN',
      description:
        'Getting timeout errors when trying to connect to company VPN from home. Started after the Windows update yesterday.',
      status: 'OPEN',
      priority: 'HIGH',
      category: 'NETWORK',
      createdById: user.id,
    },
    {
      title: 'Need access to Salesforce',
      description:
        'Starting a new project with the sales team and require read access to Salesforce CRM.',
      status: 'IN_PROGRESS',
      priority: 'MEDIUM',
      category: 'ACCESS',
      createdById: user.id,
      assignedToId: agent.id,
    },
    {
      title: 'Printer on 3rd floor offline',
      description:
        'The HP LaserJet on the 3rd floor has been showing offline since Monday. Multiple users affected.',
      status: 'OPEN',
      priority: 'MEDIUM',
      category: 'HARDWARE',
      createdById: user.id,
    },
    {
      title: 'Outlook keeps crashing on startup',
      description:
        'Outlook crashes immediately on launch. Tried reinstalling but issue persists. Using Office 365.',
      status: 'RESOLVED',
      priority: 'HIGH',
      category: 'SOFTWARE',
      createdById: user.id,
      assignedToId: agent.id,
    },
    {
      title: 'New employee setup - John Smith',
      description:
        'New hire starting Monday. Need laptop provisioned, email set up, and access to internal tools.',
      status: 'OPEN',
      priority: 'CRITICAL',
      category: 'ACCESS',
      createdById: admin.id,
    },
    {
      title: 'Monitor flickering at desk 42',
      description:
        'Dell monitor has been flickering intermittently for the past week. Checked cable connections all secure.',
      status: 'IN_PROGRESS',
      priority: 'LOW',
      category: 'HARDWARE',
      createdById: user.id,
      assignedToId: agent.id,
    },
    {
      title: 'Cannot access shared drive',
      description:
        'Getting access denied when trying to open the Marketing shared drive. Other team members can access it fine.',
      status: 'CLOSED',
      priority: 'MEDIUM',
      category: 'ACCESS',
      createdById: user.id,
    },
  ]
  for (const t of tickets) {
    await prisma.ticket.create({ data: t })
  }

  console.log('Seed complete')
  console.log('  admin@company.com / Admin1234!')
  console.log('  agent@company.com / Agent1234!')
  console.log('  user@company.com  / User1234!')
}
main()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
