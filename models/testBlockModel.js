const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const testBlockModel = {
  createTestBlock: async (testId, blockData) => {
    try {
      const {
        block_type,
        question_text,
        points = 1,
        sort_order,
        attributes = {},
        answers = [],
      } = blockData;

      let blockSortOrder = sort_order;
      if (!blockSortOrder) {
        const maxOrderResult = await prisma.test_blocks.findMany({
          where: { test_id: parseInt(testId) },
          orderBy: { sort_order: "desc" },
          take: 1,
        });

        blockSortOrder =
          maxOrderResult.length > 0
            ? (maxOrderResult[0].sort_order || 0) + 1
            : 1;
      }

      const testBlock = await prisma.test_blocks.create({
        data: {
          test_id: parseInt(testId),
          block_type,
          question_text,
          points: parseInt(points),
          sort_order: blockSortOrder,
        },
      });

      if (Object.keys(attributes).length > 0) {
        const attributesArray = Object.entries(attributes).map(
          ([key, value]) => ({
            block_id: testBlock.id,
            attribute_name: key,
            attribute_value: String(value),
          })
        );

        await prisma.test_block_attributes.createMany({
          data: attributesArray,
        });
      }

      if (answers.length > 0) {
        for (let i = 0; i < answers.length; i++) {
          const answer = answers[i];
          const answerData = {
            block_id: testBlock.id,
            answer_text: answer.text || "",
            is_correct: !!answer.is_correct,
            feedback: answer.feedback || "",
            sort_order: i + 1,
          };

          const createdAnswer = await prisma.test_block_answers.create({
            data: answerData,
          });

          if (answer.attributes && Object.keys(answer.attributes).length > 0) {
            const answerAttributesArray = Object.entries(answer.attributes).map(
              ([key, value]) => ({
                answer_id: createdAnswer.id,
                attribute_name: key,
                attribute_value: String(value),
              })
            );

            await prisma.answer_attributes.createMany({
              data: answerAttributesArray,
            });
          }
        }
      }

      const createdBlock = await testBlockModel.getTestBlock(testBlock.id);
      return { success: true, block: createdBlock };
    } catch (error) {
      console.error("Błąd podczas tworzenia bloku testowego:", error);
      return { success: false, error: error.message };
    }
  },

  getTestBlocksByTest: async (testId) => {
    try {
      const blocks = await prisma.test_blocks.findMany({
        where: {
          test_id: parseInt(testId),
        },
        include: {
          test_block_attributes: true,
          test_block_answers: {
            include: {
              answer_attributes: true,
            },
            orderBy: { sort_order: "asc" },
          },
        },
        orderBy: { sort_order: "asc" },
      });

      const formattedBlocks = blocks.map(formatTestBlock);
      return { success: true, blocks: formattedBlocks };
    } catch (error) {
      console.error(
        `Błąd podczas pobierania bloków dla testu ${testId}:`,
        error
      );
      return { success: false, error: error.message };
    }
  },

  getTestBlock: async (blockId) => {
    try {
      const block = await prisma.test_blocks.findUnique({
        where: {
          id: parseInt(blockId),
        },
        include: {
          test_block_attributes: true,
          test_block_answers: {
            include: {
              answer_attributes: true,
            },
            orderBy: { sort_order: "asc" },
          },
        },
      });

      if (!block) {
        return {
          success: false,
          message: "Blok testowy nie został znaleziony",
        };
      }

      const formattedBlock = formatTestBlock(block);
      return { success: true, block: formattedBlock };
    } catch (error) {
      console.error(`Błąd podczas pobierania bloku ${blockId}:`, error);
      return { success: false, error: error.message };
    }
  },

  getTestBlocksForUser: async (testId) => {
    try {
      const result = await testBlockModel.getTestBlocksByTest(testId);

      if (!result.success) {
        return result;
      }

      const sanitizedBlocks = result.blocks.map((block) => {
        const sanitizedBlock = {
          ...block,
          answers: block.answers.map((answer) => ({
            id: answer.id,
            text: answer.text,
            sort_order: answer.sort_order,
          })),
        };
        return sanitizedBlock;
      });

      return { success: true, blocks: sanitizedBlocks };
    } catch (error) {
      console.error(
        `Błąd podczas pobierania bloków testu ${testId} dla użytkownika:`,
        error
      );
      return {
        success: false,
        message: "Nie udało się pobrać pytań",
        error: error.message,
      };
    }
  },

  deleteTestBlock: async (blockId) => {
    try {
      await prisma.test_blocks.delete({
        where: {
          id: parseInt(blockId),
        },
      });

      return {
        success: true,
        message: "Blok testowy został pomyślnie usunięty",
      };
    } catch (error) {
      console.error(`Błąd podczas usuwania bloku ${blockId}:`, error);
      return { success: false, error: error.message };
    }
  },
  reorderTestBlocks: async (testId, orderIds) => {
    try {
      if (!testId || !Array.isArray(orderIds) || orderIds.length === 0) {
        return {
          success: false,
          message: "Nieprawidłowe parametry reorderingu bloków",
        };
      }

      const parsedIds = orderIds.map((id) => parseInt(id));

      await Promise.all(
        parsedIds.map(async (id, index) => {
          await prisma.test_blocks.update({
            where: { id },
            data: {
              sort_order: index,
              updated_at: new Date(),
            },
          });
        })
      );

      return {
        success: true,
        message: "Kolejność pytań została zaktualizowana",
      };
    } catch (error) {
      console.error(
        `Błąd podczas zmiany kolejności bloków testu ${testId}:`,
        error
      );
      return { success: false, error: error.message };
    }
  },
};

function formatTestBlock(block) {
  return {
    id: block.id,
    test_id: block.test_id,
    block_type: block.block_type,
    question_text: block.question_text,
    points: block.points,
    sort_order: block.sort_order,
    created_at: block.created_at,
    updated_at: block.updated_at,
    attributes: block.test_block_attributes.reduce((acc, attr) => {
      acc[attr.attribute_name] = attr.attribute_value;
      return acc;
    }, {}),
    answers: block.test_block_answers.map(formatAnswer),
  };
}

function formatAnswer(answer) {
  return {
    id: answer.id,
    text: answer.answer_text,
    is_correct: answer.is_correct,
    feedback: answer.feedback,
    sort_order: answer.sort_order,
    attributes: answer.answer_attributes.reduce((acc, attr) => {
      acc[attr.attribute_name] = attr.attribute_value;
      return acc;
    }, {}),
  };
}

module.exports = testBlockModel;
