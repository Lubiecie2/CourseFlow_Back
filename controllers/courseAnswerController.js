const courseAnswerModel = require("../models/courseAnswerModel");
const courseQuestionModel = require("../models/courseQuestionModel");

const courseAnswerController = {
  createAnswer: async (req, res) => {
    try {
      const { questionId } = req.params;
      const { content } = req.body;
      const userId = req.user.id;

      if (!content) {
        return res.status(400).json({
          success: false,
          message: "Treść odpowiedzi jest wymagana",
        });
      }

      const questionCheck = await courseQuestionModel.getQuestionById(
        questionId
      );

      if (!questionCheck.success) {
        return res.status(404).json({
          success: false,
          message: "Pytanie nie istnieje",
        });
      }

      const data = {
        content,
        userId,
        questionId: parseInt(questionId),
      };

      const result = await courseAnswerModel.createAnswer(data);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas tworzenia odpowiedzi",
          error: result.error,
        });
      }

      return res.status(201).json({
        success: true,
        message: "Odpowiedź została pomyślnie utworzona",
        answer: result.answer,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze odpowiedzi:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getAnswers: async (req, res) => {
    try {
      const { questionId } = req.params;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;

      const result = await courseAnswerModel.getAnswersByQuestionId(
        questionId,
        page,
        limit
      );

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania odpowiedzi",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        answers: result.answers,
        pagination: result.pagination,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze odpowiedzi:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },
};

module.exports = courseAnswerController;
