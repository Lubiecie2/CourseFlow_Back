const testModel = require("../models/testModel");

const testController = {
  getTest: async (req, res) => {
    try {
      const { testId } = req.params;

      if (!testId || isNaN(parseInt(testId))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID testu",
        });
      }

      const result = await testModel.getTestById(testId);

      if (!result.success) {
        return res.status(404).json({
          success: false,
          message: result.message || "Test nie został znaleziony",
        });
      }

      res.status(200).json({
        success: true,
        test: result.test,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze getTest:", error);
      res.status(500).json({
        success: false,
        message: "Wewnętrzny błąd serwera",
      });
    }
  },

  getTestsByChapter: async (req, res) => {
    try {
      const { courseId, chapterId } = req.params;

      if (
        !courseId ||
        !chapterId ||
        isNaN(parseInt(courseId)) ||
        isNaN(parseInt(chapterId))
      ) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID kursu lub rozdziału",
        });
      }

      const result = await testModel.getTestsByChapter(courseId, chapterId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: result.error || "Nie udało się pobrać testów",
        });
      }

      res.status(200).json({
        success: true,
        tests: result.tests,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze getTestsByChapter:", error);
      res.status(500).json({
        success: false,
        message: "Wewnętrzny błąd serwera",
      });
    }
  },

  createTest: async (req, res) => {
    try {
      const { courseId, chapterId } = req.params;
      const { title, description, pass_threshold, time_limit } = req.body;

      if (!title || title.trim() === "") {
        return res.status(400).json({
          success: false,
          message: "Tytuł testu jest wymagany",
        });
      }

      if (
        !courseId ||
        !chapterId ||
        isNaN(parseInt(courseId)) ||
        isNaN(parseInt(chapterId))
      ) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID kursu lub rozdziału",
        });
      }

      const author_id = req.user?.id;

      if (!author_id) {
        return res.status(401).json({
          success: false,
          message: "Wymagane uwierzytelnienie",
        });
      }

      const result = await testModel.createTest({
        title,
        description,
        pass_threshold,
        time_limit,
        chapter_id: chapterId,
        course_id: courseId,
        author_id,
      });

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: result.error || "Nie udało się utworzyć testu",
        });
      }

      res.status(201).json({
        success: true,
        test: result.test,
        message: "Test został pomyślnie utworzony",
      });
    } catch (error) {
      console.error("Błąd w kontrolerze createTest:", error);
      res.status(500).json({
        success: false,
        message: "Wewnętrzny błąd serwera",
      });
    }
  },

  updateTest: async (req, res) => {
    try {
      const { testId } = req.params;
      const { title, description, pass_threshold, time_limit } = req.body;

      if (!testId || isNaN(parseInt(testId))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID testu",
        });
      }

      if (!title || title.trim() === "") {
        return res.status(400).json({
          success: false,
          message: "Tytuł testu jest wymagany",
        });
      }

      const result = await testModel.updateTest(testId, {
        title,
        description,
        pass_threshold,
        time_limit,
      });

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: result.error || "Nie udało się zaktualizować testu",
        });
      }

      res.status(200).json({
        success: true,
        test: result.test,
        message: "Test został pomyślnie zaktualizowany",
      });
    } catch (error) {
      console.error("Błąd w kontrolerze updateTest:", error);
      res.status(500).json({
        success: false,
        message: "Wewnętrzny błąd serwera",
      });
    }
  },

  deleteTest: async (req, res) => {
    try {
      const { testId } = req.params;

      if (!testId || isNaN(parseInt(testId))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID testu",
        });
      }

      const result = await testModel.deleteTest(testId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: result.error || "Nie udało się usunąć testu",
        });
      }

      res.status(200).json({
        success: true,
        message: "Test został pomyślnie usunięty",
      });
    } catch (error) {
      console.error("Błąd w kontrolerze deleteTest:", error);
      res.status(500).json({
        success: false,
        message: "Wewnętrzny błąd serwera",
      });
    }
  },
};

module.exports = testController;
