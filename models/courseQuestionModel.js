const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
const db = require("./db");

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

  // ================================================================================
  // ==============================   TRANSAKCJA   ==================================
  // ================================================================================

  deleteQuestion: async (questionId, userId, isAdmin = false) => {
    const client = await db.beginTransaction();

    try {
      const questionQuery = `
      SELECT user_id FROM course_questions
      WHERE id = $1
    `;
      const questionResult = await client.query(questionQuery, [questionId]);

      if (questionResult.rows.length === 0) {
        await db.rollbackTransaction(client);
        return {
          success: false,
          message: "Pytanie nie zostało znalezione",
        };
      }

      const questionUserId = questionResult.rows[0].user_id;

      if (questionUserId !== userId && !isAdmin) {
        await db.rollbackTransaction(client);
        return {
          success: false,
          message: "Nie masz uprawnień do usunięcia tego pytania",
        };
      }

      const deleteAnswersQuery = `
      DELETE FROM course_answers
      WHERE question_id = $1
    `;
      await client.query(deleteAnswersQuery, [questionId]);

      const deleteQuestionQuery = `
      DELETE FROM course_questions
      WHERE id = $1
    `;
      await client.query(deleteQuestionQuery, [questionId]);

      await db.commitTransaction(client);

      return {
        success: true,
        message:
          "Pytanie zostało pomyślnie usunięte wraz ze wszystkimi odpowiedziami",
      };
    } catch (error) {
      await db.rollbackTransaction(client);
      console.error(`Błąd podczas usuwania pytania ${questionId}:`, error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  // ================================================================================
  // ==============================   TRANSAKCJA   ==================================
  // ================================================================================

  updateQuestion: async (questionId, data, userId) => {
    const client = await db.beginTransaction();

    try {
      const { title, content, courseId } = data;

      const questionQuery = `
        SELECT user_id FROM course_questions
        WHERE id = $1
      `;

      const questionResult = await client.query(questionQuery, [questionId]);

      if (questionResult.rows.length === 0) {
        await db.rollbackTransaction(client);
        return {
          success: false,
          message: "Pytanie nie zostało znalezione",
        };
      }

      const questionUserId = questionResult.rows[0].user_id;

      if (questionUserId !== userId) {
        await db.rollbackTransaction(client);
        return {
          success: false,
          message: "Nie masz uprawnień do edycji tego pytania",
        };
      }

      const updateQuery = `
        UPDATE course_questions 
        SET title = $1, content = $2, updated_at = NOW(), course_id = $3
        WHERE id = $4
        RETURNING id, title, content, user_id, course_id, created_at, updated_at, views
      `;

      const updateResult = await client.query(updateQuery, [
        title,
        content,
        courseId ? parseInt(courseId) : null,
        questionId,
      ]);

      await db.commitTransaction(client);

      return {
        success: true,
        message: "Pytanie zostało pomyślnie zaktualizowane",
        question: updateResult.rows[0],
      };
    } catch (error) {
      await db.rollbackTransaction(client);
      console.error(`Błąd podczas aktualizacji pytania ${questionId}:`, error);
      return {
        success: false,
        error: error.message,
      };
    }
  },
};

module.exports = courseQuestionModel;
