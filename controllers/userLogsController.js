const UserLogsModel = require("../models/userLogsModel");

const userLogsController = {
  getAllLogs: async (req, res) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;

      const filters = {};

      if (req.query.userId) filters.userId = parseInt(req.query.userId);
      if (req.query.actionType) filters.actionType = req.query.actionType;
      if (req.query.fromDate) filters.fromDate = new Date(req.query.fromDate);
      if (req.query.toDate) filters.toDate = new Date(req.query.toDate);

      const result = await UserLogsModel.getAllLogs(filters, page, limit);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania logów",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        logs: result.logs,
        pagination: result.pagination,
      });
    } catch (error) {
      console.error("Błąd kontrolera logów:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getUserLogs: async (req, res) => {
    try {
      const { userId } = req.params;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;

      if (!userId || isNaN(parseInt(userId))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowy identyfikator użytkownika",
        });
      }

      const result = await UserLogsModel.getUserLogs(
        parseInt(userId),
        page,
        limit
      );

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania logów użytkownika",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        logs: result.logs,
        pagination: result.pagination,
      });
    } catch (error) {
      console.error("Błąd kontrolera logów użytkownika:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getLoginLogs: async (req, res) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;

      const filters = {};
      if (req.query.userId) filters.userId = parseInt(req.query.userId);
      if (req.query.fromDate) filters.fromDate = new Date(req.query.fromDate);
      if (req.query.toDate) filters.toDate = new Date(req.query.toDate);

      const result = await UserLogsModel.getLoginLogs(filters, page, limit);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania logów logowań",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        logs: result.logs,
        pagination: result.pagination,
      });
    } catch (error) {
      console.error("Błąd kontrolera logów logowań:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },

  getCourseLogs: async (req, res) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 15;

      const filters = {};
      if (req.query.courseId) filters.courseId = parseInt(req.query.courseId);
      if (req.query.fromDate) filters.fromDate = new Date(req.query.fromDate);
      if (req.query.toDate) filters.toDate = new Date(req.query.toDate);

      const result = await UserLogsModel.getCourseLogs(filters, page, limit);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania logów kursów",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        logs: result.logs,
        pagination: result.pagination,
      });
    } catch (error) {
      console.error("Błąd kontrolera logów kursów:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas obsługi żądania",
        error: error.message,
      });
    }
  },
};

module.exports = userLogsController;
