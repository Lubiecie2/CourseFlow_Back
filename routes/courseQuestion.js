const express = require("express");
const router = express.Router();
const courseQuestionController = require("../controllers/courseQuestionController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: Questions
 *   description: Endpoints for managing course questions and forum content
 */

/**
 * @swagger
 * /api/courses/{courseId}/questions:
 *   get:
 *     summary: Get questions for a specific course
 *     description: Returns a list of questions with a specificied course
 *     tags:
 *       - Questions
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course
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
 *         description: Number of questions per page
 *     responses:
 *       200:
 *         description: Questions successfully retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 questions:
 *                   type: array
 *                   items:
 *                     type: object
 *                 pagination:
 *                   type: object
 *       500:
 *         description: Server error
 */
router.get(
  "/courses/:courseId/questions",
  courseQuestionController.getQuestionsByCourse
);

/**
 * @swagger
 * /api/questions/{id}:
 *   get:
 *     summary: Get question details
 *     description: Returns detailed information about a specific question by ID
 *     tags:
 *       - Questions
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: Question ID
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Question successfully retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 question:
 *                   type: object
 *       404:
 *         description: Question not found
 *       500:
 *         description: Server error
 */
router.get("/questions/:id", courseQuestionController.getQuestionById);

/**
 * @swagger
 * /api/questions:
 *   post:
 *     summary: Create a new question
 *     description: Adds a new question to the forum
 *     tags:
 *       - Questions
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - content
 *             properties:
 *               title:
 *                 type: string
 *                 description: Question title
 *               content:
 *                 type: string
 *                 description: Question content
 *               courseId:
 *                 type: integer
 *                 description: Course ID (optional)
 *     responses:
 *       201:
 *         description: Question successfully created
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 question:
 *                   type: object
 *       400:
 *         description: Missing required fields
 *       401:
 *         description: User not authenticated
 *       500:
 *         description: Server error
 */
router.post(
  "/questions",
  authMiddleware,
  courseQuestionController.createQuestion
);

/**
 * @swagger
 * /api/questions:
 *   get:
 *     summary: Get all questions
 *     description: Returns a list of all questions with pagination
 *     tags:
 *       - Questions
 *     parameters:
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
 *         description: Number of questions per page
 *     responses:
 *       200:
 *         description: Questions successfully retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 questions:
 *                   type: array
 *                   items:
 *                     type: object
 *                 pagination:
 *                   type: object
 *       500:
 *         description: Server error
 */
router.get("/questions", courseQuestionController.getAllQuestions);

/**
 * @swagger
 * /api/questions/{id}:
 *   delete:
 *     summary: Delete a question
 *     description: Deletes a question by ID (only author or admin can delete)
 *     tags:
 *       - Questions
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: Question ID to delete
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Question successfully deleted
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
 *         description: No permission to delete this question
 *       404:
 *         description: Question not found
 *       500:
 *         description: Server error
 */
router.delete(
  "/questions/:id",
  authMiddleware,
  courseQuestionController.deleteQuestion
);

/**
 * @swagger
 * /api/questions/{id}:
 *   patch:
 *     summary: Update a question
 *     description: Updates the title and/or content of a question by ID (only author can edit)
 *     tags:
 *       - Questions
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: Question ID to update
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - content
 *             properties:
 *               title:
 *                 type: string
 *                 description: New question title
 *               content:
 *                 type: string
 *                 description: New question content
 *     responses:
 *       200:
 *         description: Question successfully updated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 question:
 *                   type: object
 *       400:
 *         description: Missing required fields
 *       401:
 *         description: User not authenticated
 *       403:
 *         description: No permission to edit this question
 *       404:
 *         description: Question not found
 *       500:
 *         description: Server error
 */
router.patch(
  "/questions/:id",
  authMiddleware,
  courseQuestionController.updateQuestion
);

module.exports = router;
