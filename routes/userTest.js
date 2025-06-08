const express = require("express");
const router = express.Router();
const authMiddleware = require("../middleware/authMiddleware");
const userTestController = require("../controllers/userTestController");
const testBlockController = require("../controllers/testBlockController");

/**
 * @swagger
 * tags:
 *   name: UserTest
 *   description: Endpoints for users tess
 */

/**
 * @swagger
 * /api/userTest/{testId}:
 *   get:
 *     summary: Get test details for the user
 *     description: Returns basic information about the test for authenticated user
 *     tags:
 *       - UserTest
 *     parameters:
 *       - in: path
 *         name: testId
 *         required: true
 *         description: ID of the test
 *         schema:
 *           type: integer
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Test details successfully retrieved
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
 *                   properties:
 *                     id:
 *                       type: integer
 *                     title:
 *                       type: string
 *                     description:
 *                       type: string
 *                     time_limit:
 *                       type: integer
 *                     pass_threshold:
 *                       type: integer
 *                     chapter_id:
 *                       type: integer
 *                     course_id:
 *                       type: integer
 *       400:
 *         description: Invalid test ID
 *       404:
 *         description: Test not found
 *       500:
 *         description: Internal server error
 */
router.get("/:testId", authMiddleware, userTestController.getTestForUser);

/**
 * @swagger
 * /api/userTest/{testId}/blocks:
 *   get:
 *     summary: Get test blocks (questions)
 *     description: Returns questions for given test formatted for display to the user without correct answers
 *     tags:
 *       - UserTest
 *     parameters:
 *       - in: path
 *         name: testId
 *         required: true
 *         description: ID of the test
 *         schema:
 *           type: integer
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Test questions successfully retrieved
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
 *                     properties:
 *                       id:
 *                         type: integer
 *                       block_type:
 *                         type: string
 *                       question_text:
 *                         type: string
 *                       points:
 *                         type: integer
 *                       answers:
 *                         type: array
 *                         items:
 *                           type: object
 *                           properties:
 *                             id:
 *                               type: integer
 *                             text:
 *                               type: string
 *                             sort_order:
 *                               type: integer
 *       404:
 *         description: Test not found
 *       500:
 *         description: Internal server error
 */
router.get(
  "/:testId/blocks",
  authMiddleware,
  testBlockController.getTestBlocksForUser
);

/**
 * @swagger
 * /api/userTest/{testId}/submit:
 *   post:
 *     summary: Submit a test attempt
 *     description: Saves user answers, checks them and returns the test result
 *     tags:
 *       - UserTest
 *     parameters:
 *       - in: path
 *         name: testId
 *         required: true
 *         description: ID of the test
 *         schema:
 *           type: integer
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               answers:
 *                 type: object
 *                 description: Object with answers, where keys are block IDs and values are selected answer IDs
 *                 example:
 *                   "1": 5
 *                   "2": 9
 *                   "3": 12
 *     responses:
 *       200:
 *         description: Answers successfully submitted and checked
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 score:
 *                   type: integer
 *                   description: Points earned
 *                 totalPoints:
 *                   type: integer
 *                   description: Maximum possible points
 *                 percentage:
 *                   type: integer
 *                   description: Percentage of correct answers
 *                 passed:
 *                   type: boolean
 *                   description: Whether the test was passed
 *                 testThreshold:
 *                   type: integer
 *                   description: Pass threshold percentage
 *       404:
 *         description: Test not found
 *       500:
 *         description: Internal server error
 */
router.post(
  "/:testId/submit",
  authMiddleware,
  userTestController.submitTestAttempt
);

/**
 * @swagger
 * /api/userTest/{testId}/attempts:
 *   get:
 *     summary: Get test attempt history
 *     description: Returns the history of attempts for a specific test by the user
 *     tags:
 *       - UserTest
 *     parameters:
 *       - in: path
 *         name: testId
 *         required: true
 *         description: ID of the test
 *         schema:
 *           type: integer
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Successfully retrieved attempts
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 attempts:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       user_id:
 *                         type: integer
 *                       test_id:
 *                         type: integer
 *                       score:
 *                         type: number
 *                       max_score:
 *                         type: number
 *                       passed:
 *                         type: boolean
 *                       created_at:
 *                         type: string
 *                         format: date-time
 *                       user_test_answers:
 *                         type: array
 *                         items:
 *                           type: object
 *                           properties:
 *                             block_id:
 *                               type: integer
 *                             selected_answer_id:
 *                               type: integer
 *                             is_correct:
 *                               type: boolean
 *       400:
 *         description: Invalid test ID
 *       500:
 *         description: Internal server error
 */
router.get(
  "/:testId/attempts",
  authMiddleware,
  userTestController.getUserTestAttempts
);

module.exports = router;
