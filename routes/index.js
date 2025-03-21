var express = require("express");
var router = express.Router();

const pool = require("./../models/db");

router.get("/", async (req, res, next) => {
  const result = await pool.query("SELECT NOW()");
  const currentTime = result.rows[0].now;
  res.send(`Current time from the database is: ${currentTime}`);
});

module.exports = router;
