const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const testModel = {
  getTestById: async (testId) => {
    try {
      const test = await prisma.tests.findUnique({
        where: {
          id: parseInt(testId),
        },
        include: {
          test_blocks: {
            orderBy: {
              sort_order: "asc",
            },
            include: {
              test_block_answers: {
                orderBy: {
                  sort_order: "asc",
                },
                include: {
                  answer_attributes: true,
                },
              },
              test_block_attributes: true,
            },
          },
          chapters: {
            select: {
              id: true,
              title: true,
              course_id: true,
            },
          },
          courses: true,
        },
      });

      return { success: true, test };
    } catch (error) {
      console.error(`Błąd podczas pobierania testu ${testId}:`, error);
      return {
        success: false,
        message: "Nie udało się pobrać testu",
        error: error.message,
      };
    }
  },

  getTestsByChapter: async (courseId, chapterId) => {
    try {
      const tests = await prisma.tests.findMany({
        where: {
          chapters: {
            id: parseInt(chapterId),
          },
          course_id: parseInt(courseId),
        },
        include: {
          _count: {
            select: {
              test_blocks: true,
              user_test_attempts: true,
            },
          },
        },
        orderBy: {
          created_at: "desc",
        },
      });

      return { success: true, tests: tests };
    } catch (error) {
      console.error(
        `Błąd podczas pobierania testów dla rozdziału ${chapterId}:`,
        error
      );
      throw error;
    }
  },

  createTest: async (testData) => {
    try {
      const {
        title,
        description,
        pass_threshold,
        time_limit,
        chapter_id,
        course_id,
        author_id,
        is_course_final = false,
      } = testData;

      const test = await prisma.tests.create({
        data: {
          title,
          description: description || "",
          pass_threshold: parseInt(pass_threshold) || 70,
          time_limit: parseInt(time_limit) || 0,
          chapter_id: parseInt(chapter_id),
          course_id: parseInt(course_id),
          author_id: parseInt(author_id),
          is_course_final: is_course_final === true,
        },
      });

      return { success: true, test };
    } catch (error) {
      console.error("Błąd podczas tworzenia testu:", error);
      return { success: false, error: error.message };
    }
  },

  getTestsByCourse: async (courseId) => {
    try {
      const tests = await prisma.tests.findMany({
        where: {
          course_id: parseInt(courseId),
          is_course_final: true,
        },
        include: {
          _count: {
            select: {
              test_blocks: true,
              user_test_attempts: true,
            },
          },
        },
        orderBy: {
          created_at: "desc",
        },
      });

      return { success: true, tests };
    } catch (error) {
      console.error(
        `Błąd podczas pobierania testów dla kursu ${courseId}:`,
        error
      );
      return { success: false, error: error.message };
    }
  },

  updateTest: async (testId, testData) => {
    try {
      const { title, description, pass_threshold, time_limit } = testData;

      const test = await prisma.tests.update({
        where: { id: parseInt(testId) },
        data: {
          title,
          description,
          pass_threshold: parseInt(pass_threshold),
          time_limit: parseInt(time_limit),
          updated_at: new Date(),
        },
      });

      return { success: true, test };
    } catch (error) {
      console.error(`Błąd podczas aktualizacji testu ${testId}:`, error);
      return { success: false, error: error.message };
    }
  },

  deleteTest: async (testId) => {
    try {
      await prisma.tests.delete({
        where: { id: parseInt(testId) },
      });

      return { success: true, message: "Test został pomyślnie usunięty" };
    } catch (error) {
      console.error(`Błąd podczas usuwania testu ${testId}:`, error);
      return { success: false, error: error.message };
    }
  },
};

module.exports = testModel;
