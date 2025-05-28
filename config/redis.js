const { createClient } = require("redis");

const redisClient = createClient({
  url: process.env.REDIS_URL || "redis://localhost:6379",
});

redisClient.on("error", (err) => {
  console.error("Redis connection error:", err);
});

const connectRedis = async () => {
  try {
    await redisClient.connect();
    console.log("Połączono z Redis pomyślnie");
  } catch (error) {
    console.error("Błąd połączenia z Redis:", error);
  }
};

module.exports = { redisClient, connectRedis };
