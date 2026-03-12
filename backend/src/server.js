const app = require('./app');
const env = require('./config/env');
const prisma = require('./config/prisma');
const server = app.listen(env.port, () => console.log('API running on port ' + env.port));
process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT',  () => server.close(() => process.exit(0)));