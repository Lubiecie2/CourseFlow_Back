const express = require("express");
const router = express.Router();
const courseAnswerController = require("../controllers/courseAnswerController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: Answers
 *   description: Endpoints for managing question answers
 */

/**
 * @swagger
 * /api/questions/{questionId}/answers:
 *   get:
 *     summary: Get answers for a question
 *     description: Returns a list of answers for a specific question
 *     tags:
 *       - Answers
 *     parameters:
 *       - in: path
 *         name: questionId
 *         required: true
 *         description: ID of the question
 *         schema:
 *           type: integer
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *         description: Number of answers per page
 *     responses:
 *       200:
 *         description: Answers successfully retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 answers:
 *                   type: array
 *                   items:
 *                     type: object
 *                 pagination:
 *                   type: object
 *       500:
 *         description: Server error
 */
router.get("/questions/:questionId/answers", courseAnswerController.getAnswers);

/**
 * @swagger
 * /api/questions/{questionId}/answers:
 *   post:
 *     summary: Create a new answer
 *     description: Adds a new answer to a specific question
 *     tags:
 *       - Answers
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: questionId
 *         required: true
 *         description: ID of the question to answer
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - content
 *             properties:
 *               content:
 *                 type: string
 *                 description: Content of the answer
 *     responses:
 *       201:
 *         description: Answer successfully created
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 answer:
 *                   type: object
 *       400:
 *         description: Missing required fields
 *       401:
 *         description: User not authenticated
 *       404:
 *         description: Question not found
 *       500:
 *         description: Server error
 */
router.post(
  "/questions/:questionId/answers",
  authMiddleware,
  courseAnswerController.createAnswer
);

/**
 * @swagger
 * /api/answers/{answerId}:
 *   patch:
 *     summary: Update an answer
 *     description: Updates the content of an existing answer (only author can edit)
 *     tags:
 *       - Answers
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: answerId
 *         required: true
 *         description: ID of the answer to update
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - content
 *             properties:
 *               content:
 *                 type: string
 *                 description: New content of the answer
 *     responses:
 *       200:
 *         description: Answer successfully updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 answer:
 *                   type: object
 *       400:
 *         description: Missing required fields
 *       401:
 *         description: User not authenticated
 *       403:
 *         description: No permission to edit this answer
 *       404:
 *         description: Answer not found
 *       500:
 *         description: Server error
 */
router.patch(
  "/answers/:answerId",
  authMiddleware,
  courseAnswerController.updateAnswer
);

/**
 * @swagger
 * /api/answers/{answerId}:
 *   delete:
 *     summary: Delete an answer
 *     description: Deletes an answer by ID (only author or admin can delete)
 *     tags:
 *       - Answers
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: answerId
 *         required: true
 *         description: ID of the answer to delete
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Answer successfully deleted
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *       401:
 *         description: User not authenticated
 *       403:
 *         description: No permission to delete this answer
 *       404:
 *         description: Answer not found
 *       500:
 *         description: Server error
 */
router.delete(
  "/answers/:answerId",
  authMiddleware,
  courseAnswerController.deleteAnswer
);

module.exports = router;
