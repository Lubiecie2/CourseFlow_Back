const express = require("express");
const router = express.Router();
const testController = require("../controllers/testController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: Tests
 *   description: API for managing chapter tests
 */

/**
 * @swagger
 * /api/chapterTest/{courseId}/chapters/{chapterId}/tests:
 *   get:
 *     summary: Get all tests for a specific chapter
 *     tags: [Tests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the course
 *       - in: path
 *         name: chapterId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the chapter
 *     responses:
 *       200:
 *         description: List of tests for the chapter
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 tests:
 *                   type: array
 *                   items:
 *                     type: object
 *       400:
 *         description: Invalid course or chapter ID
 *       500:
 *         description: Server error
 */
router.get(
  "/:courseId/chapters/:chapterId/tests",
  authMiddleware,
  testController.getTestsByChapter
);

/**
 * @swagger
 * /api/chapterTest/{courseId}/chapters/{chapterId}/tests:
 *   post:
 *     summary: Create a new test for a chapter
 *     tags: [Tests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the course
 *       - in: path
 *         name: chapterId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the chapter
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *             properties:
 *               title:
 *                 type: string
 *                 description: Title of the test
 *                 example: JavaScript Basics Test
 *               description:
 *                 type: string
 *                 description: Description of the test
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
 *       201:
 *         description: Test successfully created
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
 *                   example: Test successfully created
 *       400:
 *         description: Invalid request data or chapter ID
 *       500:
 *         description: Server error
 */
router.post(
  "/:courseId/chapters/:chapterId/tests",
  authMiddleware,
  testController.createTest
);
module.exports = router;
