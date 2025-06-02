const userProfileModel = require("../models/userProfileModel");

const userController = {
  getUserStats: async (req, res) => {
    try {
      const userId = req.user.id;

      const result = await userProfileModel.getUserStats(userId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania statystyk",
          error: result.error || result.message,
        });
      }

      return res.status(200).json({
        success: true,
        stats: result.stats,
      });
    } catch (error) {
      console.error("Błąd podczas pobierania statystyk użytkownika:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania statystyk",
        error: error.message,
      });
    }
  },

  getUserActivity: async (req, res) => {
    try {
      const userId = req.user.id;
      const limit = parseInt(req.query.limit) || 10;

      const result = await userProfileModel.getUserActivity(userId, limit);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania aktywności",
          error: result.error || result.message,
        });
      }

      return res.status(200).json({
        success: true,
        activities: result.activities,
      });
    } catch (error) {
      console.error("Błąd podczas pobierania aktywności użytkownika:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania aktywności",
        error: error.message,
      });
    }
  },

  updateUserProfile: async (req, res) => {
    try {
      const userId = req.user.id;
      const { firstName, lastName } = req.body;

      const result = await userProfileModel.updateUserProfile(userId, {
        firstName,
        lastName,
      });

      if (!result.success) {
        return res
          .status(result.message.includes("nie został znaleziony") ? 404 : 400)
          .json({
            success: false,
            message:
              result.message || "Wystąpił błąd podczas aktualizacji profilu",
          });
      }

      return res.status(200).json({
        success: true,
        message: "Profil został zaktualizowany pomyślnie",
        user: result.user,
      });
    } catch (error) {
      console.error("Błąd podczas aktualizacji profilu:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas aktualizacji profilu",
        error: error.message,
      });
    }
  },

  deleteUserAccount: async (req, res) => {
    try {
      const userId = req.user.id;

      const result = await userProfileModel.deleteUserAccount(userId);

      if (!result.success) {
        return res
          .status(result.message.includes("nie został znaleziony") ? 404 : 400)
          .json({
            success: false,
            message: result.message,
          });
      }
      res.clearCookie("access_token", { path: "/" });
      res.clearCookie("access_token", { path: "/", httpOnly: true });
      res.clearCookie("access_token", { path: "/", secure: true });
      res.clearCookie("access_token", {
        path: "/",
        httpOnly: true,
        secure: true,
      });

      return res.status(200).json({
        success: true,
        message: "Konto zostało pomyślnie usunięte",
      });
    } catch (error) {
      console.error("Błąd podczas usuwania konta:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas usuwania konta",
        error: error.message,
      });
    }
  },
};

module.exports = userController;
