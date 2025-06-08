const partitionModel = require("../models/partitionModel");

const partitionController = {
  getPartitions: async (req, res) => {
    try {
      const { tableName } = req.query;

      if (!tableName) {
        return res.status(400).json({
          success: false,
          message: "Parametr tableName jest wymagany",
        });
      }

      const partitions = await partitionModel.getAllPartitions(tableName);

      return res.status(200).json({
        success: true,
        data: partitions,
      });
    } catch (error) {
      console.error("Błąd pobierania partycji:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania partycji",
        error: error.message,
      });
    }
  },

  createPartition: async (req, res) => {
    try {
      const { tableName, year, month } = req.body;

      if (!tableName || !year || !month) {
        return res.status(400).json({
          success: false,
          message: "Parametry tableName, year i month są wymagane",
        });
      }

      const result = await partitionModel.createPartition(
        tableName,
        parseInt(year),
        parseInt(month)
      );

      return res.status(200).json({
        success: true,
        message: result,
      });
    } catch (error) {
      console.error("Błąd tworzenia partycji:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas tworzenia partycji",
        error: error.message,
      });
    }
  },

  detachPartition: async (req, res) => {
    try {
      const { tableName, year, month } = req.body;

      if (!tableName || !year || !month) {
        return res.status(400).json({
          success: false,
          message: "Parametry tableName, year i month są wymagane",
        });
      }

      const result = await partitionModel.detachPartition(
        tableName,
        parseInt(year),
        parseInt(month)
      );

      return res.status(200).json({
        success: true,
        message: result,
      });
    } catch (error) {
      console.error("Błąd odłączania partycji:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas odłączania partycji",
        error: error.message,
      });
    }
  },

  attachPartition: async (req, res) => {
    try {
      const { tableName, year, month } = req.body;

      if (!tableName || !year || !month) {
        return res.status(400).json({
          success: false,
          message: "Parametry tableName, year i month są wymagane",
        });
      }

      const result = await partitionModel.attachPartition(
        tableName,
        parseInt(year),
        parseInt(month)
      );

      return res.status(200).json({
        success: true,
        message: result,
      });
    } catch (error) {
      console.error("Błąd podłączania partycji:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas podłączania partycji",
        error: error.message,
      });
    }
  },

  preparePartitions: async (req, res) => {
    try {
      const { tableName, monthsAhead } = req.body;

      if (!tableName) {
        return res.status(400).json({
          success: false,
          message: "Parametr tableName jest wymagany",
        });
      }

      const results = await partitionModel.preparePartitions(
        tableName,
        monthsAhead || 2
      );

      return res.status(200).json({
        success: true,
        results,
      });
    } catch (error) {
      console.error("Błąd przygotowywania partycji:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas przygotowywania partycji",
        error: error.message,
      });
    }
  },
};

module.exports = partitionController;
