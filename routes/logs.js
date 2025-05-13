const express = require("express");
const router = express.Router();
const userLogsController = require("../controllers/userLogsController");
const authMiddleware = require("../middleware/authMiddleware");
const checkAdmin = require("../middleware/checkAdmin");

/**
 * @swagger
 * tags:
 *   name: Logs
 *   description: API for managing user operation logs
 */

/**
 * @swagger
 * /api/logs:
 *   get:
 *     summary: Get all operation logs
 *     description: Returns a list of all user operation logs with filtering options
 *     tags: [Logs]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         description: Page number (defaults to 1)
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         description: Number of logs per page (defaults to 20)
 *       - in: query
 *         name: fromDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: Start date for filtering (YYYY-MM-DDT00:00:00.000Z)
 *       - in: query
 *         name: toDate
 *         schema:
 *           type: string
 *           format: date-time
 *         description: End date for filtering (YYYY-MM-DDT23:59:59.999Z)
 *       - in: query
 *         name: userId
 *         schema:
 *           type: integer
 *         description: Filter by user ID
 *       - in: query
 *         name: actionType
 *         schema:
 *           type: string
 *         description: Filter by action type
 *     responses:
 *       200:
 *         description: List of operation logs
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 logs:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       user_id:
 *                         type: integer
 *                       changed_by_user_id:
 *                         type: integer
 *                       action_type:
 *                         type: string
 *                       old_value:
 *                         type: string
 *                       new_value:
 *                         type: string
 *                       created_at:
 *                         type: string
 *                         format: date-time
 *                       user_email:
 *                         type: string
 *                       user_first_name:
 *                         type: string
 *                       user_last_name:
 *                         type: string
 *                       changed_by_email:
 *                         type: string
 *                       changed_by_first_name:
 *                         type: string
 *                       changed_by_last_name:
 *                         type: string
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     totalPages:
 *                       type: integer
 *                     currentPage:
 *                       type: integer
 *                     perPage:
 *                       type: integer
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - Admin access required
 *       500:
 *         description: Server error
 */
router.get("/", authMiddleware, checkAdmin, userLogsController.getAllLogs);

/**
 * @swagger
 * /api/logs/users/{userId}:
 *   get:
 *     summary: Get logs for a specific user
 *     description: Returns a list of operation logs for a specific user
 *     tags: [Logs]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         schema:
 *           type: integer
 *         required: true
 *         description: User ID
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         description: Page number (defaults to 1)
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         description: Number of logs per page (defaults to 20)
 *     responses:
 *       200:
 *         description: List of user logs
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 logs:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       user_id:
 *                         type: integer
 *                       changed_by_user_id:
 *                         type: integer
 *                       action_type:
 *                         type: string
 *                       old_value:
 *                         type: string
 *                       new_value:
 *                         type: string
 *                       created_at:
 *                         type: string
 *                         format: date-time
 *                       user_email:
 *                         type: string
 *                       user_first_name:
 *                         type: string
 *                       user_last_name:
 *                         type: string
 *                       changed_by_email:
 *                         type: string
 *                       changed_by_first_name:
 *                         type: string
 *                       changed_by_last_name:
 *                         type: string
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     totalPages:
 *                       type: integer
 *                     currentPage:
 *                       type: integer
 *                     perPage:
 *                       type: integer
 *       400:
 *         description: Invalid user ID
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - Admin access required
 *       500:
 *         description: Server error
 */
router.get(
  "/users/:userId",
  authMiddleware,
  checkAdmin,
  userLogsController.getUserLogs
);

module.exports = router;
