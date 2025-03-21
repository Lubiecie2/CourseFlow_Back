const { jwtDecrypt } = require("jose");
const { createSecretKey } = require("node:crypto");
const config = {
  secret: process.env.JWE_SECRET,
  jwtSecret: process.env.JWT_SECRET,
  expiresIn: process.env.JWT_EXPIRES_IN || "24h",
  issuer: "express-jwt-api",
  audience: "express-jwt-app",
};

const authMiddleware = async (req, res, next) => {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res
        .status(401)
        .json({ message: "No token, authorization denied" });
    }

    const token = authHeader.split(" ")[1];

    // Create encryption key from environment variable
    const encryptionKey = createSecretKey(Buffer.from(config.secret));

    // Decrypt and verify the JWE token
    const { payload } = await jwtDecrypt(token, encryptionKey, {
      issuer: config.issuer,
      audience: config.audience,
    });

    // Add user from payload to request object
    req.user = payload;
    next();
  } catch (err) {
    console.error("Token verification failed:", err.message);
    return res.status(401).json({ message: "Token is not valid" });
  }
};

module.exports = authMiddleware;
