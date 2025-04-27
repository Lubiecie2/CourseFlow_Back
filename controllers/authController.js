const User = require("../models/userModel");
const Role = require("../models/roleModel");
const db = require("../models/db");
const jweToken = require("../utils/jweToken");
const {
  sendVerificationEmail,
  generateVerificationToken,
} = require("../utils/mailer");
const bcrypt = require("bcryptjs");

const verificationCodes = new Map();

const authController = {
  register: async (req, res) => {
    try {
      const { email, password, firstName, lastName } = req.body;
      if (!email || !password || !firstName || !lastName) {
        return res.status(400).json({ error: "Missing required fields" });
      }

      const userExists = await User.exists(email);
      if (userExists) {
        return res.status(400).json({ message: "User already exists" });
      }

      const user = await User.create(email, password, firstName, lastName);

      await db.query("DELETE FROM verification_tokens WHERE user_id = $1", [
        user.id,
      ]);

      const plainToken = generateVerificationToken();
      const tokenSalt = await bcrypt.genSalt(10);
      const tokenHash = await bcrypt.hash(plainToken, tokenSalt);

      const tokenId = await User.createVerificationToken(user.id, tokenHash);

      await User.updateVerificationTokenId(user.id, tokenId);

      await sendVerificationEmail(email, plainToken);

      res.status(201).json({
        message: "User created. A verification email has been sent.",
        user,
      });
    } catch (err) {
      console.error("Error creating user:", err);
      res.status(500).json({ error: "Internal Server Error" });
    }
  },

  login: async (req, res) => {
    try {
      const { email, password } = req.body;

      const user = await User.findByEmail(email);

      if (!user) {
        return res.status(401).json({ error: "Invalid email or password" });
      }

      const passwordMatch = await User.verifyPassword(password, user.password);

      if (!passwordMatch) {
        return res.status(401).json({ error: "Invalid email or password" });
      }

      console.log("User found:", user);

      if (!user.is_verified) {
        return res.status(200).json({
          message: "User not verified",
          user: {
            id: user.id,
            email: user.email,
            is_verified: false,
          },
        });
      }

      const token = await jweToken.createToken({
        id: user.id,
        email: user.email,
        role: user.role,
      });

      const hours = 24;
      res
        .cookie("access_token", token, {
          httpOnly: false,
          secure: true,
          maxAge: hours * 60 * 1000 * 60,
        })
        .status(200)
        .json({
          message: "Login successful",
          token,
          user: {
            id: user.id,
            firstName: user.first_name,
            lastName: user.last_name,
            email: user.email,
            role: user.role,
            is_verified: true,
          },
          token,
        });
    } catch (err) {
      console.error("Error during login:", err);
      res.status(500).json({ error: "Internal Server Error" });
    }
  },

  getUser: async (req, res) => {
    try {
      if (!req.user || !req.user.id) {
        return res
          .status(401)
          .json({ message: "Unauthorized - Invalid or missing token" });
      }

      const user = await User.findById(req.user.id);

      if (!user) {
        return res.status(404).json({ message: "User not found" });
      }

      const permissions = await Role.getPermissionByRole(user.role_id);

      console.log("User permissions:", user.role);

      res.json({
        id: user.id,
        firstName: user.first_name,
        lastName: user.last_name,
        email: user.email,
        role: user.role,
        createdAt: user.created_at
          ? new Date(user.created_at).toLocaleString("pl-PL", {
              day: "2-digit",
              month: "2-digit",
              year: "numeric",
            })
          : null,
        permissions: permissions.map((p) => p.name),
      });
    } catch (err) {
      console.error("Get user error:", err.message);
      res.status(500).json({ message: "Server error" });
    }
  },

  verifyRegistration: async (req, res) => {
    try {
      const { email, code } = req.body;
      if (!email || !code) {
        return res.status(400).json({ error: "Missing email or code" });
      }

      const user = await User.findByEmail(email);
      if (!user) {
        return res.status(400).json({ error: "User not found" });
      }

      const tokenData = await db.query(
        "SELECT * FROM verification_tokens WHERE user_id = $1",
        [user.id]
      );

      if (tokenData.rows.length === 0) {
        return res.status(400).json({ error: "No verification token found" });
      }

      const token = tokenData.rows[0];

      const isMatch = await bcrypt.compare(code, token.verification_token);
      if (!isMatch) {
        return res.status(400).json({ error: "Invalid verification code" });
      }

      if (new Date(token.expires_at) < new Date()) {
        return res.status(400).json({ error: "Verification code expired" });
      }

      await db.query(
        "UPDATE users SET verification_token_id = NULL WHERE id = $1",
        [user.id]
      );

      await db.query("DELETE FROM verification_tokens WHERE id = $1", [
        token.id,
      ]);

      await db.query("UPDATE users SET is_verified = true WHERE id = $1", [
        user.id,
      ]);

      res.status(200).json({ message: "User verified successfully" });
    } catch (err) {
      console.error("Error verifying user:", err);
      res.status(500).json({ error: "Internal Server Error" });
    }
  },

  resendCode: async (req, res) => {
    try {
      const { email } = req.body;
      if (!email) {
        return res.status(400).json({ error: "Missing email" });
      }

      const user = await User.findByEmail(email);
      if (!user) {
        return res.status(400).json({ error: "User not found" });
      }

      if (!user.is_verified) {
        const plainToken = generateVerificationToken();
        const tokenSalt = await bcrypt.genSalt(10);
        const tokenHash = await bcrypt.hash(plainToken, tokenSalt);
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

        const existingToken = await db.query(
          "SELECT id FROM verification_tokens WHERE user_id = $1",
          [user.id]
        );

        if (existingToken.rows.length > 0) {
          await db.query(
            "UPDATE verification_tokens SET verification_token = $1, expires_at = $2, created_at = NOW() WHERE id = $3",
            [tokenHash, expiresAt, existingToken.rows[0].id]
          );
        } else {
          const newToken = await db.query(
            `INSERT INTO verification_tokens (user_id, verification_token, expires_at, created_at) 
             VALUES ($1, $2, $3, NOW()) RETURNING id`,
            [user.id, tokenHash, expiresAt]
          );
          await User.updateVerificationTokenId(user.id, newToken.rows[0].id);
        }

        await sendVerificationEmail(email, plainToken);

        res
          .status(200)
          .json({ message: "Verification code resent successfully" });
      } else {
        res.status(400).json({ error: "User is already verified" });
      }
    } catch (err) {
      console.error("Error resending verification code:", err);
      res.status(500).json({ error: "Internal Server Error" });
    }
  },
};

module.exports = authController;
