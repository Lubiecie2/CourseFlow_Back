const express = require("express");
const router = express.Router();
const chapterController = require("../controllers/chapterController");
const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/upload");

/**
 * @swagger
 * tags:
 *   name: Chapters
 *   description: Endpoints for managing chapters of a course
 */

/**
 * @swagger
 * /api/courses/{courseId}/chapters:
 *   post:
 *     summary: Create a new chapter for a course
 *     description: Allows creating a new chapter for a specified course.
 *     tags:
 *       - Chapters
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course to which the chapter will be added.
 *         schema:
 *           type: integer
 *           example: 1
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 example: "Introduction to JavaScript"
 *               description:
 *                 type: string
 *                 example: "This chapter introduces the basics of JavaScript."
 *     responses:
 *       201:
 *         description: Chapter successfully created.
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
 *                   example: "Introduction to JavaScript"
 *                 description:
 *                   type: string
 *                   example: "This chapter introduces the basics of JavaScript."
 *       400:
 *         description: Missing required fields (title).
 *       404:
 *         description: Course not found for the specified ID.
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
  "/:courseId/chapters",
  authMiddleware,
  chapterController.createChapter
);

/**
 * @swagger
 * /api/courses/{courseId}/chapters:
 *   get:
 *     summary: Get all chapters for a course
 *     description: Retrieves all chapters of a specific course.
 *     tags:
 *       - Chapters
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course to retrieve chapters for.
 *         schema:
 *           type: integer
 *           example: 1
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Successfully retrieved chapters for the course.
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
 *                     example: "Introduction to JavaScript"
 *                   description:
 *                     type: string
 *                     example: "This chapter introduces the basics of JavaScript."
 *       404:
 *         description: Course not found for the specified ID.
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
router.get(
  "/:courseId/chapters",
  authMiddleware,
  chapterController.getChapters
);

/**
 * @swagger
 * /api/courses/{courseId}/chapters/{chapterId}:
 *   patch:
 *     summary: Update a chapter in a course
 *     description: Allows updating a chapter's content (e.g., WYSIWYG code) for a specific course.
 *     tags:
 *       - Chapters
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course to which the chapter belongs.
 *         schema:
 *           type: integer
 *           example: 1
 *       - in: path
 *         name: chapterId
 *         required: true
 *         description: ID of the chapter to update.
 *         schema:
 *           type: integer
 *           example: 1
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               wysiwyg_code:
 *                 type: string
 *                 example: "<p>Updated chapter content</p>"
 *     responses:
 *       200:
 *         description: Chapter successfully updated.
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
 *                   example: "Chapter updated successfully."
 *       400:
 *         description: Invalid chapter or missing content.
 *       404:
 *         description: Chapter not found for the specified course ID.
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
  "/:courseId/chapters/:chapterId",
  authMiddleware,
  chapterController.updateChapter
);

/**
 * @swagger
 * /api/courses/{courseId}/chapters/{chapterId}:
 *   get:
 *     summary: Get a specific chapter of a course
 *     description: Retrieves a specific chapter from a course using the chapter ID.
 *     tags:
 *       - Chapters
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course to which the chapter belongs.
 *         schema:
 *           type: integer
 *           example: 1
 *       - in: path
 *         name: chapterId
 *         required: true
 *         description: ID of the chapter to retrieve.
 *         schema:
 *           type: integer
 *           example: 1
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Successfully retrieved the chapter.
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
 *                   example: "Introduction to JavaScript"
 *                 description:
 *                   type: string
 *                   example: "This chapter introduces the basics of JavaScript."
 *       404:
 *         description: Chapter not found for the specified ID.
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
router.get(
  "/:courseId/chapters/:chapterId",
  authMiddleware,
  chapterController.getChapter
);

router.delete(
  "/:courseId/chapters/:chapterId",
  authMiddleware,
  chapterController.deleteChapter
);
/**
 * @swagger
 * /api/courses/{courseId}/chapters/upload-image:
 *   post:
 *     summary: Upload image for chapter content
 *     tags:
 *       - Chapters
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course
 *         schema:
 *           type: integer
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               image:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Image uploaded successfully
 *       400:
 *         description: No file uploaded
 *       500:
 *         description: Server error
 */
router.post(
  "/:courseId/chapters/upload-image",
  authMiddleware,
  upload.single("image"),
  chapterController.uploadChapterImage
);

/**
 * @swagger
 * /api/courses/{courseId}/chapters/{chapterId}/upload-video:
 *   post:
 *     summary: Upload a video for a chapter
 *     description: Upload a video that can be used in chapter content.
 *     tags:
 *       - Chapters
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course.
 *         schema:
 *           type: integer
 *       - in: path
 *         name: chapterId
 *         required: true
 *         description: ID of the chapter.
 *         schema:
 *           type: integer
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               video:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Video uploaded successfully
 */
router.post(
  "/:courseId/chapters/:chapterId/upload-video",
  authMiddleware,
  upload.single("video"),
  chapterController.uploadChapterVideo
);
module.exports = router;
