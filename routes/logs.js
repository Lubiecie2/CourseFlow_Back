const express = require("express");
const router = express.Router();
const userLogsController = require("../controllers/userLogsController");
const authMiddleware = require("../middleware/authMiddleware");
const checkAdmin = require("../middleware/checkAdmin");

router.get("/", authMiddleware, checkAdmin, userLogsController.getAllLogs);

router.get(
  "/users/:userId",
  authMiddleware,
  checkAdmin,
  userLogsController.getUserLogs
);

module.exports = router;
