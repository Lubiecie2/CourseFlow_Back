const { EncryptJWT } = require("jose");
const { createSecretKey } = require("node:crypto");
const config = {
  secret: process.env.JWE_SECRET,
  expiresIn: process.env.JWT_EXPIRES_IN || "24h",
  issuer: "express-jwt-api",
  audience: "express-jwt-app",
};

async function createToken(payload) {
  const encryptionKey = createSecretKey(Buffer.from(config.secret));

  const expiresIn = config.expiresIn;

  const expirationTime = expiresIn.endsWith("h")
    ? parseInt(expiresIn.slice(0, -1)) * 60 * 60
    : 24 * 60 * 60;

  return new EncryptJWT(payload)
    .setProtectedHeader({ alg: "dir", enc: "A256GCM" })
    .setIssuedAt()
    .setIssuer(config.issuer)
    .setAudience(config.audience)
    .setExpirationTime(Math.floor(Date.now() / 1000) + expirationTime)
    .encrypt(encryptionKey);
}

module.exports = {
  createToken,
};
