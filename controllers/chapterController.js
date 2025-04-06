const chapterModel = require("../models/chapterModel");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const chapterController = {
  createChapter: async (req, res) => {
    try {
      const { courseId } = req.params;
      const { title, description } = req.body;

      console.log("Rozpoczęto tworzenie rozdziału:", {
        courseId,
        title,
        description,
      });

      if (!title || title.trim() === "") {
        return res.status(400).json({
          success: false,
          message: "Tytuł rozdziału jest wymagany",
        });
      }
      const courseExists = await chapterModel.checkCourseExists(courseId);

      if (!courseExists) {
        return res.status(404).json({
          success: false,
          message: "Kurs o podanym ID nie istnieje",
        });
      }

      const newChapter = await chapterModel.createChapter(
        courseId,
        title,
        description || null
      );

      console.log("Utworzono rozdział:", newChapter);

      return res.status(201).json(newChapter);
    } catch (error) {
      console.error("Błąd podczas tworzenia rozdziału:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas tworzenia rozdziału",
        error: error.message,
      });
    }
  },

  updateChapter: async (req, res) => {
    try {
      const { chapterId } = req.params;

      const wysiwyg_code = req.body.wysiwyg_code || null;

      if (wysiwyg_code) {
        const updatedChapter = await chapterModel.updateChapterWysiwygCode(
          chapterId,
          wysiwyg_code
        );

        return res.status(200).json({
          success: true,
          message: "Rozdział został zaktualizowany",
          chapter: updatedChapter,
        });
      }
    } catch (error) {
      console.error("Błąd podczas aktualizacji rozdziału:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas aktualizacji rozdziału",
      });
    }
  },
  getChapters: async (req, res) => {
    try {
      const { courseId } = req.params;

      console.log("Pobieranie rozdziałów dla kursu:", courseId);

      const courseExists = await prisma.courses.findUnique({
        where: { id: parseInt(courseId) },
      });

      if (!courseExists) {
        return res.status(404).json({
          success: false,
          message: "Kurs o podanym ID nie istnieje",
        });
      }

      const chapters = await prisma.chapters.findMany({
        where: { course_id: parseInt(courseId) },
        orderBy: { id: "asc" },
      });

      console.log("Pobrano rozdziały:", chapters.length);

      return res.status(200).json(chapters);
    } catch (error) {
      console.error("Błąd podczas pobierania rozdziałów:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania rozdziałów",
      });
    }
  },

  getChapter: async (req, res) => {
    try {
      const { courseId, chapterId } = req.params;

      const chapter = await chapterModel.getChapter(chapterId, courseId);

      if (!chapter) {
        return res.status(404).json({
          success: false,
          message: "Rozdział nie został znaleziony",
        });
      }

      return res.status(200).json({
        success: true,
        chapter,
      });
    } catch (error) {
      console.error("Błąd podczas pobierania rozdziału:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania rozdziału",
      });
    }
  },
};

module.exports = chapterController;
