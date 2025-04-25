const testBlockModel = require("../models/testBlockModel");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const testBlockController = {
  createTestBlock: async (req, res) => {
    try {
      const { testId } = req.params;
      const { block_type, question_text, points, attributes, answers } =
        req.body;

      if (!block_type || !question_text) {
        return res.status(400).json({
          success: false,
          message: "Typ bloku i treść pytania są wymagane",
        });
      }

      const test = await prisma.tests.findUnique({
        where: { id: parseInt(testId) },
      });

      if (!test) {
        return res.status(404).json({
          success: false,
          message: "Test nie został znaleziony",
        });
      }

      const result = await testBlockModel.createTestBlock(testId, {
        block_type,
        question_text,
        points,
        attributes,
        answers,
      });

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas tworzenia bloku testowego",
          error: result.error,
        });
      }

      return res.status(201).json({
        success: true,
        message: "Blok testowy został pomyślnie utworzony",
        block: result.block,
      });
    } catch (error) {
      console.error("Błąd podczas tworzenia bloku testowego:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas tworzenia bloku testowego",
        error: error.message,
      });
    }
  },

  getTestBlocksByTest: async (req, res) => {
    try {
      const { testId } = req.params;

      const test = await prisma.tests.findUnique({
        where: { id: parseInt(testId) },
      });

      if (!test) {
        return res.status(404).json({
          success: false,
          message: "Test nie został znaleziony",
        });
      }

      const result = await testBlockModel.getTestBlocksByTest(testId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas pobierania bloków testowych",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        blocks: result.blocks,
      });
    } catch (error) {
      console.error("Błąd podczas pobierania bloków testowych:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania bloków testowych",
        error: error.message,
      });
    }
  },

  getTestBlock: async (req, res) => {
    try {
      const { blockId } = req.params;

      const result = await testBlockModel.getTestBlock(blockId);

      if (!result.success) {
        return res.status(404).json({
          success: false,
          message: result.message || "Blok testowy nie został znaleziony",
        });
      }

      return res.status(200).json({
        success: true,
        block: result.block,
      });
    } catch (error) {
      console.error("Błąd podczas pobierania bloku testowego:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania bloku testowego",
        error: error.message,
      });
    }
  },

  deleteTestBlock: async (req, res) => {
    try {
      const { blockId } = req.params;

      const block = await prisma.test_blocks.findUnique({
        where: { id: parseInt(blockId) },
      });

      if (!block) {
        return res.status(404).json({
          success: false,
          message: "Blok testowy nie został znaleziony",
        });
      }

      const result = await testBlockModel.deleteTestBlock(blockId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas usuwania bloku testowego",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        message: "Blok testowy został pomyślnie usunięty",
      });
    } catch (error) {
      console.error("Błąd podczas usuwania bloku testowego:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas usuwania bloku testowego",
        error: error.message,
      });
    }
  },
};

module.exports = testBlockController;
