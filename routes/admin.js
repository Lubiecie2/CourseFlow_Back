const express = require("express");
const router = express.Router();
const adminController = require("../controllers/adminController");
const authMiddleware = require("../middleware/authMiddleware");
const checkAdmin = require("../middleware/checkAdmin");

/**
 * @swagger
 * /api/admin/users:
 *   get:
 *     summary: Pobiera listę wszystkich użytkowników
 *     description: Zwraca listę użytkowników. Wymaga autoryzacji administratora.
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Lista użytkowników pobrana pomyślnie
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
 *                   email:
 *                     type: string
 *                     example: "user@example.com"
 *                   firstName:
 *                     type: string
 *                     example: "John"
 *                   lastName:
 *                     type: string
 *                     example: "Doe"
 *       401:
 *         description: Brak autoryzacji - nieprawidłowy token
 *       403:
 *         description: Brak dostępu - wymagane uprawnienia administratora
 */
router.get("/users", authMiddleware, checkAdmin, adminController.getAllUsers);

/**
 * @swagger
 * /api/admin/users/{id}:
 *   delete:
 *     summary: Usuwa użytkownika
 *     description: Usuwa użytkownika na podstawie jego ID. Wymaga autoryzacji administratora.
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID użytkownika do usunięcia
 *     responses:
 *       200:
 *         description: Użytkownik został pomyślnie usunięty
 *       401:
 *         description: Brak autoryzacji - nieprawidłowy token
 *       403:
 *         description: Brak dostępu - wymagane uprawnienia administratora
 *       404:
 *         description: Użytkownik nie znaleziony
 */
router.delete(
  "/users/:id",
  authMiddleware,
  checkAdmin,
  adminController.deleteUser
);

/**
 * @swagger
 * /api/admin/users/{id}/role:
 *   put:
 *     summary: Aktualizuje rolę użytkownika
 *     description: Zmienia rolę użytkownika na podstawie jego ID. Wymaga autoryzacji administratora.
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID użytkownika, którego rola ma zostać zmieniona
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               role:
 *                 type: string
 *                 example: "admin"
 *     responses:
 *       200:
 *         description: Rola użytkownika została pomyślnie zmieniona
 *       401:
 *         description: Brak autoryzacji - nieprawidłowy token
 *       403:
 *         description: Brak dostępu - wymagane uprawnienia administratora
 *       404:
 *         description: Użytkownik nie znaleziony
 */
router.put(
  "/users/:id/role",
  authMiddleware,
  checkAdmin,
  adminController.updateUserRole
);

/**
 * @swagger
 * /api/admin/users/search:
 *   get:
 *     summary: Wyszukuje użytkowników na podstawie zapytania
 *     description: Zwraca listę użytkowników na podstawie zapytania (np. email, imię, nazwisko).
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: query
 *         required: true
 *         schema:
 *           type: string
 *         description: Zapytanie wyszukiwania użytkowników
 *     responses:
 *       200:
 *         description: Lista użytkowników pasujących do zapytania
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
 *                   email:
 *                     type: string
 *                     example: "user@example.com"
 *                   firstName:
 *                     type: string
 *                     example: "John"
 *                   lastName:
 *                     type: string
 *                     example: "Doe"
 *       400:
 *         description: Brak zapytania do wyszukiwania
 *       401:
 *         description: Brak autoryzacji - nieprawidłowy token
 *       403:
 *         description: Brak dostępu - wymagane uprawnienia administratora
 */
router.get(
  "/users/search",
  authMiddleware,
  checkAdmin,
  adminController.searchUsers
);

module.exports = router;
