const User = require("../models/userModel");

const adminController = {
  getAllUsers: async (req, res) => {
    try {
      const { query } = req.query;

      if (query && typeof query !== "string") {
        return res.status(400).json({
          error: {
            status: 400,
            message:
              "Invalid query parameter, because 'query' must be a string.",
          },
        });
      }

      let users = query ? await User.searchUsers(query) : await User.findAll();
      const roles = await User.getAllRoles();

      return res.json({ users, roles });
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

      const roles = await User.getAllRoles();
      const roleId = roles.find((r) => r.name === role)?.id;

      if (!roleId) {
        return res.status(400).json({
          error: {
            status: 400,
            message: "Invalid role. Role not found.",
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

      await User.updateRole(id, roleId);
      res.status(200).json({ message: "User role updated successfully." });
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
