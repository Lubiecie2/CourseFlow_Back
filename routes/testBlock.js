const express = require("express");
const router = express.Router();
const testBlockController = require("../controllers/testBlockController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: Tests
 *   description: API for managing test blocks (questions)
 */

/**
 * @swagger
 * /api/tests/{testId}/blocks:
 *   post:
 *     summary: Create a new test block (question)
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
 *             required:
 *               - block_type
 *               - question_text
 *             properties:
 *               block_type:
 *                 type: string
 *                 description: Type of test block (e.g. single_choice)
 *                 example: single_choice
 *               question_text:
 *                 type: string
 *                 description: Question text
 *                 example: Which method adds an element to the end of an array in JavaScript?
 *               points:
 *                 type: integer
 *                 description: Points for the question
 *                 default: 1
 *                 example: 1
 *               attributes:
 *                 type: object
 *                 description: Additional question attributes
 *                 example: { "difficulty": "easy", "category": "javascript" }
 *               answers:
 *                 type: array
 *                 description: List of possible answers
 *                 items:
 *                   type: object
 *                   required:
 *                     - text
 *                     - is_correct
 *                   properties:
 *                     text:
 *                       type: string
 *                       description: Answer text
 *                       example: push()
 *                     is_correct:
 *                       type: boolean
 *                       description: Whether the answer is correct
 *                       example: true
 *                     feedback:
 *                       type: string
 *                       description: Feedback for the answer
 *                       example: Correct! The push() method adds an element to the end of an array.
 *     responses:
 *       201:
 *         description: Test block successfully created
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
 *                   example: Test block successfully created
 *                 block:
 *                   type: object
 *       400:
 *         description: Data validation error
 *       404:
 *         description: Test not found
 *       500:
 *         description: Server error
 */
router.post(
  "/tests/:testId/blocks",
  authMiddleware,
  testBlockController.createTestBlock
);

/**
 * @swagger
 * /api/tests/{testId}/blocks:
 *   get:
 *     summary: Get all test blocks (questions) for a specific test
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
 *         description: List of test blocks
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 blocks:
 *                   type: array
 *                   items:
 *                     type: object
 *       404:
 *         description: Test not found
 *       500:
 *         description: Server error
 */
router.get(
  "/tests/:testId/blocks",
  authMiddleware,
  testBlockController.getTestBlocksByTest
);

/**
 * @swagger
 * /api/blocks/{blockId}:
 *   get:
 *     summary: Get a specific test block (question)
 *     tags: [Tests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: blockId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the test block
 *     responses:
 *       200:
 *         description: Test block details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 block:
 *                   type: object
 *       404:
 *         description: Test block not found
 *       500:
 *         description: Server error
 */
router.get(
  "/blocks/:blockId",
  authMiddleware,
  testBlockController.getTestBlock
);

/**
 * @swagger
 * /api/blocks/{blockId}:
 *   delete:
 *     summary: Delete a test block (question)
 *     tags: [Tests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: blockId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the test block
 *     responses:
 *       200:
 *         description: Test block successfully deleted
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
 *                   example: Test block successfully deleted
 *       404:
 *         description: Test block not found
 *       500:
 *         description: Server error
 */
router.delete(
  "/blocks/:blockId",
  authMiddleware,
  testBlockController.deleteTestBlock
);
router.patch(
  "/tests/:testId/reorder",
  authMiddleware,
  testBlockController.reorderTestBlocks
);
module.exports = router;
