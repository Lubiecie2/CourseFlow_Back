const User = require("../models/userModel");
const UserLogsModel = require("../models/userLogsModel");
const cacheService = require("../services/cacheServices");

const USERS_CACHE_KEY = "admin:all_users";
const STATS_CACHE_KEY = "admin:stats";

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

      if (query) {
        let users = await User.searchUsers(query);
        const roles = await User.getAllRoles();
        return res.json({ users, roles });
      }

      const data = await cacheService.getOrSet(
        USERS_CACHE_KEY,
        async () => {
          console.log("Cache miss - pobieranie użytkowników z bazy danych");
          const users = await User.findAll();
          const roles = await User.getAllRoles();
          return { users, roles };
        },
        600
      );

      return res.json(data);
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
      const userId = parseInt(req.params.userId);

      if (isNaN(userId)) {
        return res.status(400).json({
          message: "Nieprawidłowy identyfikator użytkownika - musi być liczbą",
        });
      }

      const user = await User.findById(userId);

      if (!user) {
        return res
          .status(404)
          .json({ message: "Użytkownik nie został znaleziony" });
      }

      const userEmail = user.email;

      await UserLogsModel.setOperationContext(req.user.id);

      // await UserLogsModel.logUserOperation(
      //   userId,
      //   "USER_DELETED",
      //   userEmail,
      //   null
      // );

      await User.deleteById(userId);

      await cacheService.invalidate(USERS_CACHE_KEY);

      await UserLogsModel.setOperationContext(null);

      return res
        .status(200)
        .json({ message: "Użytkownik został pomyślnie usunięty" });
    } catch (error) {
      console.error("Error deleting user:", error);
      return res
        .status(500)
        .json({ message: "Wystąpił błąd podczas usuwania użytkownika" });
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

      const oldRole =
        roles.find((r) => r.id === user.role_id)?.name || "unknown";

      await UserLogsModel.setOperationContext(req.user.id);

      await User.updateRole(id, roleId);

      await cacheService.invalidate(USERS_CACHE_KEY);

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

  getAdminStats: async (req, res) => {
    try {
      console.log("Pobieranie statystyk administratora");

      const stats = await User.getAdminStats();

      if (!stats.success) {
        return res.status(500).json({
          success: false,
          message:
            stats.message || "Wystąpił błąd podczas pobierania statystyk",
        });
      }

      return res.status(200).json({
        success: true,
        data: stats.data,
      });
    } catch (error) {
      console.error("Błąd kontrolera statystyk admina:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania statystyk",
      });
    }
  },
};

module.exports = adminController;
