const express = require("express");
const router = express.Router();
const certificateController = require("../controllers/certificateController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: Certificates
 *   description: Endpoints for managing course completion certificates
 */

/**
 * @swagger
 * /api/certificates/eligibility/{courseId}:
 *   get:
 *     summary: Check certificate eligibility
 *     description: Checks if a user is eligible to receive a certificate for a specific course
 *     tags:
 *       - Certificates
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Eligibility status successfully retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 isEligible:
 *                   type: boolean
 *                 hasCertificate:
 *                   type: boolean
 *                 certificateId:
 *                   type: integer
 *                   description: Only present if hasCertificate is true
 *                 certificateCode:
 *                   type: string
 *                   description: Only present if hasCertificate is true
 *       400:
 *         description: Missing course ID
 *       500:
 *         description: Server error
 */
router.get(
  "/eligibility/:courseId",
  authMiddleware,
  certificateController.checkEligibility
);

/**
 * @swagger
 * /api/certificates/generate/{courseId}:
 *   post:
 *     summary: Generate certificate
 *     description: Generates a certificate for a user who has completed a course
 *     tags:
 *       - Certificates
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: courseId
 *         required: true
 *         description: ID of the course
 *         schema:
 *           type: integer
 *     responses:
 *       201:
 *         description: Certificate successfully generated
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 certificateId:
 *                   type: integer
 *                 certificateCode:
 *                   type: string
 *       200:
 *         description: Certificate already exists
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 certificateId:
 *                   type: integer
 *                 certificateCode:
 *                   type: string
 *       400:
 *         description: Missing course ID
 *       403:
 *         description: User doesn't meet the requirements for certification
 *       404:
 *         description: User or course not found
 *       500:
 *         description: Server error
 */
router.post(
  "/generate/:courseId",
  authMiddleware,
  certificateController.generateCertificate
);

/**
 * @swagger
 * /api/certificates/user:
 *   get:
 *     summary: Get user certificates
 *     description: Retrieves all certificates earned by the authenticated user
 *     tags:
 *       - Certificates
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Certificates successfully retrieved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 certificates:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: integer
 *                       certificate_code:
 *                         type: string
 *                       issued_at:
 *                         type: string
 *                         format: date-time
 *                       courses:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: integer
 *                           title:
 *                             type: string
 *                           category:
 *                             type: string
 *                           course_image:
 *                             type: string
 *       500:
 *         description: Server error
 */
router.get("/user", authMiddleware, certificateController.getUserCertificates);

/**
 * @swagger
 * /api/certificates/download/{certificateCode}:
 *   get:
 *     summary: Download certificate
 *     description: Downloads a certificate PDF file by unique code
 *     tags:
 *       - Certificates
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: certificateCode
 *         required: true
 *         description: Unique code of the certificate
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Certificate PDF file
 *         content:
 *           application/pdf:
 *             schema:
 *               type: string
 *               format: binary
 *       400:
 *         description: Missing certificate code
 *       403:
 *         description: No permission to download this certificate
 *       404:
 *         description: Certificate not found
 *       500:
 *         description: Server error
 */
router.get(
  "/download/:certificateCode",
  authMiddleware,
  certificateController.downloadCertificate
);

module.exports = router;
