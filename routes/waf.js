const express = require("express");
const router = express.Router();
const wafController = require("../controllers/wafController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: WAF
 *   description: Web Application Firewall management
 */

/**
 * @swagger
 * /api/waf/status:
 *   get:
 *     summary: Get WAF status
 *     tags: [WAF]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Status WAF
 */
router.get("/status", authMiddleware, wafController.getStatus);

/**
 * @swagger
 * /api/waf/dashboard:
 *   get:
 *     summary: Get WAF dashboard data
 *     tags: [WAF]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Dashboard data
 */
router.get("/dashboard", authMiddleware, wafController.getDashboard);

/**
 * @swagger
 * /api/waf/events:
 *   get:
 *     summary: Get security events
 *     tags: [WAF]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: since
 *         schema:
 *           type: string
 *           format: date-time
 *       - in: query
 *         name: until
 *         schema:
 *           type: string
 *           format: date-time
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 50
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *     responses:
 *       200:
 *         description: Lista eventów bezpieczeństwa
 */
router.get("/events", authMiddleware, wafController.getSecurityEvents);

/**
 * @swagger
 * /api/waf/config:
 *   patch:
 *     summary: Update WAF configuration
 *     tags: [WAF]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               config:
 *                 type: object
 *                 properties:
 *                   rateLimiting:
 *                     type: object
 *                     properties:
 *                       enabled:
 *                         type: boolean
 *                       maxRequests:
 *                         type: integer
 *                   sqlInjection:
 *                     type: object
 *                     properties:
 *                       enabled:
 *                         type: boolean
 *                   xss:
 *                     type: object
 *                     properties:
 *                       enabled:
 *                         type: boolean
 *     responses:
 *       200:
 *         description: Konfiguracja zaktualizowana
 */
router.patch("/config", authMiddleware, wafController.updateConfig);

module.exports = router;
