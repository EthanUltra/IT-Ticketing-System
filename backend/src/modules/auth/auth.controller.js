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