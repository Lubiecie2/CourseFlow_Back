require("dotenv").config();
const { Pool } = require("pg");

const pool = new Pool({
  connectionString: process.env.DB_CONNECTION_STRING,
});

pool.on("connect", () => {
  console.log("Connected to the PostgreSQL database.");
});

pool.on("error", (err) => {
  console.error("Unexpected error on idle client", err);
  process.exit(-1);
});

pool.query("SELECT NOW()", (err, res) => {
  if (err) {
    console.error("Database connection error:", err.stack);
  } else {
    console.log("Database connected successfully");
  }
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool,
};
