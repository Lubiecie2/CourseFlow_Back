const courseModel = require("../models/courseModel");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
const path = require("path");
const fs = require("fs");

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
      console.log("Attempting to fetch courses...");

      const courses = await prisma.courses.findMany();

      console.log(`Successfully fetched ${courses.length} courses`);
      res.json(courses);
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

      console.log(`Attempting to fetch course with ID: ${id}`);

      if (!id || isNaN(parseInt(id))) {
        console.log("Invalid course ID format");
        return res.status(400).json({ message: "Nieprawidłowe ID kursu" });
      }
      const course = await prisma.courses.findUnique({
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

      if (!course) {
        console.log(`Course with ID ${id} not found`);
        return res.status(404).json({ message: "Kurs nie został znaleziony" });
      }

      console.log(`Successfully fetched course with ID: ${id}`);
      res.status(200).json(course);
    } catch (error) {
      console.error("Error fetching course:", error);
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
};
module.exports = courseController;
