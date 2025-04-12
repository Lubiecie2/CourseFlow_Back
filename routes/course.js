const express = require("express");
const router = express.Router();
const courseController = require("../controllers/courseController");
const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/upload");

/**
 * @swagger
 * tags:
 *   name: Courses
 *   description: Endpoints for managing courses
 */
/**
 * @swagger
 * /api/courses:
 *   post:
 *     summary: Create a new course
 *     description: Allows administrators to create a new course with a title, category, description, and an optional image.
 *     tags:
 *       - Courses
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 example: "JavaScript for Beginners"
 *               category:
 *                 type: string
 *                 example: "Programming"
 *               description:
 *                 type: string
 *                 example: "An introductory course to JavaScript."
 *               image:
 *                 type: string
 *                 format: binary
 *                 description: Optional image for the course.
 *     responses:
 *       201:
 *         description: Course created successfully.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Course successfully created."
 *                 course:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: integer
 *                       example: 1
 *                     title:
 *                       type: string
 *                       example: "JavaScript for Beginners"
 *                     category:
 *                       type: string
 *                       example: "Programming"
 *                     description:
 *                       type: string
 *                       example: "An introductory course to JavaScript."
 *       400:
 *         description: Missing required fields (title, category).
 *       401:
 *         description: Unauthorized - invalid token.
 *       500:
 *         description: Internal server error.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: object
 *                   properties:
 *                     status:
 *                       type: integer
 *                       example: 500
 *                     message:
 *                       type: string
 *                       example: "Internal server error. Please try again later."
 */
router.post(
  "/",
  authMiddleware,
  upload.single("image"),
  courseController.createCourse
);

/**
 * @swagger
 * /api/courses:
 *   get:
 *     summary: Retrieve a list of courses
 *     description: Fetches all courses available in the system.
 *     tags:
 *       - Courses
 *     responses:
 *       200:
 *         description: Successfully retrieved courses.
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: integer
 *                     example: 1
 *                   title:
 *                     type: string
 *                     example: "JavaScript for Beginners"
 *                   category:
 *                     type: string
 *                     example: "Programming"
 *                   description:
 *                     type: string
 *                     example: "An introductory course to JavaScript."
 *       500:
 *         description: Internal server error.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: object
 *                   properties:
 *                     status:
 *                       type: integer
 *                       example: 500
 *                     message:
 *                       type: string
 *                       example: "Internal server error. Please try again later."
 */
router.get("/", courseController.getAllCourses);

router.get("/uploads", express.static("public/uploads"));

/**
 * @swagger
 * /api/courses/{id}:
 *   get:
 *     summary: Retrieve a specific course by ID
 *     description: Fetches a single course using its unique ID.
 *     tags:
 *       - Courses
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID of the course to retrieve.
 *         schema:
 *           type: integer
 *           example: 1
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Successfully retrieved the course.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 id:
 *                   type: integer
 *                   example: 1
 *                 title:
 *                   type: string
 *                   example: "JavaScript for Beginners"
 *                 category:
 *                   type: string
 *                   example: "Programming"
 *                 description:
 *                   type: string
 *                   example: "An introductory course to JavaScript."
 *       400:
 *         description: Invalid course ID.
 *       404:
 *         description: Course not found.
 *       401:
 *         description: Unauthorized - invalid token.
 *       500:
 *         description: Internal server error.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: object
 *                   properties:
 *                     status:
 *                       type: integer
 *                       example: 500
 *                     message:
 *                       type: string
 *                       example: "Internal server error. Please try again later."
 */
router.get("/:id", authMiddleware, courseController.getCourseById);

/**
 * @swagger
 * /api/courses/{id}:
 *   patch:
 *     summary: Update an existing course
 *     description: Allows administrators to update a course's title, category, description, and optional image.
 *     tags:
 *       - Courses
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID of the course to update.
 *         schema:
 *           type: integer
 *           example: 1
 *     requestBody:
 *       required: false
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 example: "Advanced JavaScript"
 *               category:
 *                 type: string
 *                 example: "Programming"
 *               description:
 *                 type: string
 *                 example: "An advanced course on JavaScript."
 *               image:
 *                 type: string
 *                 format: binary
 *                 description: Optional image for the course.
 *     responses:
 *       200:
 *         description: Course successfully updated.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Course updated successfully."
 *                 course:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: integer
 *                       example: 1
 *                     title:
 *                       type: string
 *                       example: "Advanced JavaScript"
 *                     category:
 *                       type: string
 *                       example: "Programming"
 *                     description:
 *                       type: string
 *                       example: "An advanced course on JavaScript."
 *       400:
 *         description: Invalid course ID or missing fields.
 *       404:
 *         description: Course not found.
 *       401:
 *         description: Unauthorized - invalid token.
 *       500:
 *         description: Internal server error.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: object
 *                   properties:
 *                     status:
 *                       type: integer
 *                       example: 500
 *                     message:
 *                       type: string
 *                       example: "Internal server error. Please try again later."
 */
router.patch(
  "/:id",
  authMiddleware,
  upload.single("image"),
  courseController.updateCourse
);

/**
 * @swagger
 * /api/courses/{id}:
 *   delete:
 *     summary: Usuń kurs
 *     description: Usuwa kurs i wszystkie powiązane z nim rozdziały
 *     tags:
 *       - Kursy
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: ID kursu do usunięcia
 *         schema:
 *           type: integer
 *           example: 1
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Kurs pomyślnie usunięty
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
 *                   example: "Kurs został pomyślnie usunięty"
 *       400:
 *         description: Nieprawidłowe ID kursu
 *       404:
 *         description: Nie znaleziono kursu
 *       500:
 *         description: Wewnętrzny błąd serwera
 */
router.delete("/:id", authMiddleware, courseController.deleteCourse);

module.exports = router;
