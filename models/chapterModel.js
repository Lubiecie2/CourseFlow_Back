const { PrismaClient } = require("@prisma/client");
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

  createChapter: async (courseId, title, wysiwygCode) => {
    return await prisma.chapters.create({
      data: {
        title: title.trim(),
        wysiwyg_code: wysiwygCode ? wysiwygCode.trim() : null,
        course_id: parseInt(courseId),
        created_at: new Date(),
        updated_at: new Date(),
      },
    });
  },

  updateChapterWysiwygCode: async (chapterId, wysiwygCode) => {
    return await prisma.chapters.update({
      where: { id: parseInt(chapterId) },
      data: {
        wysiwyg_code: wysiwygCode ? wysiwygCode.trim() : null,
        updated_at: new Date(),
      },
    });
  },

  getChapters: async (courseId) => {
    return await prisma.chapters.findMany({
      where: { course_id: parseInt(courseId) },
      orderBy: { order: "asc" },
    });
  },

  getChapter: async (chapterId, courseId) => {
    return await prisma.chapters.findFirst({
      where: {
        id: parseInt(chapterId),
        course_id: parseInt(courseId),
      },
    });
  },
};

module.exports = chapterModel;
