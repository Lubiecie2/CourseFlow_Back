const express = require("express");
const router = express.Router();
const notificationController = require("../controllers/notificationController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/", authMiddleware, notificationController.getUserNotifications);

router.get(
  "/unread-count",
  authMiddleware,
  notificationController.getUnreadCount
);

router.post(
  "/admin",
  authMiddleware,
  notificationController.createAdminNotification
);

module.exports = router;
