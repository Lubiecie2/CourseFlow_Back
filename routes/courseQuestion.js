const express = require("express");
const router = express.Router();
const courseQuestionController = require("../controllers/courseQuestionController");
const authMiddleware = require("../middleware/authMiddleware");

router.get(
  "/courses/:courseId/questions",
  courseQuestionController.getQuestionsByCourse
);

router.get("/questions/:id", courseQuestionController.getQuestionById);

router.post(
  "/questions",
  authMiddleware,
  courseQuestionController.createQuestion
);

router.get("/questions", courseQuestionController.getAllQuestions);

module.exports = router;
