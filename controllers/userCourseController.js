const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const userCourseController = {
  getUserSignedInCourse: async (req, res) => {
    try {
      const userId = req.user.id;
      const signs = await prisma.user_courses.findMany({
        where: {
          users: {
            id: userId,
          },
        },
        include: {
          courses: {
            select: {
              id: true,
              title: true,
              category: true,
              course_image: true,
              short_description: true,
            },
          },
        },
      });
      res.status(200).json(signs);
    } catch (error) {
      console.error("Błąd podczas pobierania zapisów:", error);
      res.status(500).json({
        message: "Wystąpił błąd podczas pobierania zapisów na kursy",
        error: error.message,
      });
    }
  },

  signUpUserToCourse: async (req, res) => {
    try {
      const userId = req.user.id;
      const { courseId } = req.body;

      console.log("Zapisywanie użytkownika na kurs:", { userId, courseId });
      if (!courseId) {
        return res.status(400).json({ message: "ID kursu jest wymagane" });
      }
      const course = await prisma.courses.findUnique({
        where: { id: parseInt(courseId) },
      });
      if (!course) {
        return res
          .status(404)
          .json({ message: "Nie znaleziono kursu o podanym ID" });
      }
      const existingSignUpCourse = await prisma.user_courses.findFirst({
        where: {
          users: {
            id: userId,
          },
          courses: {
            id: parseInt(courseId),
          },
        },
      });
      if (existingSignUpCourse) {
        return res
          .status(400)
          .json({ message: "Użytkownik jest już zapisany na ten kurs" });
      }
      const signUp = await prisma.user_courses.create({
        data: {
          users: {
            connect: { id: userId },
          },
          courses: {
            connect: { id: parseInt(courseId) },
          },
          status: "not_started",
        },
      });
      res.status(201).json({
        message: "Użytkownik został pomyślnie zapisany na kurs",
        signUp,
      });
    } catch (error) {
      console.error("Błąd podczas zapisywania na kurs:", error);
      res.status(500).json({
        message: "Wystąpił błąd podczas zapisywania na kurs",
        error: error.message,
      });
    }
  },
};

module.exports = userCourseController;
