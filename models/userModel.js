const db = require("./db");
const bcrypt = require("bcryptjs");

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
      `SELECT u.id, u.email, u.first_name, u.last_name, r.name AS role, r.id AS role_id
       FROM users u
       LEFT JOIN roles r ON u.role_id = r.id
       WHERE u.id = $1`,
      [id]
    );
    return result.rows[0];
  },

  findAll: async () => {
    const result = await db.query(
      `SELECT users.id, users.email, users.first_name, users.last_name, roles.name AS role
       FROM users
       LEFT JOIN roles ON users.role_id = roles.id
       ORDER BY users.id`
    );
    return result.rows;
  },
  deleteById: async (id) => {
    const result = await db.query("DELETE FROM users WHERE id = $1", [id]);
  },
  updateRole: async (id, newRole) => {
    const result = await db.query(
      "UPDATE users SET role = $1 WHERE id = $2 RETURNING id, email, first_name, last_name, role",
      [newRole, id]
    );
    return result.rows[0];
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

    const result = await db.query(
      "INSERT INTO users (email, password, first_name, last_name) VALUES ($1, $2, $3, $4) RETURNING id, email",
      [email, hashedPassword, firstName, lastName]
    );

    return result.rows[0];
  },

  verifyPassword: async (plainPassword, hashedPassword) => {
    return await bcrypt.compare(plainPassword, hashedPassword);
  },

  searchUsers: async (searchQuery) => {
    const query = `
      SELECT u.id, u.email, u.first_name, u.last_name, r.name AS role
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
};

module.exports = User;
