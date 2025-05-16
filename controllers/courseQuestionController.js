const courseQuestionModel = require("../models/courseQuestionModel");

const courseQuestionController = {
  getQuestionsByCourse: async (req, res) => {
    try {
      const { courseId } = req.params;
      const limit = parseInt(req.query.limit) || 10;
      const page = parseInt(req.query.page) || 1;
      const offset = (page - 1) * limit;

      const result = await courseQuestionModel.getQuestionsByCourse(
        courseId,
        limit,
        offset
      );

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania pytań",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        questions: result.questions,
        pagination: {
          total: result.total,
          page,
          limit,
          totalPages: Math.ceil(result.total / limit),
        },
      });
    } catch (error) {
      console.error("Błąd w kontrolerze pytań:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getQuestionById: async (req, res) => {
    try {
      const { id } = req.params;

      const result = await courseQuestionModel.getQuestionById(id);

      if (!result.success) {
        return res.status(404).json({
          success: false,
          message: "Pytanie nie zostało znalezione",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        question: result.question,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze pytań:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  createQuestion: async (req, res) => {
    try {
      const { title, content, courseId } = req.body;
      const userId = req.user.id;

      if (!title || !content) {
        return res.status(400).json({
          success: false,
          message: "Tytuł i treść pytania są wymagane",
        });
      }

      const data = {
        title,
        content,
        userId,
        courseId,
      };

      const result = await courseQuestionModel.createQuestion(data);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas tworzenia pytania",
          error: result.error,
        });
      }

      return res.status(201).json({
        success: true,
        message: "Pytanie zostało pomyślnie utworzone",
        question: result.question,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze pytań:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getAllQuestions: async (req, res) => {
    try {
      const limit = parseInt(req.query.limit) || 10;
      const page = parseInt(req.query.page) || 1;
      const offset = (page - 1) * limit;

      const result = await courseQuestionModel.getAllQuestions(limit, offset);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania pytań",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        questions: result.questions,
        pagination: {
          total: result.total,
          page,
          limit,
          totalPages: Math.ceil(result.total / limit),
        },
      });
    } catch (error) {
      console.error("Błąd w kontrolerze pytań:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },
};

module.exports = courseQuestionController;
