const testModel = require("../models/testModel");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

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

      const courseIdNum = parseInt(courseId);
      const chapterIdNum = parseInt(chapterId);

      const tests = await prisma.tests.findMany({
        where: {
          course_id: courseIdNum,
          chapter_id: chapterIdNum,
        },
        include: {
          _count: {
            select: {
              test_blocks: true,
              user_test_attempts: true,
            },
          },
        },
        orderBy: {
          created_at: "desc",
        },
      });

      return res.status(200).json({
        success: true,
        tests,
      });
    } catch (error) {
      console.error(`Błąd podczas pobierania testów dla rozdziału:`, error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania testów",
        error: error.message,
      });
    }
  },

  createTest: async (req, res) => {
    try {
      const { courseId, chapterId } = req.params;
      const {
        title,
        description,
        pass_threshold,
        time_limit,
        is_course_final,
      } = req.body;

      if (!title || title.trim() === "") {
        return res.status(400).json({
          success: false,
          message: "Tytuł testu jest wymagany",
        });
      }

      if (!courseId || isNaN(parseInt(courseId))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID kursu",
        });
      }

      const author_id = req.user?.id;
      if (!author_id) {
        return res.status(401).json({
          success: false,
          message: "Wymagane uwierzytelnienie",
        });
      }

      const isCourseTest = is_course_final === true || !chapterId;

      const testData = {
        title,
        description,
        pass_threshold,
        time_limit,
        course_id: courseId,
        author_id,
        is_course_final: is_course_final === true,
      };

      if (!isCourseTest && chapterId) {
        testData.chapter_id = chapterId;
      }

      const result = await testModel.createTest(testData);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: result.error || "Nie udało się utworzyć testu",
        });
      }

      const testType = isCourseTest ? "dla całego kursu" : "dla rozdziału";
      res.status(201).json({
        success: true,
        test: result.test,
        message: `Test ${testType} został pomyślnie utworzony`,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze createTest:", error);
      res.status(500).json({
        success: false,
        message: "Wewnętrzny błąd serwera",
      });
    }
  },

  getCourseTests: async (req, res) => {
    try {
      const { courseId } = req.params;

      if (!courseId || isNaN(parseInt(courseId))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID kursu",
        });
      }

      const result = await testModel.getTestsByCourse(courseId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania testów kursu",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        tests: result.tests,
      });
    } catch (error) {
      console.error("Błąd podczas pobierania testów kursu:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania testów kursu",
        error: error.message,
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
