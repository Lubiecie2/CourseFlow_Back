const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const courseQuestionModel = {
  getQuestionsByCourse: async (courseId, limit = 10, offset = 0) => {
    try {
      const questions = await prisma.course_questions.findMany({
        where: { course_id: parseInt(courseId) },
        include: {
          users: {
            select: {
              id: true,
              email: true,
              first_name: true,
              last_name: true,
            },
          },
        },
        orderBy: { created_at: "desc" },
        take: limit,
        skip: offset,
      });

      const total = await prisma.course_questions.count({
        where: { course_id: parseInt(courseId) },
      });

      return {
        success: true,
        questions,
        total,
      };
    } catch (error) {
      console.error("Błąd podczas pobierania pytań:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  getAllQuestions: async (limit = 10, offset = 0) => {
    try {
      const questions = await prisma.course_questions.findMany({
        include: {
          users: {
            select: {
              id: true,
              first_name: true,
              last_name: true,
            },
          },
          courses: {
            select: {
              id: true,
              title: true,
            },
          },
          _count: {
            select: {
              course_answers: true,
            },
          },
        },
        orderBy: { created_at: "desc" },
        take: limit,
        skip: offset,
      });

      const total = await prisma.course_questions.count();

      return {
        success: true,
        questions,
        total,
      };
    } catch (error) {
      console.error("Błąd podczas pobierania wszystkich pytań:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  getQuestionById: async (questionId) => {
    try {
      const question = await prisma.course_questions.findUnique({
        where: { id: parseInt(questionId) },
        include: {
          users: {
            select: {
              id: true,
              email: true,
              first_name: true,
              last_name: true,
            },
          },
          courses: {
            select: {
              id: true,
              title: true,
            },
          },
        },
      });

      if (!question) {
        return {
          success: false,
          error: "Pytanie nie istnieje",
        };
      }

      await prisma.course_questions.update({
        where: { id: parseInt(questionId) },
        data: { views: { increment: 1 } },
      });

      return {
        success: true,
        question,
      };
    } catch (error) {
      console.error("Błąd podczas pobierania pytania:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  createQuestion: async (data) => {
    try {
      const { title, content, userId, courseId } = data;

      const question = await prisma.course_questions.create({
        data: {
          title,
          content,
          user_id: parseInt(userId),
          course_id: courseId ? parseInt(courseId) : null,
          created_at: new Date(),
          updated_at: new Date(),
        },
      });

      return {
        success: true,
        question,
      };
    } catch (error) {
      console.error("Błąd podczas tworzenia pytania:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  deleteQuestion: async (questionId, userId, isAdmin = false) => {
    try {
      const question = await prisma.course_questions.findUnique({
        where: { id: parseInt(questionId) },
        select: { user_id: true },
      });

      if (!question) {
        return {
          success: false,
          message: "Pytanie nie zostało znalezione",
        };
      }

      const questionUserId = question.user_id;

      if (questionUserId !== userId && !isAdmin) {
        return {
          success: false,
          message: "Nie masz uprawnień do usunięcia tego pytania",
        };
      }

      await prisma.course_answers.deleteMany({
        where: { question_id: parseInt(questionId) },
      });

      await prisma.course_questions.delete({
        where: { id: parseInt(questionId) },
      });

      return {
        success: true,
        message:
          "Pytanie zostało pomyślnie usunięte wraz ze wszystkimi odpowiedziami",
      };
    } catch (error) {
      console.error(`Błąd podczas usuwania pytania ${questionId}:`, error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  updateQuestion: async (questionId, data, userId) => {
    try {
      const { title, content } = data;

      const question = await prisma.course_questions.findUnique({
        where: { id: parseInt(questionId) },
        select: { user_id: true },
      });

      if (!question) {
        return {
          success: false,
          message: "Pytanie nie zostało znalezione",
        };
      }

      const questionUserId = question.user_id;

      if (questionUserId !== userId) {
        return {
          success: false,
          message: "Nie masz uprawnień do edycji tego pytania",
        };
      }

      const updatedQuestion = await prisma.course_questions.update({
        where: { id: parseInt(questionId) },
        data: {
          title,
          content,
          updated_at: new Date(),
        },
      });

      return {
        success: true,
        message: "Pytanie zostało pomyślnie zaktualizowane",
        question: updatedQuestion,
      };
    } catch (error) {
      console.error(`Błąd podczas aktualizacji pytania ${questionId}:`, error);
      return {
        success: false,
        error: error.message,
      };
    }
  },
};

module.exports = courseQuestionModel;
