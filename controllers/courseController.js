const courseModel = require("../models/courseModel");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
const path = require("path");
const fs = require("fs");
const cacheService = require("../services/cacheServices");
const COURSES_CACHE_KEY = "courses:all";

const courseController = {
  createCourse: async (req, res) => {
    try {
      const { title, category, description } = req.body;

      if (!title || !category) {
        return res.status(400).json({
          message: "Tytuł i kategoria są wymagane",
        });
      }

      const userId = req.user.id;

      let imageUrl = null;
      if (req.file) {
        imageUrl = req.file.filename;
      }

      const courseData = {
        title,
        category,
        description: description || "",
        imageUrl,
        creatorId: userId,
      };

      const course = await courseModel.createCourse(courseData);

      await cacheService.invalidate(COURSES_CACHE_KEY);

      return res.status(201).json({
        message: "Wizytówka kursu została pomyślnie utworzona",
        course,
      });
    } catch (error) {
      console.error("Error creating course:", error);
      return res.status(500).json({
        message: "Wystąpił błąd podczas tworzenia wizytówki kursu",
      });
    }
  },

  getAllCourses: async (req, res) => {
    try {
      console.log("Zapytanie o kursy otrzymane, sprawdzam cache...");

      const data = await cacheService.getOrSet(
        COURSES_CACHE_KEY,
        async () => {
          console.log("Cache miss - pobieranie kursów z bazy danych");
          return await prisma.courses.findMany({
            orderBy: { created_at: "desc" },
          });
        },
        900
      );

      console.log(`Zwracam ${data.length} kursów do klienta`);
      res.json(data);
    } catch (error) {
      console.error("Error details:", error);
      res.status(500).json({
        message: "Failed to fetch courses",
        error: error.message,
      });
    }
  },

  getCourseById: async (req, res) => {
    try {
      const { id } = req.params;

      console.log(`Otrzymano zapytanie o kurs z ID: ${id}`);

      if (!id || isNaN(parseInt(id))) {
        console.log("Nieprawidłowy format ID kursu");
        return res.status(400).json({ message: "Nieprawidłowe ID kursu" });
      }

      const COURSE_CACHE_KEY = `courses:id:${id}`;

      const course = await cacheService.getOrSet(
        COURSE_CACHE_KEY,
        async () => {
          console.log(`Cache miss - pobieranie kursu ${id} z bazy danych`);
          const courseData = await prisma.courses.findUnique({
            where: {
              id: parseInt(id),
            },
            include: {
              users: {
                select: {
                  id: true,
                  first_name: true,
                  last_name: true,
                },
              },
              chapters: true,
            },
          });

          if (!courseData) {
            return null;
          }

          return courseData;
        },
        600
      );

      if (!course) {
        console.log(`Kurs o ID ${id} nie został znaleziony`);
        return res.status(404).json({ message: "Kurs nie został znaleziony" });
      }

      console.log(`Pomyślnie pobrano kurs o ID: ${id}`);
      res.status(200).json(course);
    } catch (error) {
      console.error("Błąd podczas pobierania kursu:", error);
      res.status(500).json({
        message: "Wystąpił błąd podczas pobierania kursu",
        error: error.message,
      });
    }
  },
  updateCourse: async (req, res) => {
    try {
      const { id } = req.params;
      const { title, category, description } = req.body;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({ message: "Nieprawidłowe ID kursu" });
      }

      const existingCourse = await courseModel.getCourseById(parseInt(id));
      if (!existingCourse) {
        return res.status(404).json({ message: "Kurs nie został znaleziony" });
      }

      const updateData = {
        title: title || existingCourse.title,
        category: category || existingCourse.category,
        short_description: description || existingCourse.short_description,
        updated_at: new Date(),
      };

      if (req.file) {
        if (existingCourse.course_image) {
          const oldImagePath = path.join(
            __dirname,
            "../uploads",
            existingCourse.course_image
          );
          if (fs.existsSync(oldImagePath)) {
            fs.unlinkSync(oldImagePath);
          }
        }
        updateData.course_image = req.file.filename;
      }

      const updatedCourse = await courseModel.updateCourse(
        parseInt(id),
        updateData
      );

      await cacheService.invalidate(COURSES_CACHE_KEY);
      await cacheService.invalidate(`courses:id:${id}`);

      return res.status(200).json({
        message: "Kurs został zaktualizowany pomyślnie",
        course: updatedCourse,
      });
    } catch (error) {
      console.error("Error updating course:", error);
      return res.status(500).json({
        message: "Wystąpił błąd podczas aktualizacji kursu",
        error: error.message,
      });
    }
  },
  deleteCourse: async (req, res) => {
    try {
      const { id } = req.params;

      if (!id || isNaN(parseInt(id))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID kursu",
        });
      }
      const existingCourse = await courseModel.getCourseById(parseInt(id));
      if (!existingCourse) {
        return res.status(404).json({
          success: false,
          message: "Kurs nie został znaleziony",
        });
      }
      if (existingCourse.course_image) {
        const imagePath = path.join(
          __dirname,
          "../uploads",
          existingCourse.course_image
        );
        if (fs.existsSync(imagePath)) {
          fs.unlinkSync(imagePath);
        }
      }

      const result = await courseModel.deleteCourse(id);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: result.message,
          error: result.error,
        });
      }

      await cacheService.invalidate(COURSES_CACHE_KEY);
      await cacheService.invalidate(`courses:id:${id}`);

      return res.status(200).json({
        success: true,
        message: "Kurs został pomyślnie usunięty",
      });
    } catch (error) {
      console.error("Błąd podczas usuwania kursu:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas usuwania kursu",
        error: error.message,
      });
    }
  },
};
module.exports = courseController;
