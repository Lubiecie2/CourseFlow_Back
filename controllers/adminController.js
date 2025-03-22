const User = require("../models/userModel");

const adminController = {
  getAllUsers: async (req, res) => {
    try {
      const users = await User.findAll();
      res.json(users);
    } catch (err) {
      console.error("Error fetching users:", err.message);
      res.status(500).json({ message: "Server error" });
    }
  },

  deleteUser: async (req, res) => {
    try {
      const { id } = req.params;
      await User.deleteById(id);
      res.json({ message: "User deleted successfully" });
    } catch (err) {
      console.error("Error deleting user:", err.message);
      res.status(500).json({ message: "Server error" });
    }
  },

  updateUserRole: async (req, res) => {
    try {
      const { id } = req.params;
      const { role } = req.body;

      if (!["user", "admin"].includes(role)) {
        return res.status(400).json({ message: "Invalid role" });
      }

      const updatedUser = await User.updateRole(id, role);
      res.json(updatedUser);
    } catch (err) {
      console.error("Error updating user role:", err.message);
      res.status(500).json({ message: "Server error" });
    }
  },
};

module.exports = adminController;
