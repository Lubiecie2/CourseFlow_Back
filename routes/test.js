const express = require("express");
const router = express.Router();
const testController = require("../controllers/testController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: Tests
 *   description: API for managing tests
 */

/**
 * @swagger
 * /api/tests/{testId}:
 *   get:
 *     summary: Get a specific test
 *     tags: [Tests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: testId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the test
 *     responses:
 *       200:
 *         description: Test details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 test:
 *                   type: object
 *       404:
 *         description: Test not found
 *       500:
 *         description: Server error
 */
router.get("/:testId", authMiddleware, testController.getTest);

/**
 * @swagger
 * /api/tests/{testId}:
 *   patch:
 *     summary: Update a test
 *     tags: [Tests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: testId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the test
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 description: Test title
 *                 example: JavaScript Basics Test
 *               description:
 *                 type: string
 *                 description: Test description
 *                 example: A test covering basic JavaScript concepts
 *               pass_threshold:
 *                 type: integer
 *                 description: Minimum percentage to pass the test
 *                 example: 70
 *               time_limit:
 *                 type: integer
 *                 description: Time limit in minutes (0 for no limit)
 *                 example: 30
 *     responses:
 *       200:
 *         description: Test successfully updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 test:
 *                   type: object
 *                 message:
 *                   type: string
 *                   example: Test successfully updated
 *       400:
 *         description: Invalid request data
 *       404:
 *         description: Test not found
 *       500:
 *         description: Server error
 */
router.patch("/:testId", authMiddleware, testController.updateTest);

/**
 * @swagger
 * /api/tests/{testId}:
 *   delete:
 *     summary: Delete a test
 *     tags: [Tests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: testId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the test
 *     responses:
 *       200:
 *         description: Test successfully deleted
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 message:
 *                   type: string
 *                   example: Test successfully deleted
 *       404:
 *         description: Test not found
 *       500:
 *         description: Server error
 */
router.delete("/:testId", authMiddleware, testController.deleteTest);

module.exports = router;
