const User = require("../models/userModel");
const Role = require("../models/roleModel");
const jweToken = require("../utils/jweToken");

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

      res.status(201).json({
        message: "User created successfully",
        user,
      });
    } catch (err) {
      console.error("Error creating user:", err);

      if (err.code === "23505") {
        return res.status(400).json({ error: "Email already exists" });
      }

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
        permissions: permissions.map((p) => p.name),
      });
    } catch (err) {
      console.error("Get user error:", err.message);
      res.status(500).json({ message: "Server error" });
    }
  },
};

module.exports = authController;
