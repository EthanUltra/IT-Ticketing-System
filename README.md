# IT Ticketing System

A full-stack role-based IT help desk application built with **React**, **Node.js**, **PostgreSQL**, and **Docker**.

Users submit support tickets. Agents manage and resolve them. Admins control everything.

---

## Stack

| Layer | Tech |
|-------|------|
| Frontend | React 18, Vite, Tailwind CSS, Zustand |
| Backend | Node.js, Express |
| Database | PostgreSQL via Prisma ORM |
| Auth | JWT access tokens + refresh tokens (httpOnly cookies) |
| Infra | Docker + docker-compose |

---

## Features

**All users**
- Register / Login
- Submit tickets with title, description, priority, category
- View and comment on own tickets

**Agents**
- View all tickets
- Update ticket status and priority
- Assign tickets to agents
- Post internal notes (hidden from users)

**Admins**
- Everything agents can do
- Manage user roles
- Unlock locked accounts
- Delete tickets

---

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/yourusername/it-ticketing-system.git
cd it-ticketing-system
```

### 2. Set up backend environment

```bash
cp backend/.env.example backend/.env
# Edit backend/.env — at minimum update JWT secrets
```

### 3. Start everything

```bash
docker-compose up --build
```

### 4. Run migrations and seed demo data

```bash
# In a new terminal
docker exec ticketing_api npx prisma migrate dev --name init
docker exec ticketing_api npm run db:seed
```

### 5. Open the app

- Frontend: http://localhost:5173
- Backend API: http://localhost:4000/api
- Prisma Studio: `cd backend && npm run db:studio`

---

## Demo Accounts

| Email | Password | Role |
|-------|----------|------|
| admin@company.com | Admin1234! | ADMIN |
| agent@company.com | Agent1234! | AGENT |
| user@company.com | User1234! | USER |

---

## API Reference

### Auth
| Method | Route | Description |
|--------|-------|-------------|
| POST | `/api/auth/register` | Register |
| POST | `/api/auth/login` | Login |
| POST | `/api/auth/refresh` | Refresh tokens |
| POST | `/api/auth/logout` | Logout |
| GET | `/api/auth/me` | Current user |

### Tickets
| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/api/tickets` | All | List tickets (filtered by role) |
| POST | `/api/tickets` | All | Create ticket |
| GET | `/api/tickets/:id` | All | Get ticket |
| PATCH | `/api/tickets/:id` | Agent/Admin | Update ticket |
| DELETE | `/api/tickets/:id` | Admin | Delete ticket |
| POST | `/api/tickets/:id/comments` | All | Add comment |
| GET | `/api/tickets/stats` | Agent/Admin | Status counts |

### Users
| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/api/users` | Agent/Admin | List users |
| PATCH | `/api/users/:id/role` | Admin | Change role |
| PATCH | `/api/users/:id/unlock` | Admin | Unlock account |

---

## Project Structure

```
it-ticketing-system/
├── backend/
│   ├── prisma/           # Schema + migrations + seed
│   └── src/
│       ├── config/       # Env + Prisma client
│       ├── modules/
│       │   ├── auth/     # Register, login, tokens
│       │   ├── tickets/  # CRUD, comments, stats
│       │   └── users/    # Role management
│       ├── middleware/   # Auth, RBAC, error handler
│       └── utils/        # Token helpers, errors
├── frontend/
│   └── src/
│       ├── api/          # Axios client + API calls
│       ├── components/   # Layout, UI components
│       ├── pages/        # Dashboard, Tickets, Detail, Users
│       └── store/        # Zustand auth store
└── docker-compose.yml
```

---

## Local Dev (without Docker)

```bash
# Backend
cd backend
cp .env.example .env
npm install
npx prisma migrate dev
npm run db:seed
npm run dev   # → http://localhost:4000

# Frontend (new terminal)
cd frontend
npm install
npm run dev   # → http://localhost:5173
```

---

## CV Description

> Designed and built a full-stack role-based IT help desk system using React, Node.js, PostgreSQL, and Docker. Features ticket lifecycle management, role-based access control (USER / AGENT / ADMIN), JWT authentication with refresh token rotation, internal agent notes, audit logging, and a real-time-style comment system.
