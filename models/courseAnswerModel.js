const db = require("./db");

const courseAnswerModel = {
  createAnswer: async (data) => {
    try {
      const { content, userId, questionId } = data;

      const query = `
        INSERT INTO course_answers (content, user_id, question_id, created_at, updated_at)
        VALUES ($1, $2, $3, NOW(), NOW())
        RETURNING id, content, user_id, question_id, is_accepted, created_at, updated_at
      `;

      const result = await db.query(query, [content, userId, questionId]);

      if (result.rows.length === 0) {
        return { success: false, error: "Nie udało się utworzyć odpowiedzi" };
      }

      return { success: true, answer: result.rows[0] };
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
        answers: result.rows,
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
};

module.exports = courseAnswerModel;
