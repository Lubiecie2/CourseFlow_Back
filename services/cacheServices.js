const { redisClient } = require("../config/redis");

const cacheService = {
  // ------ Pobieranie danych z cache

  async getOrSet(key, fetchFunction, ttl = 300) {
    try {
      const cachedData = await redisClient.get(key);

      if (cachedData) {
        console.log(`Cache hit: ${key}`);
        return JSON.parse(cachedData);
      }

      const freshData = await fetchFunction();
      await redisClient.setEx(key, ttl, JSON.stringify(freshData));
      return freshData;
    } catch (error) {
      console.error(`Cache error: ${key}`, error);
      return await fetchFunction();
    }
  },

  // ------ Usuwanie danych z cache

  async invalidate(key) {
    try {
      await redisClient.del(key);
    } catch (error) {
      console.error(`Cache invalidation error: ${key}`, error);
    }
  },
};

module.exports = cacheService;
