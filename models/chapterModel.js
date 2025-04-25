const { PrismaClient, Prisma } = require("@prisma/client");
const prisma = new PrismaClient();

const chapterModel = {
  checkCourseExists: async (courseId) => {
    return await prisma.courses.findUnique({
      where: { id: parseInt(courseId) },
    });
  },

  getLastChapter: async (courseId) => {
    return await prisma.chapters.findFirst({
      where: { course_id: parseInt(courseId) },
      orderBy: { id: "desc" },
    });
  },

  createChapter: async (courseId, title, content = []) => {
    const chapter = await prisma.chapters.create({
      data: {
        title: title.trim(),
        course_id: parseInt(courseId),
        created_at: new Date(),
        updated_at: new Date(),
      },
    });

    if (content && Array.isArray(content) && content.length > 0) {
      try {
        await chapterModel.saveChapterBlocks(chapter.id, content);
      } catch (error) {
        console.error(
          `Błąd podczas zapisywania bloków w createChapter:`,
          error
        );
      }
    }

    return chapter;
  },

  getChapterBlocks: async (chapterId) => {
    try {
      const blocks = await prisma.chapter_blocks.findMany({
        where: {
          chapter_id: parseInt(chapterId),
        },
        include: {
          chapter_block_attributes: true,
        },
        orderBy: {
          sort_order: "asc",
        },
      });

      return blocks.map((block) => {
        const params = {};
        if (
          block.chapter_block_attributes &&
          block.chapter_block_attributes.length > 0
        ) {
          block.chapter_block_attributes.forEach((attr) => {
            params[attr.name] = attr.value;
          });
        }

        return {
          id: `item-${block.id}`,
          type: block.type,
          params,
        };
      });
    } catch (error) {
      console.error(
        `Błąd podczas pobierania bloków dla rozdziału ${chapterId}:`,
        error
      );
      return [];
    }
  },

  saveChapterBlocks: async (chapterId, contentArray) => {
    try {
      const chapterId_int = parseInt(chapterId);

      const existingBlocks = await prisma.chapter_blocks.findMany({
        where: { chapter_id: chapterId_int },
        select: { id: true },
      });

      if (existingBlocks.length > 0) {
        const ids = existingBlocks.map((block) => block.id);
        await prisma.chapter_block_attributes.deleteMany({
          where: {
            block_id: { in: ids },
          },
        });

        await prisma.chapter_blocks.deleteMany({
          where: {
            id: { in: ids },
          },
        });
      }
      for (let i = 0; i < contentArray.length; i++) {
        const item = contentArray[i];

        if (!item.type) {
          console.warn(`Brak typu bloku`);
          continue;
        }

        const newBlock = await prisma.chapter_blocks.create({
          data: {
            chapter_id: chapterId_int,
            type: item.type,
            sort_order: i,
            created_at: new Date(),
            updated_at: new Date(),
          },
        });

        const blockId = newBlock.id;

        if (item.params) {
          const attributesData = Object.entries(item.params).map(
            ([name, value]) => ({
              block_id: blockId,
              name,
              value: String(value),
            })
          );

          await prisma.chapter_block_attributes.createMany({
            data: attributesData,
          });
        }
      }
      await prisma.chapters.update({
        where: { id: chapterId_int },
        data: { updated_at: new Date() },
      });
      return true;
    } catch (error) {
      console.error(
        `Błąd podczas zapisywania bloków dla rozdziału ${chapterId}:`,
        error
      );
      throw error;
    }
  },

  getChapters: async (courseId) => {
    return await prisma.chapters.findMany({
      where: { course_id: parseInt(courseId) },
      orderBy: { id: "asc" },
    });
  },

  getChapter: async (chapterId, courseId) => {
    try {
      const chapter = await prisma.chapters.findFirst({
        where: {
          id: parseInt(chapterId),
          course_id: parseInt(courseId),
        },
      });

      if (!chapter) return null;

      const blocks = await chapterModel.getChapterBlocks(chapterId);

      return {
        ...chapter,
        blocks,
      };
    } catch (error) {
      console.error(`Błąd podczas pobierania rozdziału ${chapterId}:`, error);
      return null;
    }
  },
  deleteChapter: async (chapterId, courseId) => {
    try {
      const chapterId_int = parseInt(chapterId);
      const courseId_int = parseInt(courseId);

      const chapter = await prisma.chapters.findFirst({
        where: {
          id: chapterId_int,
          course_id: courseId_int,
        },
      });

      if (!chapter) {
        return { success: false, message: "Rozdział nie został znaleziony" };
      }
      await prisma.chapters.delete({
        where: {
          id: chapterId_int,
        },
      });

      return { success: true, message: "Rozdział został pomyślnie usunięty" };
    } catch (error) {
      console.error(`Błąd podczas usuwania rozdziału ${chapterId}:`, error);
      return { success: false, error: error.message };
    }
  },
  uploadChapterImage: async (filePath) => {
    try {
      const fileName = filePath.split("/").pop();
      return {
        success: true,
        fileName: fileName,
        imageUrl: `http://localhost:4000/uploads/${fileName}`,
      };
    } catch (error) {
      console.error("Błąd podczas zapisywania obrazu rozdziału:", error);
      return {
        success: false,
        message: "Wystąpił błąd podczas zapisywania obrazu",
        error: error.message,
      };
    }
  },
  uploadChapterVideo: async (filePath) => {
    try {
      const fileName = filePath.split("/").pop();
      return {
        success: true,
        fileName: fileName,
        videoUrl: `http://localhost:4000/uploads/${fileName}`,
      };
    } catch (error) {
      console.error("Błąd podczas zapisywania filmu rozdziału:", error);
      return {
        success: false,
        message: "Wystąpił błąd podczas zapisywania filmu",
        error: error.message,
      };
    }
  },
};

module.exports = chapterModel;
