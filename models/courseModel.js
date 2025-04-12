const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const courseModel = {
  createCourse: async (courseData) => {
    try {
      const { title, category, description, imageUrl, creatorId } = courseData;

      const course = await prisma.courses.create({
        data: {
          title,
          category,
          short_description: description,
          course_image: imageUrl,
          users: {
            connect: {
              id: parseInt(creatorId),
            },
          },
          is_published: false,
        },
      });
      return course;
    } catch (error) {
      console.error("Error in createCourse model:", error);
      throw error;
    }
  },

  getAllCourses: async () => {
    try {
      return await prisma.courses.findMany({
        select: {
          id: true,
          title: true,
          category: true,
          short_description: true,
          course_image: true,
          created_at: true,
          is_published: true,
          users: {
            select: {
              id: true,
              fist_name: true,
            },
          },
        },
      });
    } catch (error) {
      console.error("Error in getAllCourses model:", error);
      throw error;
    }
  },

  getCourseById: async (id) => {
    try {
      return await prisma.courses.findUnique({
        where: { id: parseInt(id) },
        include: {
          users: {
            select: {
              id: true,
              first_name: true,
              email: true,
            },
          },
        },
      });
    } catch (error) {
      console.error("Error in getCourseById model:", error);
      throw error;
    }
  },
  updateCourse: async (id, updateData) => {
    try {
      return await prisma.courses.update({
        where: {
          id: id,
        },
        data: updateData,
      });
    } catch (error) {
      console.error("Error in updateCourse:", error);
      throw error;
    }
  },
  deleteCourse: async (id) => {
    try {
      const deletedCourse = await prisma.courses.delete({
        where: {
          id: parseInt(id),
        },
      });

      return {
        success: true,
        message: "Kurs został pomyślnie usunięty",
        course: deletedCourse,
      };
    } catch (error) {
      console.error("Błąd w modelu deleteCourse:", error);
      return {
        success: false,
        message: "Wystąpił błąd podczas usuwania kursu",
        error: error.message,
      };
    }
  },
};

module.exports = courseModel;
