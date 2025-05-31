const db = require("./db");
const bcrypt = require("bcryptjs");
const { generateVerificationToken } = require("../utils/mailer");

const User = {
  findByEmail: async (email) => {
    const result = await db.query(
      `SELECT users.*, roles.name AS role
       FROM users
       LEFT JOIN roles ON users.role_id = roles.id
       WHERE users.email = $1`,
      [email]
    );
    return result.rows[0];
  },

  findById: async (id) => {
    const result = await db.query(
      `SELECT u.id, u.email, u.first_name, u.last_name, r.name AS role, r.id AS role_id, u.created_at
       FROM users u
       LEFT JOIN roles r ON u.role_id = r.id
       WHERE u.id = $1`,
      [id]
    );
    return result.rows[0];
  },

  findAll: async () => {
    const result = await db.query(
      `SELECT users.id, users.email, users.first_name, users.last_name, roles.name AS role, roles.id AS role_id
       FROM users
       LEFT JOIN roles ON users.role_id = roles.id
       ORDER BY users.id`
    );
    return result.rows;
  },

  // ================================================================================
  // ==============================   TRANSAKCJA   ==================================
  // ================================================================================
  deleteById: async (id) => {
    const client = await db.beginTransaction();

    try {
      const userResult = await client.query(
        "SELECT * FROM users WHERE id = $1",
        [id]
      );

      if (userResult.rows.length === 0) {
        await db.rollbackTransaction(client);
        return { success: false, message: "Użytkownik nie został znaleziony" };
      }

      await client.query("DELETE FROM users WHERE id = $1", [id]);

      await db.commitTransaction(client);

      return { success: true };
    } catch (error) {
      await db.rollbackTransaction(client);
      console.error("Error deleting user:", error);
      return { success: false, error: error.message };
    }
  },

  // ================================================================================
  // ==============================   TRANSAKCJA   ==================================
  // ================================================================================
  updateRole: async (id, newRoleId) => {
    const client = await db.beginTransaction();

    try {
      const userResult = await client.query(
        "SELECT * FROM users WHERE id = $1",
        [id]
      );

      if (userResult.rows.length === 0) {
        await db.rollbackTransaction(client);
        return { success: false, message: "Użytkownik nie został znaleziony" };
      }

      const roleResult = await client.query(
        "SELECT * FROM roles WHERE id = $1",
        [newRoleId]
      );

      if (roleResult.rows.length === 0) {
        await db.rollbackTransaction(client);
        return { success: false, message: "Rola nie została znaleziona" };
      }

      const updateResult = await client.query(
        "UPDATE users SET role_id = $1, updated_at = NOW() WHERE id = $2 RETURNING id, email, first_name, last_name, role_id",
        [newRoleId, id]
      );

      await db.commitTransaction(client);

      return { success: true, user: updateResult.rows[0] };
    } catch (error) {
      await db.rollbackTransaction(client);
      console.error("Error updating user role:", error);
      return { success: false, error: error.message };
    }
  },

  exists: async (email) => {
    const result = await db.query("SELECT * FROM users WHERE email = $1", [
      email,
    ]);
    return result.rows.length > 0;
  },

  create: async (email, password, firstName, lastName) => {
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    const query = `
      INSERT INTO users (email, password, first_name, last_name, is_verified)
      VALUES ($1, $2, $3, $4, false)
      RETURNING id, email, is_verified
    `;
    const values = [email, hashedPassword, firstName, lastName];
    const result = await db.query(query, values);
    return result.rows[0];
  },

  verifyPassword: async (plainPassword, hashedPassword) => {
    return await bcrypt.compare(plainPassword, hashedPassword);
  },

  searchUsers: async (searchQuery) => {
    const query = `
      SELECT u.id, u.email, u.first_name, u.last_name, r.name AS role, r.id AS role_id
      FROM users u
      LEFT JOIN roles r ON u.role_id = r.id
      WHERE u.email LIKE $1
         OR u.first_name LIKE $1
         OR u.last_name LIKE $1
         OR r.name LIKE $1
      ORDER BY u.id;
    `;
    const result = await db.query(query, [`%${searchQuery}%`]);
    return result.rows;
  },

  getAllRoles: async () => {
    const result = await db.query("SELECT id, name FROM roles");
    return result.rows;
  },

  verifyUser: async (userId) => {
    const result = await db.query(
      "UPDATE users SET is_verified = true WHERE id = $1 RETURNING id, email, is_verified",
      [userId]
    );
    return result.rows[0];
  },

  createVerificationToken: async (userId, tokenHash) => {
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    const result = await db.query(
      `INSERT INTO verification_tokens (user_id, verification_token, expires_at) 
     VALUES ($1, $2, $3) RETURNING id`,
      [userId, tokenHash, expiresAt]
    );
    return result.rows[0].id;
  },

  updateVerificationTokenId: async (userId, tokenId) => {
    const result = await db.query(
      "UPDATE users SET verification_token_id = $1 WHERE id = $2 RETURNING id",
      [tokenId, userId]
    );
    return result.rows[0];
  },

  updateVerificationTokenForResend: async (userId) => {
    const plainToken = generateVerificationToken();
    const salt = await bcrypt.genSalt(10);
    const tokenHash = await bcrypt.hash(plainToken, salt);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    const existingToken = await db.query(
      "SELECT id FROM verification_tokens WHERE user_id = $1",
      [userId]
    );

    let tokenId;

    if (existingToken.rows.length > 0) {
      await db.query(
        "UPDATE verification_tokens SET verification_token = $1, expires_at = $2, created_at = NOW() WHERE id = $3",
        [tokenHash, expiresAt, existingToken.rows[0].id]
      );
      tokenId = existingToken.rows[0].id;
    } else {
      const newToken = await db.query(
        `INSERT INTO verification_tokens (user_id, verification_token, expires_at) 
         VALUES ($1, $2, $3) RETURNING id`,
        [userId, tokenHash, expiresAt]
      );
      tokenId = newToken.rows[0].id;
    }

    await db.query(
      "UPDATE users SET verification_token_id = $1 WHERE id = $2",
      [tokenId, userId]
    );

    return { tokenId, plainToken };
  },

  getVerificationToken: async (userId) => {
    const result = await db.query(
      "SELECT * FROM verification_tokens WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1",
      [userId]
    );
    return result.rows[0];
  },

  deleteVerificationToken: async (tokenId) => {
    await db.query("DELETE FROM verification_tokens WHERE id = $1", [tokenId]);
  },

  resetVerificationToken: async (userId) => {
    await db.query(
      "UPDATE users SET verification_token_id = NULL WHERE id = $1",
      [userId]
    );
  },

  verifyToken: async (tokenHash, userCode) => {
    return await bcrypt.compare(userCode, tokenHash);
  },

  isTokenExpired: (tokenExpiresAt) => {
    return new Date(tokenExpiresAt) < new Date();
  },
  getAdminStats: async () => {
    try {
      const monthAgo = new Date();
      monthAgo.setMonth(monthAgo.getMonth() - 1);

      const activeUsersQuery = `
        SELECT COUNT(DISTINCT id) as active_users 
        FROM users 
        WHERE last_login > $1
      `;

      const activeUsersResult = await db.query(activeUsersQuery, [monthAgo]);
      const activeUsers = parseInt(
        activeUsersResult.rows[0]?.active_users || "0"
      );

      const totalUsersQuery = `SELECT COUNT(*) as count FROM users`;
      const totalUsersResult = await db.query(totalUsersQuery);
      const totalUsers = parseInt(totalUsersResult.rows[0]?.count || "0");

      const totalCoursesQuery = `SELECT COUNT(*) as count FROM courses`;
      const totalCoursesResult = await db.query(totalCoursesQuery);
      const totalCourses = parseInt(totalCoursesResult.rows[0]?.count || "0");

      const totalTestsQuery = `SELECT COUNT(*) as count FROM tests`;
      const totalTestsResult = await db.query(totalTestsQuery);
      const totalTests = parseInt(totalTestsResult.rows[0]?.count || "0");

      const totalChaptersQuery = `SELECT COUNT(*) as count FROM chapters`;
      const totalChaptersResult = await db.query(totalChaptersQuery);
      const totalChapters = parseInt(totalChaptersResult.rows[0]?.count || "0");

      const totalCertificatesQuery = `SELECT COUNT(*) as count FROM certificates`;
      const totalCertificatesResult = await db.query(totalCertificatesQuery);
      const totalCertificates = parseInt(
        totalCertificatesResult.rows[0]?.count || "0"
      );

      const newUsersQuery = `
        SELECT COUNT(*) as count FROM users
        WHERE created_at > $1
      `;
      const newUsersResult = await db.query(newUsersQuery, [monthAgo]);
      const newUsers = parseInt(newUsersResult.rows[0]?.count || "0");

      return {
        success: true,
        data: {
          totalUsers,
          activeUsers,
          totalCourses,
          totalTests,
          totalChapters,
          totalCertificates,
          newUsers,
        },
      };
    } catch (error) {
      console.error("Błąd podczas pobierania statystyk administratora:", error);
      return {
        success: false,
        message: "Wystąpił błąd podczas pobierania statystyk",
        error: error.message,
      };
    }
  },
};

module.exports = User;
