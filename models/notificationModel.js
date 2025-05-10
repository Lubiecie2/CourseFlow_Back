const db = require("./db");

const NotificationModel = {
  getUserNotifications: async (userId, page = 1, limit = 10) => {
    try {
      const offset = (page - 1) * limit;
      const params = [userId, limit, offset];

      const query = `
        SELECT 
          n.id, 
          n.title, 
          n.message, 
          n.type, 
          n.related_entity_id, 
          n.is_read,
          n.created_at,
          c.title as course_title
        FROM notifications n
        LEFT JOIN courses c ON n.related_entity_id = c.id AND n.type = 'NEW_COURSE'
        WHERE n.user_id = $1
        ORDER BY n.created_at DESC
        LIMIT $2 OFFSET $3
      `;

      const countQuery = `
        SELECT COUNT(*) FROM notifications 
        WHERE user_id = $1
      `;

      const notificationsResult = await db.query(query, params);
      const countResult = await db.query(countQuery, [userId]);

      const totalCount = parseInt(countResult.rows[0].count);

      return {
        success: true,
        notifications: notificationsResult.rows,
        pagination: {
          total: totalCount,
          totalPages: Math.ceil(totalCount / limit),
          currentPage: page,
          perPage: limit,
        },
      };
    } catch (error) {
      console.error("Błąd podczas pobierania powiadomień:", error);
      return { success: false, error: error.message };
    }
  },

  getUnreadCount: async (userId) => {
    try {
      const result = await db.query(
        "SELECT COUNT(*) AS count FROM notifications WHERE user_id = $1 AND is_read = FALSE",
        [userId]
      );

      return {
        success: true,
        count: parseInt(result.rows[0].count),
      };
    } catch (error) {
      console.error(
        "Błąd podczas liczenia nieprzeczytanych powiadomień:",
        error
      );
      return { success: false, error: error.message };
    }
  },

  markAllAsRead: async (userId) => {
    try {
      await db.query(
        `UPDATE notifications 
         SET is_read = TRUE 
         WHERE user_id = $1 AND is_read = FALSE`,
        [userId]
      );

      return { success: true };
    } catch (error) {
      console.error(
        "Błąd podczas oznaczania powiadomień jako przeczytane:",
        error
      );
      return { success: false, error: error.message };
    }
  },

  createNotificationForAllUsers: async (
    title,
    message,
    type = "ADMIN_ANNOUNCEMENT"
  ) => {
    try {
      const usersResult = await db.query("SELECT id FROM users");

      if (usersResult.rows.length === 0) {
        return {
          success: true,
          message: "Brak użytkowników do powiadomienia",
        };
      }

      const valuesSets = usersResult.rows
        .map((user, index) => {
          return `($${index * 5 + 1}, $${index * 5 + 2}, $${index * 5 + 3}, $${
            index * 5 + 4
          }, $${index * 5 + 5})`;
        })
        .join(", ");

      const params = [];
      usersResult.rows.forEach((user) => {
        params.push(user.id, title, message, type, new Date());
      });

      const query = `
    INSERT INTO notifications (user_id, title, message, type, created_at)
    VALUES ${valuesSets}
  `;

      await db.query(query, params);

      return {
        success: true,
        message: `Powiadomienia utworzone dla ${usersResult.rows.length} użytkowników`,
      };
    } catch (error) {
      console.error(
        "Błąd podczas tworzenia powiadomień dla wszystkich użytkowników:",
        error
      );
      return { success: false, error: error.message };
    }
  },
};

module.exports = NotificationModel;
