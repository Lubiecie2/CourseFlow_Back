const db = require("./db");
const bcrypt = require("bcryptjs");

const User = {
  findByEmail: async (email) => {
    const result = await db.query("SELECT * FROM users WHERE email = $1", [
      email,
    ]);
    return result.rows[0];
  },

  findById: async (id) => {
    const result = await db.query(
      "SELECT id, email, first_name, role, last_name FROM users WHERE id = $1",
      [id]
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
};

module.exports = User;
