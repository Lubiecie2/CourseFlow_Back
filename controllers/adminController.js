const User = require("../models/userModel");

const adminController = {
  getAllUsers: async (req, res) => {
    try {
      const { query } = req.query;

      if (query && typeof query !== "string") {
        return res.status(400).json({
          error: {
            status: 400,
            message: "Invalid query parameter. 'query' must be a string.",
          },
        });
      }

      if (!query) {
        const users = await User.findAll();
        return res.json(users);
      }

      const users = await User.searchUsers(query);
      return res.json(users);
    } catch (err) {
      console.error("Error fetching users:", err.message);
      res.status(500).json({
        error: {
          status: 500,
          message: "Internal server error. Please try again later.",
        },
      });
    }
  },

  deleteUser: async (req, res) => {
    try {
      const { id } = req.params;

      if (!id || isNaN(Number(id))) {
        return res.status(400).json({
          error: {
            status: 400,
            message: "Invalid user ID. It must be a numeric value.",
          },
        });
      }

      const user = await User.findById(id);
      if (!user) {
        return res.status(404).json({
          error: {
            status: 404,
            message: "User not found.",
          },
        });
      }

      await User.deleteById(id);
      res.status(200).json({ message: "User deleted successfully." });
    } catch (err) {
      console.error("Error deleting user:", err.message);
      res.status(500).json({
        error: {
          status: 500,
          message: "Internal server error. Please try again later.",
        },
      });
    }
  },

  updateUserRole: async (req, res) => {
    try {
      const { id } = req.params;
      const { role } = req.body;

      if (!id || isNaN(Number(id))) {
        return res.status(400).json({
          error: {
            status: 400,
            message: "Invalid user ID. It must be a numeric value.",
          },
        });
      }

      if (!["user", "admin"].includes(role)) {
        return res.status(400).json({
          error: {
            status: 400,
            message: "Invalid role. Allowed values: 'user', 'admin'.",
          },
        });
      }

      const user = await User.findById(id);
      if (!user) {
        return res.status(404).json({
          error: {
            status: 404,
            message: "User not found.",
          },
        });
      }

      const updatedUser = await User.updateRole(id, role);
      res.status(200).json(updatedUser);
    } catch (err) {
      console.error("Error updating user role:", err.message);
      res.status(500).json({
        error: {
          status: 500,
          message: "Internal server error. Please try again later.",
        },
      });
    }
  },
};

module.exports = adminController;
