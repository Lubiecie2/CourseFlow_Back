const db = require("./db");

const userProfileModel = {
  getUserStats: async (userId) => {
    try {
      const query = `
        SELECT 
          (SELECT COUNT(*) FROM user_courses WHERE user_id = $1) AS enrolled_courses,
          (SELECT COUNT(DISTINCT uta.test_id) 
           FROM user_test_attempts uta
           JOIN tests t ON uta.test_id = t.id
           WHERE uta.user_id = $1 
           AND uta.passed = true 
           AND t.is_course_final = true) AS completed_courses,
          (SELECT COUNT(*) FROM user_test_attempts WHERE user_id = $1 AND passed = true) AS completed_tests,
          (SELECT COUNT(*) FROM certificates WHERE user_id = $1) AS certificates_earned
      `;

      const result = await db.query(query, [userId]);

      if (result.rows.length === 0) {
        return {
          success: false,
          message: "Nie udało się pobrać statystyk użytkownika",
        };
      }

      return {
        success: true,
        stats: {
          enrolledCourses: parseInt(result.rows[0].enrolled_courses) || 0,
          completedCourses: parseInt(result.rows[0].completed_courses) || 0,
          completedTests: parseInt(result.rows[0].completed_tests) || 0,
          certificatesEarned: parseInt(result.rows[0].certificates_earned) || 0,
        },
      };
    } catch (error) {
      console.error("Błąd podczas pobierania statystyk użytkownika:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  getUserActivity: async (userId, limit = 10) => {
    try {
      const courseQuery = `
        SELECT 
          c.id AS course_id, 
          c.title, 
          uc.status,
          uc.created_at AS date,
          'course' AS type
        FROM user_courses uc
        JOIN courses c ON uc.course_id = c.id
        WHERE uc.user_id = $1
        ORDER BY uc.created_at DESC
        LIMIT $2
      `;

      const courseResult = await db.query(courseQuery, [userId, limit]);

      const testQuery = `
        SELECT 
          t.id AS test_id, 
          t.title,
          t.course_id,
          uta.passed,
          uta.created_at AS date,
          'test' AS type
        FROM user_test_attempts uta
        JOIN tests t ON uta.test_id = t.id
        WHERE uta.user_id = $1
        ORDER BY uta.created_at DESC
        LIMIT $2
      `;

      const testResult = await db.query(testQuery, [userId, limit]);

      const certQuery = `
        SELECT 
          cert.id, 
          c.id AS course_id,
          c.title,
          cert.certificate_code,
          cert.issued_at AS date,
          'certificate' AS type
        FROM certificates cert
        JOIN courses c ON cert.course_id = c.id
        WHERE cert.user_id = $1
        ORDER BY cert.issued_at DESC
        LIMIT $2
      `;

      const certResult = await db.query(certQuery, [userId, limit]);

      const activities = [
        ...courseResult.rows.map((row) => ({
          type: "course",
          title: row.title,
          date: row.date,
          courseId: row.course_id,
          status: row.status,
        })),
        ...testResult.rows.map((row) => ({
          type: "test",
          title: row.title,
          date: row.date,
          courseId: row.course_id,
          passed: row.passed,
        })),
        ...certResult.rows.map((row) => ({
          type: "certificate",
          title: `Certyfikat: ${row.title}`,
          date: row.date,
          courseId: row.course_id,
          certificateCode: row.certificate_code,
        })),
      ]
        .sort((a, b) => new Date(b.date) - new Date(a.date))
        .slice(0, limit);

      return {
        success: true,
        activities,
      };
    } catch (error) {
      console.error("Błąd podczas pobierania aktywności użytkownika:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  updateUserProfile: async (userId, userData) => {
    try {
      const { firstName, lastName } = userData;

      if (!firstName && !lastName) {
        return {
          success: false,
          message: "Nie podano danych do aktualizacji",
        };
      }

      let query = "UPDATE users SET ";
      const queryParams = [];
      const updates = [];

      if (firstName) {
        queryParams.push(firstName);
        updates.push(`first_name = $${queryParams.length}`);
      }

      if (lastName) {
        queryParams.push(lastName);
        updates.push(`last_name = $${queryParams.length}`);
      }

      queryParams.push(new Date());
      updates.push(`updated_at = $${queryParams.length}`);

      queryParams.push(userId);
      query +=
        updates.join(", ") +
        ` WHERE id = $${queryParams.length} RETURNING id, first_name, last_name, email`;

      const result = await db.query(query, queryParams);

      if (result.rows.length === 0) {
        return {
          success: false,
          message: "Użytkownik nie został znaleziony",
        };
      }

      return {
        success: true,
        user: {
          id: result.rows[0].id,
          firstName: result.rows[0].first_name,
          lastName: result.rows[0].last_name,
          email: result.rows[0].email,
        },
      };
    } catch (error) {
      console.error("Błąd podczas aktualizacji profilu użytkownika:", error);
      return {
        success: false,
        error: error.message,
      };
    }
  },

  deleteUserAccount: async (userId) => {
    const client = await db.beginTransaction();

    try {
      const userQuery = `
      SELECT id FROM users 
      WHERE id = $1
    `;
      const userResult = await client.query(userQuery, [userId]);

      if (userResult.rows.length === 0) {
        await db.rollbackTransaction(client);
        return {
          success: false,
          message: "Użytkownik nie został znaleziony",
        };
      }

      const deleteQueries = [
        `DELETE FROM user_test_answers WHERE attempt_id IN (SELECT id FROM user_test_attempts WHERE user_id = $1)`,
        `DELETE FROM user_test_attempts WHERE user_id = $1`,
        `DELETE FROM user_courses WHERE user_id = $1`,
        `DELETE FROM certificates WHERE user_id = $1`,
        `DELETE FROM course_answers WHERE user_id = $1`,
        `DELETE FROM course_questions WHERE user_id = $1`,
        `DELETE FROM course_notes WHERE user_id = $1`,
        `DELETE FROM notifications WHERE user_id = $1`,
        `DELETE FROM user_logs WHERE user_id = $1`,
        `DELETE FROM users WHERE id = $1`,
      ];

      for (const queryText of deleteQueries) {
        await client.query(queryText, [userId]);
      }

      await db.commitTransaction(client);

      return {
        success: true,
        message: "Konto zostało pomyślnie usunięte",
      };
    } catch (error) {
      if (client) await db.rollbackTransaction(client);
      console.error("Błąd podczas usuwania konta użytkownika:", error);
      return {
        success: false,
        error: error.message || "db is not defined",
      };
    }
  },
};

module.exports = userProfileModel;
