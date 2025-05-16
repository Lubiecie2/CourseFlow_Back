const express = require("express");
const router = express.Router();
const courseAnswerController = require("../controllers/courseAnswerController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/questions/:questionId/answers", courseAnswerController.getAnswers);

router.post(
  "/questions/:questionId/answers",
  authMiddleware,
  courseAnswerController.createAnswer
);

module.exports = router;
