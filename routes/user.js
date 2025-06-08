const express = require("express");
const router = express.Router();
const userController = require("../controllers/userProfileController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: User Profile
 *   description: API for managing user profile
 */

/**
 * @swagger
 * /api/user/stats:
 *   get:
 *     summary: Get user statistics
 *     description: Returns user statistics such as number of courses, tests, and certificates
 *     tags:
 *       - User Profile
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Statistics successfully retrieved
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server error
 */
router.get("/stats", authMiddleware, userController.getUserStats);

/**
 * @swagger
 * /api/user/activity:
 *   get:
 *     summary: Get user activities
 *     description: Returns a list of the user's recent activities
 *     tags:
 *       - User Profile
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Maximum number of activities to return
 *     responses:
 *       200:
 *         description: Activities successfully retrieved
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server error
 */
router.get("/activity", authMiddleware, userController.getUserActivity);

/**
 * @swagger
 * /api/user/profile:
 *   patch:
 *     summary: Update user profile
 *     description: Updates the user's profile information
 *     tags:
 *       - User Profile
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *     responses:
 *       200:
 *         description: Profile successfully updated
 *       400:
 *         description: Invalid data
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server error
 */
router.patch("/profile", authMiddleware, userController.updateUserProfile);

/**
 * @swagger
 * /api/user/account:
 *   delete:
 *     summary: Delete user account
 *     description: Permanently deletes the user's account and all associated data
 *     tags:
 *       - User Profile
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Account successfully deleted
 *       404:
 *         description: User not found
 *       500:
 *         description: Server error
 */
router.delete("/account", authMiddleware, userController.deleteUserAccount);

module.exports = router;
