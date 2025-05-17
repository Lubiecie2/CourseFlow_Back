const db = require("./db");

const courseAnswerModel = {
  createAnswer: async (data) => {
    try {
      const { content, userId, questionId } = data;

      const insertQuery = `
        INSERT INTO course_answers (content, user_id, question_id, created_at, updated_at)
        VALUES ($1, $2, $3, NOW(), NOW())
        RETURNING id
      `;

      const insertResult = await db.query(insertQuery, [
        content,
        userId,
        questionId,
      ]);

      if (insertResult.rows.length === 0) {
        return { success: false, error: "Nie udało się utworzyć odpowiedzi" };
      }

      const answerId = insertResult.rows[0].id;

      const fullDataQuery = `
        SELECT 
          a.id, a.content, a.user_id, a.question_id, a.is_accepted, a.created_at, a.updated_at,
          u.first_name, u.last_name, u.email
        FROM course_answers a
        JOIN users u ON a.user_id = u.id
        WHERE a.id = $1
      `;

      const fullDataResult = await db.query(fullDataQuery, [answerId]);

      return { success: true, answer: fullDataResult.rows[0] };
    } catch (error) {
      console.error("Błąd podczas tworzenia odpowiedzi:", error);
      return { success: false, error: error.message };
    }
  },

  getAnswersByQuestionId: async (questionId, page = 1, limit = 10) => {
    try {
      const offset = (page - 1) * limit;

      const countQuery = `
        SELECT COUNT(*) as total FROM course_answers
        WHERE question_id = $1
      `;

      const countResult = await db.query(countQuery, [questionId]);
      const total = parseInt(countResult.rows[0].total);

      const query = `
        SELECT 
          a.id, a.content, a.user_id, a.question_id, a.is_accepted, a.created_at, a.updated_at,
          u.first_name, u.last_name, u.email
        FROM course_answers a
        JOIN users u ON a.user_id = u.id
        WHERE a.question_id = $1
        ORDER BY a.is_accepted DESC, a.created_at DESC
        LIMIT $2 OFFSET $3
      `;

      const result = await db.query(query, [questionId, limit, offset]);

      return {
        success: true,
        answers: result.rows.map((answer) => ({
          ...answer,
          user: {
            id: answer.user_id,
            first_name: answer.first_name,
            last_name: answer.last_name,
            email: answer.email,
          },
        })),
        pagination: {
          total,
          page,
          limit,
          totalPages: Math.ceil(total / limit),
        },
      };
    } catch (error) {
      console.error(
        `Błąd podczas pobierania odpowiedzi dla pytania ${questionId}:`,
        error
      );
      return { success: false, error: error.message };
    }
  },

  getAnswerById: async (id) => {
    try {
      const query = `
        SELECT 
          a.id, a.content, a.user_id, a.question_id, a.is_accepted, a.created_at, a.updated_at,
          u.first_name, u.last_name, u.email
        FROM course_answers a
        JOIN users u ON a.user_id = u.id
        WHERE a.id = $1
      `;

      const result = await db.query(query, [id]);

      if (result.rows.length === 0) {
        return { success: false, message: "Odpowiedź nie została znaleziona" };
      }

      return { success: true, answer: result.rows[0] };
    } catch (error) {
      console.error(`Błąd podczas pobierania odpowiedzi ${id}:`, error);
      return { success: false, error: error.message };
    }
  },

  deleteAnswer: async (answerId, userId, isAdmin = false) => {
    try {
      const checkQuery = `
        SELECT user_id FROM course_answers WHERE id = $1
      `;

      const checkResult = await db.query(checkQuery, [answerId]);

      if (checkResult.rows.length === 0) {
        return {
          success: false,
          message: "Odpowiedź nie została znaleziona",
        };
      }

      const answerUserId = checkResult.rows[0].user_id;

      if (answerUserId !== userId && !isAdmin) {
        return {
          success: false,
          message: "Nie masz uprawnień do usunięcia tej odpowiedzi",
        };
      }

      const deleteQuery = `
        DELETE FROM course_answers 
        WHERE id = $1
        RETURNING id
      `;

      const deleteResult = await db.query(deleteQuery, [answerId]);

      if (deleteResult.rows.length === 0) {
        return {
          success: false,
          message: "Nie udało się usunąć odpowiedzi",
        };
      }

      return {
        success: true,
        message: "Odpowiedź została pomyślnie usunięta",
      };
    } catch (error) {
      console.error(`Błąd podczas usuwania odpowiedzi ${answerId}:`, error);
      return { success: false, error: error.message };
    }
  },

  updateAnswer: async (answerId, content, userId) => {
    try {
      const checkQuery = `
        SELECT user_id FROM course_answers 
        WHERE id = $1
      `;

      const checkResult = await db.query(checkQuery, [answerId]);

      if (checkResult.rows.length === 0) {
        return {
          success: false,
          message: "Odpowiedź nie została znaleziona",
        };
      }

      const answerUserId = checkResult.rows[0].user_id;

      if (answerUserId !== userId) {
        return {
          success: false,
          message: "Nie masz uprawnień do edycji tej odpowiedzi",
        };
      }

      const updateQuery = `
        UPDATE course_answers 
        SET content = $1, updated_at = NOW() 
        WHERE id = $2
        RETURNING id
      `;

      const updateResult = await db.query(updateQuery, [content, answerId]);

      if (updateResult.rows.length === 0) {
        return {
          success: false,
          message: "Nie udało się zaktualizować odpowiedzi",
        };
      }

      const fullDataQuery = `
        SELECT 
          a.id, a.content, a.user_id, a.question_id, a.is_accepted, a.created_at, a.updated_at,
          u.first_name, u.last_name, u.email
        FROM course_answers a
        JOIN users u ON a.user_id = u.id
        WHERE a.id = $1
      `;

      const fullDataResult = await db.query(fullDataQuery, [answerId]);

      const answer = fullDataResult.rows[0];
      const formattedAnswer = {
        ...answer,
        user: {
          id: answer.user_id,
          first_name: answer.first_name,
          last_name: answer.last_name,
          email: answer.email,
        },
      };

      return {
        success: true,
        message: "Odpowiedź została pomyślnie zaktualizowana",
        answer: formattedAnswer,
      };
    } catch (error) {
      console.error(`Błąd podczas aktualizacji odpowiedzi ${answerId}:`, error);
      return { success: false, error: error.message };
    }
  },
};

module.exports = courseAnswerModel;
