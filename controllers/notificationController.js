const NotificationModel = require("../models/notificationModel");

const notificationController = {
  getUserNotifications: async (req, res) => {
    try {
      const userId = req.user.id;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;

      const result = await NotificationModel.getUserNotifications(
        userId,
        page,
        limit
      );

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania powiadomień",
          error: result.error,
        });
      }

      await NotificationModel.markAllAsRead(userId);

      return res.status(200).json({
        success: true,
        notifications: result.notifications,
        pagination: result.pagination,
      });
    } catch (error) {
      console.error("Błąd kontrolera powiadomień:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getUnreadCount: async (req, res) => {
    try {
      const userId = req.user.id;

      const result = await NotificationModel.getUnreadCount(userId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania liczby powiadomień",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        count: result.count,
      });
    } catch (error) {
      console.error("Błąd kontrolera powiadomień:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  createAdminNotification: async (req, res) => {
    try {
      const { title, message } = req.body;

      if (!title || !message) {
        return res.status(400).json({
          success: false,
          message: "Tytuł i treść powiadomienia są wymagane",
        });
      }

      const type = "ADMIN_ANNOUNCEMENT";
      const result = await NotificationModel.createNotificationForAllUsers(
        title,
        message,
        type
      );

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas tworzenia powiadomień",
          error: result.error,
        });
      }

      return res.status(201).json({
        success: true,
        message: result.message || "Powiadomienia zostały pomyślnie utworzone",
      });
    } catch (error) {
      console.error("Błąd kontrolera powiadomień administratora:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },
};

module.exports = notificationController;
