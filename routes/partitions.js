const express = require("express");
const router = express.Router();
const partitionController = require("../controllers/partitionController");
const authMiddleware = require("../middleware/authMiddleware");

/**
 * @swagger
 * tags:
 *   name: Partitions
 *   description: API for managing database partitions
 */

/**
 * @swagger
 * /partitions:
 *   get:
 *     summary: Get partitions for a table
 *     tags: [Partitions]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: tableName
 *         required: true
 *         schema:
 *           type: string
 *         description: Name of the table to get partitions for
 *     responses:
 *       200:
 *         description: List of partitions
 *       400:
 *         description: Missing tableName parameter
 *       500:
 *         description: Server error
 */
router.get("/", authMiddleware, partitionController.getPartitions);

/**
 * @swagger
 * /partitions:
 *   post:
 *     summary: Create a new partition
 *     tags: [Partitions]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - tableName
 *               - year
 *               - month
 *             properties:
 *               tableName:
 *                 type: string
 *               year:
 *                 type: integer
 *               month:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Partition created successfully
 *       400:
 *         description: Missing required parameters
 *       500:
 *         description: Server error
 */
router.post("/", authMiddleware, partitionController.createPartition);

/**
 * @swagger
 * /partitions/detach:
 *   post:
 *     summary: Detach a partition from a table
 *     tags: [Partitions]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - tableName
 *               - year
 *               - month
 *             properties:
 *               tableName:
 *                 type: string
 *               year:
 *                 type: integer
 *               month:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Partition detached successfully
 *       400:
 *         description: Missing required parameters
 *       500:
 *         description: Server error
 */
router.post("/detach", authMiddleware, partitionController.detachPartition);

/**
 * @swagger
 * /partitions/attach:
 *   post:
 *     summary: Attach a partition to a table
 *     tags: [Partitions]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - tableName
 *               - year
 *               - month
 *             properties:
 *               tableName:
 *                 type: string
 *               year:
 *                 type: integer
 *               month:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Partition attached successfully
 *       400:
 *         description: Missing required parameters
 *       500:
 *         description: Server error
 */
router.post("/attach", authMiddleware, partitionController.attachPartition);

/**
 * @swagger
 * /partitions/prepare:
 *   post:
 *     summary: Prepare partitions for a table in advance
 *     tags: [Partitions]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - tableName
 *             properties:
 *               tableName:
 *                 type: string
 *               monthsAhead:
 *                 type: integer
 *                 default: 2
 *     responses:
 *       200:
 *         description: Partitions prepared successfully
 *       400:
 *         description: Missing required parameters
 *       500:
 *         description: Server error
 */
router.post("/prepare", authMiddleware, partitionController.preparePartitions);

module.exports = router;
