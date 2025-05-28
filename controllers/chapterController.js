// Zastąp istniejący kontroler tym kodem
const chapterModel = require("../models/chapterModel");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
const cacheService = require("../services/cacheServices");

const chapterController = {
  createChapter: async (req, res) => {
    try {
      const { courseId } = req.params;
      const { title, content } = req.body;

      console.log("Rozpoczęto tworzenie rozdziału:", {
        courseId,
        title,
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
        content || []
      );

      if (content && Array.isArray(content) && content.length > 0) {
        const chapterWithBlocks = await chapterModel.getChapter(
          newChapter.id,
          courseId
        );
        return res.status(201).json({
          success: true,
          chapter: chapterWithBlocks,
        });
      }

      console.log("Utworzono rozdział:", newChapter);

      await cacheService.invalidate(`chapters:course:${courseId}`);

      return res.status(201).json({
        success: true,
        chapter: newChapter,
      });
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
      const { chapterId, courseId } = req.params;
      const { title, content } = req.body;

      console.log(`Aktualizacja rozdziału ${chapterId}:`, {
        title,
        contentLength: content?.length,
      });

      if (title) {
        await prisma.chapters.update({
          where: { id: parseInt(chapterId) },
          data: {
            title: title.trim(),
            updated_at: new Date(),
          },
        });
      }

      if (content && Array.isArray(content)) {
        await chapterModel.saveChapterBlocks(chapterId, content);
      }

      const updatedChapter = await chapterModel.getChapter(chapterId, courseId);

      await cacheService.invalidate(`chapters:course:${courseId}`);
      await cacheService.invalidate(`chapter:${chapterId}:course:${courseId}`);

      return res.status(200).json({
        success: true,
        message: "Rozdział został zaktualizowany",
        chapter: updatedChapter,
      });
    } catch (error) {
      console.error("Błąd podczas aktualizacji rozdziału:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas aktualizacji rozdziału",
        error: error.message,
      });
    }
  },

  getChapters: async (req, res) => {
    try {
      const { courseId } = req.params;

      console.log("Pobieranie rozdziałów dla kursu:", courseId);

      const CHAPTERS_CACHE_KEY = `chapters:course:${courseId}`;

      const chapters = await cacheService.getOrSet(
        CHAPTERS_CACHE_KEY,
        async () => {
          console.log(
            `Cache miss - pobieranie rozdziałów dla kursu ${courseId}`
          );

          const courseExists = await prisma.courses.findUnique({
            where: { id: parseInt(courseId) },
          });

          if (!courseExists) {
            return { notFound: true };
          }

          return await prisma.chapters.findMany({
            where: { course_id: parseInt(courseId) },
            orderBy: { id: "asc" },
          });
        },
        300
      );

      if (chapters.notFound) {
        return res.status(404).json({
          success: false,
          message: "Kurs o podanym ID nie istnieje",
        });
      }

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

      const CHAPTER_CACHE_KEY = `chapter:${chapterId}:course:${courseId}`;

      const chapter = await cacheService.getOrSet(
        CHAPTER_CACHE_KEY,
        async () => {
          console.log(`Cache miss - pobieranie rozdziału ${chapterId}`);
          return await chapterModel.getChapter(chapterId, courseId);
        },
        300
      );

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
  deleteChapter: async (req, res) => {
    try {
      const { courseId, chapterId } = req.params;

      console.log(`Próba usunięcia rozdziału ${chapterId} z kursu ${courseId}`);

      const result = await chapterModel.deleteChapter(chapterId, courseId);

      if (!result.success) {
        return res.status(404).json({
          success: false,
          message: result.message || "Wystąpił błąd podczas usuwania rozdziału",
        });
      }

      await cacheService.invalidate(`chapters:course:${courseId}`);
      await cacheService.invalidate(`chapter:${chapterId}:course:${courseId}`);

      return res.status(200).json({
        success: true,
        message: "Rozdział został pomyślnie usunięty",
      });
    } catch (error) {
      console.error("Błąd podczas usuwania rozdziału:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas usuwania rozdziału",
        error: error.message,
      });
    }
  },
  uploadChapterImage: async (req, res) => {
    try {
      const { courseId, chapterId } = req.params;

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: "Nie przesłano pliku",
        });
      }

      const filePath = req.file.path;
      const fileName = req.file.filename;

      if (courseId && chapterId) {
        await cacheService.invalidate(`chapters:course:${courseId}`);
        await cacheService.invalidate(
          `chapter:${chapterId}:course:${courseId}`
        );
      }

      return res.status(200).json({
        success: true,
        message: "Zdjęcie zostało pomyślnie przesłane",
        imageUrl: `http://localhost:4000/uploads/${fileName}`,
      });
    } catch (error) {
      console.error("Błąd podczas przesyłania zdjęcia:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas przesyłania zdjęcia",
        error: error.message,
      });
    }
  },
  uploadChapterVideo: async (req, res) => {
    try {
      const { courseId, chapterId } = req.params;

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: "Nie przesłano pliku wideo",
        });
      }

      const filePath = req.file.path;
      const fileName = req.file.filename;

      if (courseId && chapterId) {
        await cacheService.invalidate(`chapters:course:${courseId}`);
        await cacheService.invalidate(
          `chapter:${chapterId}:course:${courseId}`
        );
      }

      return res.status(200).json({
        success: true,
        message: "Film został pomyślnie przesłany",
        videoUrl: `http://localhost:4000/uploads/${fileName}`,
      });
    } catch (error) {
      console.error("Błąd podczas przesyłania filmu:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas przesyłania filmu",
        error: error.message,
      });
    }
  },
};

module.exports = chapterController;
