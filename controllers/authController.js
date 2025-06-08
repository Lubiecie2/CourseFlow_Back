const User = require("../models/userModel");
const Role = require("../models/roleModel");
const db = require("../models/db");
const jweToken = require("../utils/jweToken");
const {
  sendVerificationEmail,
  generateVerificationToken,
  canSendEmail,
  sendPasswordResetEmail,
} = require("../utils/mailer");
const bcrypt = require("bcryptjs");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
const NotificationModel = require("../models/notificationModel");
const cacheService = require("../services/cacheServices");
const USERS_CACHE_KEY = "users:all";

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

      const USERS_CACHE_KEY = "admin:all_users";
      await cacheService.invalidate(USERS_CACHE_KEY);

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

      await db.query("UPDATE users SET last_login = NOW() WHERE id = $1", [
        user.id,
      ]);

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

      if (user.first_login) {
        await NotificationModel.createNotificationWelcome(
          user.id,
          "Witaj w CourseFlow!",
          "Dziękujemy za dołączenie do naszej platformy. Sprawdź dostępne kursy i rozpocznij swoją podróż edukacyjną!",
          "WELCOME"
        );
        await prisma.users.update({
          where: { id: user.id },
          data: { first_login: false },
        });
      }

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

      const token = await User.getVerificationToken(user.id);
      if (!token) {
        return res.status(400).json({ error: "No verification token found" });
      }

      const isMatch = await User.verifyToken(token.verification_token, code);
      if (!isMatch) {
        return res.status(400).json({ error: "Invalid verification code" });
      }

      if (User.isTokenExpired(token.expires_at)) {
        return res.status(400).json({ error: "Verification code expired" });
      }

      await User.resetVerificationToken(user.id);
      await User.deleteVerificationToken(token.id);
      await User.verifyUser(user.id);

      res.status(200).json({ message: "User verified successfully" });
    } catch (err) {
      console.error("Error verifying user:", err);
      res.status(500).json({ error: "Internal Server Error" });
    }
  },

  resendCode: async (req, res) => {
    try {
      const { email } = req.body;
      const ipAddress = req.ip;

      if (!email) {
        return res.status(400).json({ error: "Missing email" });
      }

      const user = await User.findByEmail(email);
      if (!user) {
        return res.status(400).json({ error: "User not found" });
      }

      if (!user.is_verified) {
        if (!canSendEmail(ipAddress, email)) {
          return res.status(429).json({
            error:
              "Proszę poczekać 2 minuty przed ponownym wysłaniem wiadomości e-mail",
          });
        }

        const { plainToken } = await User.updateVerificationTokenForResend(
          user.id
        );

        if (!plainToken) {
          console.error("Nie udało się wygenerować plainToken w resendCode");
          return res
            .status(500)
            .json({ error: "Internal server error during token generation" });
        }

        console.log("Wysyłanie nowego kodu weryfikacyjnego:", plainToken);

        try {
          await sendVerificationEmail(email, plainToken, ipAddress);
          res
            .status(200)
            .json({ message: "Verification code resent successfully" });
        } catch (err) {
          if (err.message && err.message.includes("Proszę poczekać")) {
            return res.status(429).json({ error: err.message });
          }
          console.error("Error sending verification email:", err);
          res.status(500).json({ error: "Failed to send verification email" });
        }
      } else {
        res.status(400).json({ error: "User is already verified" });
      }
    } catch (err) {
      console.error("Error resending verification code:", err);
      res.status(500).json({ error: "Internal Server Error" });
    }
  },

  resetPasswordRequest: async (req, res) => {
    try {
      const { email } = req.body;
      const ipAddress = req.ip;

      if (!email) {
        return res.status(400).json({ message: "Email jest wymagany" });
      }

      const user = await User.findByEmail(email);

      if (!user) {
        return res.status(200).json({
          message:
            "Jeśli podany adres email istnieje w naszej bazie, wysłaliśmy na niego link do resetowania hasła.",
        });
      }

      const plainToken = generateVerificationToken();
      const tokenSalt = await bcrypt.genSalt(10);
      const hashedToken = await bcrypt.hash(plainToken, tokenSalt);

      await prisma.users.update({
        where: { id: user.id },
        data: {
          reset_password_token: hashedToken,
          reset_password_expires: new Date(Date.now() + 3600000),
          updated_at: new Date(),
        },
      });

      const frontendBaseUrl =
        process.env.FRONTEND_URL || "http://localhost:3000";
      const resetUrl = `${frontendBaseUrl}/setNewPassword?token=${plainToken}`;

      try {
        await sendPasswordResetEmail(user.email, resetUrl, ipAddress);
      } catch (emailError) {
        if (
          emailError.message &&
          emailError.message.includes("Proszę poczekać")
        ) {
          return res.status(429).json({ message: emailError.message });
        }
        console.error("Błąd wysyłania emaila resetującego hasło:", emailError);
        return res.status(500).json({ message: "Błąd wysyłania emaila" });
      }

      return res.status(200).json({
        message:
          "Jeśli podany adres email istnieje w naszej bazie, wysłaliśmy na niego link do resetowania hasła.",
      });
    } catch (error) {
      console.error("Błąd resetowania hasła:", error);
      return res.status(500).json({ message: "Wystąpił błąd serwera" });
    }
  },

  resetPassword: async (req, res) => {
    try {
      const { token, newPassword } = req.body;

      if (!token || !newPassword) {
        return res
          .status(400)
          .json({ message: "Token i nowe hasło są wymagane" });
      }

      if (newPassword.length < 8) {
        return res
          .status(400)
          .json({ message: "Hasło musi mieć co najmniej 8 znaków" });
      }

      const users = await prisma.users.findMany({
        where: {
          reset_password_token: { not: null },
          reset_password_expires: { gt: new Date() },
        },
      });

      let userToUpdate = null;
      for (const user of users) {
        const isMatch = await bcrypt.compare(token, user.reset_password_token);
        if (isMatch) {
          userToUpdate = user;
          break;
        }
      }

      if (!userToUpdate) {
        return res
          .status(400)
          .json({ message: "Token jest nieprawidłowy lub wygasł" });
      }

      const tokenSalt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(newPassword, tokenSalt);

      await prisma.users.update({
        where: { id: userToUpdate.id },
        data: {
          password: hashedPassword,
          reset_password_token: null,
          reset_password_expires: null,
          last_password_change: new Date(),
          updated_at: new Date(),
        },
      });

      return res
        .status(200)
        .json({ message: "Hasło zostało pomyślnie zmienione" });
    } catch (error) {
      console.error("Błąd resetowania hasła:", error);
      return res.status(500).json({ message: "Wystąpił błąd serwera" });
    }
  },
};

module.exports = authController;
