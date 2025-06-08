const express = require("express");
const router = express.Router();
const authMiddleware = require("../middleware/authMiddleware");
const userCourseController = require("../controllers/userCourseController");

/**
 * @swagger
 * tags:
 *   name: UserCourses
 *   description: Endpoints related to user's course sign-ups
 */

/**
 * @swagger
 * /api/userCourses/registeredForCourse:
 *   get:
 *     summary: Get user's signed-up courses
 *     description: Retrieves the list of courses that the currently signed-in user has signed up for.
 *     tags:
 *       - UserCourses
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of courses the user has signed up for
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: integer
 *                   courses:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       title:
 *                         type: string
 *                       category:
 *                         type: string
 *                       course_image:
 *                         type: string
 *                       short_description:
 *                         type: string
 *       500:
 *         description: Server error while fetching user's signed-up courses
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "An error occurred while retrieving signed-up courses"
 *                 error:
 *                   type: string
 */
router.get(
  "/registeredForCourse",
  authMiddleware,
  userCourseController.getUserSignedInCourse
);

/**
 * @swagger
 * /api/userCourses/signUpToCourse:
 *   post:
 *     summary: Sign user up for a course
 *     description: Signs up the currently authenticated user for the specified course.
 *     tags:
 *       - UserCourses
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - courseId
 *             properties:
 *               courseId:
 *                 type: integer
 *                 example: 1
 *     responses:
 *       201:
 *         description: User successfully signed up for the course
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "User successfully signed up for the course"
 *                 signUp:
 *                   type: object
 *       400:
 *         description: Bad request (e.g., missing courseId or user already signed up)
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "User is already signed up for this course"
 *       404:
 *         description: Course with the given ID not found
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Course with the provided ID was not found"
 *       500:
 *         description: Server error while signing up for the course
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "An error occurred while signing up for the course"
 *                 error:
 *                   type: string
 */
router.post(
  "/signUpToCourse",
  authMiddleware,
  userCourseController.signUpUserToCourse
);

module.exports = router;
