const db = require("./db");

const UserLogsModel = {
  setOperationContext: async (userId) => {
    try {
      await db.query(`SELECT set_operation_context($1)`, [userId || null]);
      return true;
    } catch (error) {
      console.error("Błąd podczas ustawiania kontekstu operacji:", error);
      return false;
    }
  },

  logRoleChange: async (userId, changedByUserId, oldRole, newRole) => {
    try {
      const query = `
        INSERT INTO user_logs(
          user_id, 
          changed_by_user_id, 
          action_type, 
          old_value, 
          new_value
        ) VALUES ($1, $2, 'ROLE_CHANGED', $3, $4)
        RETURNING id
      `;

      const result = await db.query(query, [
        userId,
        changedByUserId,
        oldRole,
        newRole,
      ]);

      return { success: true, logId: result.rows[0].id };
    } catch (error) {
      console.error("Błąd podczas logowania zmiany roli:", error);
      return { success: false, error: error.message };
    }
  },

  getAllLogs: async (filters = {}, page = 1, limit = 20) => {
    try {
      const offset = (page - 1) * limit;
      let params = [limit, offset];
      let whereClause = "";
      let conditions = [];
      let paramIndex = 3;
      let countParams = [];
      let countParamIndex = 1;

      if (filters.userId) {
        conditions.push(`l.user_id = $${paramIndex++}`);
        params.push(filters.userId);
        countParams.push(filters.userId);
      }

      if (filters.actionType) {
        conditions.push(`l.action_type = $${paramIndex++}`);
        params.push(filters.actionType);
        countParams.push(filters.actionType);
      }

      if (filters.fromDate) {
        conditions.push(`l.created_at >= $${paramIndex++}::timestamp`);
        const dateValue =
          filters.fromDate instanceof Date
            ? filters.fromDate.toISOString()
            : filters.fromDate;
        params.push(dateValue);
        countParams.push(dateValue);
      }

      if (filters.toDate) {
        conditions.push(`l.created_at <= $${paramIndex++}::timestamp`);
        const dateValue =
          filters.toDate instanceof Date
            ? filters.toDate.toISOString()
            : filters.toDate;
        params.push(dateValue);
        countParams.push(dateValue);
      }

      if (conditions.length > 0) {
        const countConditions = conditions.map((condition, index) => {
          return condition.replace(/\$\d+/, `$${index + 1}`);
        });
        whereClause = `WHERE ${conditions.join(" AND ")}`;
        countWhereClause = `WHERE ${countConditions.join(" AND ")}`;
      } else {
        countWhereClause = "";
      }

      const query = `
    SELECT 
      l.id, 
      l.user_id, 
      l.changed_by_user_id, 
      l.action_type, 
      l.old_value, 
      l.new_value, 
      l.created_at,
      u.email as user_email,
      u.first_name as user_first_name,
      u.last_name as user_last_name,
      c.email as changed_by_email,
      c.first_name as changed_by_first_name,
      c.last_name as changed_by_last_name
    FROM user_logs l
    LEFT JOIN users u ON l.user_id = u.id
    LEFT JOIN users c ON l.changed_by_user_id = c.id
    ${whereClause}
    ORDER BY l.created_at DESC
    LIMIT $1 OFFSET $2
    `;

      const logsResult = await db.query(query, params);

      const countQuery = `
    SELECT COUNT(*) FROM user_logs l ${countWhereClause}
    `;

      const countResult = await db.query(countQuery, countParams);
      const totalCount = parseInt(countResult.rows[0].count);

      return {
        success: true,
        logs: logsResult.rows,
        pagination: {
          total: totalCount,
          totalPages: Math.ceil(totalCount / limit),
          currentPage: page,
          perPage: limit,
        },
      };
    } catch (error) {
      console.error("Błąd podczas pobierania logów:", error);
      return { success: false, error: error.message };
    }
  },

  getUserLogs: async (userId, page = 1, limit = 20) => {
    try {
      return await UserLogsModel.getAllLogs({ userId }, page, limit);
    } catch (error) {
      console.error(
        `Błąd podczas pobierania logów użytkownika ${userId}:`,
        error
      );
      return { success: false, error: error.message };
    }
  },

  logUserOperation: async (
    userId,
    actionType,
    oldValue = null,
    newValue = null
  ) => {
    try {
      const result = await db.query(
        `SELECT log_user_operation($1, $2, $3, $4) AS log_id`,
        [userId, actionType, oldValue, newValue]
      );

      return { success: true, logId: result.rows[0].log_id };
    } catch (error) {
      console.error(`Błąd podczas logowania operacji ${actionType}:`, error);
      return { success: false, error: error.message };
    }
  },

  getCourseLogs: async (filters = {}, page = 1, limit = 20) => {
    try {
      const offset = (page - 1) * limit;
      let params = [limit, offset];
      let whereClause = "";
      let conditions = [];
      let paramIndex = 3;
      let countParams = [];
      let countParamIndex = 1;

      if (filters.courseId) {
        conditions.push(`l.course_id = $${paramIndex++}`);
        params.push(filters.courseId);
        countParams.push(filters.courseId);
      }

      if (filters.fromDate) {
        conditions.push(`l.created_at >= $${paramIndex++}::timestamp`);
        const dateValue =
          filters.fromDate instanceof Date
            ? filters.fromDate.toISOString()
            : filters.fromDate;
        params.push(dateValue);
        countParams.push(dateValue);
      }

      if (filters.toDate) {
        conditions.push(`l.created_at <= $${paramIndex++}::timestamp`);
        const dateValue =
          filters.toDate instanceof Date
            ? filters.toDate.toISOString()
            : filters.toDate;
        params.push(dateValue);
        countParams.push(dateValue);
      }

      if (conditions.length > 0) {
        const countConditions = conditions.map((condition, index) => {
          return condition.replace(/\$\d+/, `$${index + 1}`);
        });
        whereClause = `WHERE ${conditions.join(" AND ")}`;
        countWhereClause = `WHERE ${countConditions.join(" AND ")}`;
      } else {
        countWhereClause = "";
      }

      const query = `
        SELECT 
          l.id, 
          l.course_id, 
          l.user_id, 
          l.action_type, 
          l.old_value, 
          l.new_value, 
          l.course_title,
          l.action_description,
          l.created_at,
          u.email as user_email,
          u.first_name as user_first_name,
          u.last_name as user_last_name
        FROM course_logs l
        LEFT JOIN users u ON l.user_id = u.id
        ${whereClause}
        ORDER BY l.created_at DESC
        LIMIT $1 OFFSET $2
      `;

      const logsResult = await db.query(query, params);

      const countQuery = `
        SELECT COUNT(*) FROM course_logs l ${countWhereClause}
      `;

      const countResult = await db.query(countQuery, countParams);
      const totalCount = parseInt(countResult.rows[0].count);

      return {
        success: true,
        logs: logsResult.rows,
        pagination: {
          total: totalCount,
          totalPages: Math.ceil(totalCount / limit),
          currentPage: page,
          perPage: limit,
        },
      };
    } catch (error) {
      console.error("Błąd podczas pobierania logów kursów:", error);
      return { success: false, error: error.message };
    }
  },
};

module.exports = UserLogsModel;
