const { jwtDecrypt } = require("jose");
const { createSecretKey } = require("node:crypto");
const config = {
  secret: process.env.JWE_SECRET,
  expiresIn: process.env.JWT_EXPIRES_IN || "24h",
  issuer: "express-jwt-api",
  audience: "express-jwt-app",
};

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization; // <--- Tutaj pobiera się nagłówek z żądania HTTP

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      // <--- Tutaj się sprawdza czy token jest w tym nagłówku
      return res
        .status(401)
        .json({ message: "No token, authorization denied" });
    }

    const token = authHeader.split(" ")[1]; // <--- Tutaj pobiera się token z nagłówka

    const encryptionKey = createSecretKey(Buffer.from(config.secret)); // <--- Tworzenie klucza deszyfrującego (ładowany jest z enva)

    const { payload } = await jwtDecrypt(token, encryptionKey, {
      // <--- Tu się używa jwtDecrypt do deszyfrowania tokena
      issuer: config.issuer,
      audience: config.audience,
    });
    req.user = payload; // <--- Po udanym odszyfrowaniu zapisuje się dane użytownika w obiekcie req.user
    next(); // <--- Po wszystkim przechodzi się do kolejnego middleware albo do kontrolera
  } catch (err) {
    console.error("Token verification failed:", err.message);
    return res.status(401).json({ message: "Token is not valid" });
  }
};

module.exports = authMiddleware;
