const express = require("express");
const router = express.Router();
const courseNoteController = require("../controllers/courseNoteController");
const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/upload");

/**
 * @swagger
 * tags:
 *   name: Notes
 *   description: Endpoints for managing course notes and forum content
 */

/**
 * @swagger
 * /api/notes/{id}/download:
 *   get:
 *     summary: Download a note's attached file
 *     description: Retrieves the file attached to a note and sends it as a downloadable attachment
 *     tags: [Notes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the note to download the file from
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: File sent as attachment
 *         content:
 *           application/octet-stream:
 *             schema:
 *               type: string
 *               format: binary
 *       404:
 *         description: File not found
 *       500:
 *         description: Server error
 */
router.get(
  "/:id/download",
  authMiddleware,
  courseNoteController.downloadNoteFile
);

/**
 * @swagger
 * /api/notes:
 *   get:
 *     summary: Get all notes
 *     description: Retrieves a paginated list of all notes
 *     tags: [Notes]
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
 *         description: Number of notes per page
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of notes
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 notes:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       title:
 *                         type: string
 *                       content:
 *                         type: string
 *                       user_id:
 *                         type: integer
 *                       course_id:
 *                         type: integer
 *                       file_path:
 *                         type: string
 *                       file_name:
 *                         type: string
 *                       created_at:
 *                         type: string
 *                         format: date-time
 *                       updated_at:
 *                         type: string
 *                         format: date-time
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     page:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     totalPages:
 *                       type: integer
 *       500:
 *         description: Server error
 */
router.get("/", authMiddleware, courseNoteController.getAllNotes);

/**
 * @swagger
 * /api/notes/{id}:
 *   get:
 *     summary: Get a note by ID
 *     description: Retrieves a specific note by its ID
 *     tags: [Notes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the note to retrieve
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Note details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 note:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: integer
 *                     title:
 *                       type: string
 *                     content:
 *                       type: string
 *                     user_id:
 *                       type: integer
 *                     course_id:
 *                       type: integer
 *                     file_path:
 *                       type: string
 *                     file_name:
 *                       type: string
 *                     created_at:
 *                       type: string
 *                       format: date-time
 *                     updated_at:
 *                       type: string
 *                       format: date-time
 *       404:
 *         description: Note not found
 *       500:
 *         description: Server error
 */
router.get("/:id", authMiddleware, courseNoteController.getNoteById);

/**
 * @swagger
 * /api/notes:
 *   post:
 *     summary: Create a new note
 *     description: Creates a new note with optional file attachment
 *     tags: [Notes]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - content
 *             properties:
 *               title:
 *                 type: string
 *                 description: Note title
 *               content:
 *                 type: string
 *                 description: Note content
 *               courseId:
 *                 type: integer
 *                 description: Course ID (optional)
 *               document:
 *                 type: string
 *                 format: binary
 *                 description: File attachment (optional)
 *               images:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *                 description: Image attachments (up to 6, optional)
 *     responses:
 *       201:
 *         description: Note created successfully
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
 *                   example: "Note created successfully"
 *                 note:
 *                   type: object
 *       400:
 *         description: Invalid input data
 *       500:
 *         description: Server error
 */
router.post(
  "/",
  authMiddleware,
  upload.fields([
    { name: "images", maxCount: 6 },
    { name: "document", maxCount: 1 },
  ]),
  courseNoteController.createNote
);

/**
 * @swagger
 * /api/notes/{id}:
 *   patch:
 *     summary: Update a note
 *     description: Updates an existing note with optional file attachment
 *     tags: [Notes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the note to update
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 description: Updated note title
 *               content:
 *                 type: string
 *                 description: Updated note content
 *               document:
 *                 type: string
 *                 format: binary
 *                 description: Updated file attachment (optional)
 *               images:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *                 description: Updated image attachments (up to 6, optional)
 *     responses:
 *       200:
 *         description: Note updated successfully
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
 *                   example: "Note updated successfully"
 *                 note:
 *                   type: object
 *       400:
 *         description: No data provided for update
 *       403:
 *         description: Not authorized to update this note
 *       404:
 *         description: Note not found
 *       500:
 *         description: Server error
 */
router.patch(
  "/:id",
  authMiddleware,
  upload.fields([
    { name: "images", maxCount: 6 },
    { name: "document", maxCount: 1 },
  ]),
  courseNoteController.updateNote
);

/**
 * @swagger
 * /api/notes/{id}:
 *   delete:
 *     summary: Delete a note
 *     description: Deletes an existing note (user must be the creator or an admin)
 *     tags: [Notes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the note to delete
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Note deleted successfully
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
 *                   example: "Note deleted successfully"
 *       403:
 *         description: Not authorized to delete this note
 *       404:
 *         description: Note not found
 *       500:
 *         description: Server error
 */
router.delete("/:id", authMiddleware, courseNoteController.deleteNote);

/**
 * @swagger
 * /api/notes/course/{courseId}:
 *   get:
 *     summary: Get notes for a specific course
 *     description: Retrieves a paginated list of notes for a particular course
 *     tags: [Notes]
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID of the course
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
 *         description: Number of notes per page
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of notes for the course
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 notes:
 *                   type: array
 *                   items:
 *                     type: object
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     page:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     totalPages:
 *                       type: integer
 *       500:
 *         description: Server error
 */
router.get(
  "/course/:courseId",
  authMiddleware,
  courseNoteController.getNotesByCourse
);

module.exports = router;
