const express = require("express");
const router = express.Router();
const adminController = require("../controllers/roleController");
const authMiddleware = require("../middleware/authMiddleware");
const checkAdmin = require("../middleware/checkAdmin");
const roleController = require("../controllers/roleController");

/**
 * @swagger
 * tags:
 *   name: Role
 *   description: Endpoints to create/update role and set permissions.
 */

/**
 * @swagger
 * /api/role/createrole:
 *   post:
 *     summary: Create a new role
 *     description: Endpoint do tworzenia nowej roli z opcjonalnymi uprawnieniami.
 *     tags:
 *       - Role
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - roleName
 *             properties:
 *               roleName:
 *                 type: string
 *                 example: "manager"
 *               permission:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 example: [1, 2, 3]
 *     responses:
 *       201:
 *         description: Rola została pomyślnie utworzona.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Rola została utworzona pomyślnie."
 *                 role:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: integer
 *                       example: 5
 *                     name:
 *                       type: string
 *                       example: "manager"
 *       400:
 *         description: Błąd walidacji danych wejściowych.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Nazwa roli jest wymagana i musi być tekstem."
 *       500:
 *         description: Wewnętrzny błąd serwera.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Wystąpił błąd podczas tworzenia roli."
 */
router.post("/createrole", authMiddleware, adminController.createRole);

/**
 * @swagger
 * /api/role/getrole:
 *   get:
 *     summary: Retrieve a list of roles with their permissions
 *     description: Returns all available roles in the system along with their associated permissions.
 *     tags:
 *       - Role
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: A list of roles with their permissions.
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
 *                   name:
 *                     type: string
 *                     example: "Moderator"
 *                   permissions:
 *                     type: array
 *                     items:
 *                       type: object
 *                       properties:
 *                         id:
 *                           type: integer
 *                           example: 101
 *                         name:
 *                           type: string
 *                           example: "PANEL_SHOW_USERS"
 *       404:
 *         description: No roles found in the system.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "No roles found in the system."
 *       500:
 *         description: Server error.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "An error occurred while fetching roles."
 */
router.get("/getrole", authMiddleware, adminController.getRolesWithPermissions);

/**
 * @swagger
 * /api/role/permissions:
 *   get:
 *     summary: Retrieve a list of all permissions
 *     description: Returns a list of all available permissions in the system.
 *     tags:
 *       - Role
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: A list of permissions.
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
 *                   name:
 *                     type: string
 *                     example: "PANEL_SHOW_USERS"
 *       404:
 *         description: No permissions found.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "No permissions found."
 *       500:
 *         description: Server error.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "An error occurred while fetching permissions."
 */
router.get("/permissions", authMiddleware, adminController.getPermissions);

/**
 * @swagger
 * /api/role/updaterole/{roleId}:
 *   patch:
 *     summary: Update a role's name and permissions
 *     description: Updates an existing role by changing its name and/or associated permissions.
 *     tags:
 *       - Role
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: roleId
 *         required: true
 *         schema:
 *           type: integer
 *         description: The ID of the role to be updated.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               roleName:
 *                 type: string
 *                 example: "Administrator"
 *               permissions:
 *                 type: array
 *                 items:
 *                   type: integer
 *                 example: [101, 102, 103]
 *     responses:
 *       200:
 *         description: Role successfully updated.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Role successfully updated."
 *       400:
 *         description: Invalid request data.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Invalid request data."
 *       404:
 *         description: Role not found.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Role not found."
 *       500:
 *         description: Server error.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "An error occurred while updating the role."
 */
router.patch("/updaterole/:roleId", authMiddleware, adminController.updateRole);
module.exports = router;
