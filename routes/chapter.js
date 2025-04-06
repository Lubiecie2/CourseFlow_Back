const express = require("express");
const router = express.Router();
const chapterController = require("../controllers/chapterController");
const authMiddleware = require("../middleware/authMiddleware");

router.post(
  "/:courseId/chapters",
  authMiddleware,
  chapterController.createChapter
);
router.get(
  "/:courseId/chapters",
  authMiddleware,
  chapterController.getChapters
);

router.patch(
  "/:courseId/chapters/:chapterId",
  authMiddleware,
  chapterController.updateChapter
);

router.get(
  "/:courseId/chapters/:chapterId",
  authMiddleware,
  chapterController.getChapter
);

module.exports = router;
