const express = require("express");
const router = express.Router();
const testController = require("../controllers/testController");
const authMiddleware = require("../middleware/authMiddleware");

router.get(
  "/:courseId/chapters/:chapterId/tests",
  authMiddleware,
  testController.getTestsByChapter
);

router.post(
  "/:courseId/chapters/:chapterId/tests",
  authMiddleware,
  testController.createTest
);

module.exports = router;
