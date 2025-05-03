const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
const { v4: uuidv4 } = require("uuid");

const certificateModel = {
  checkEligibility: async (userId, courseId) => {
    try {
      const existingCertificate = await prisma.certificates.findFirst({
        where: {
          user_id: userId,
          course_id: parseInt(courseId),
        },
      });

      if (existingCertificate) {
        return {
          success: true,
          isEligible: true,
          hasCertificate: true,
          certificateId: existingCertificate.id,
          certificateCode: existingCertificate.certificate_code,
        };
      }

      const chapters = await prisma.chapters.findMany({
        where: { course_id: parseInt(courseId) },
      });

      let allChaptersPassed = true;

      for (const chapter of chapters) {
        const chapterTests = await prisma.tests.findMany({
          where: {
            chapter_id: chapter.id,
            is_course_final: false,
          },
        });

        if (chapterTests.length > 0) {
          let chapterPassed = false;

          for (const test of chapterTests) {
            const passedAttempt = await prisma.user_test_attempts.findFirst({
              where: {
                user_id: userId,
                test_id: test.id,
                passed: true,
              },
            });

            if (passedAttempt) {
              chapterPassed = true;
              break;
            }
          }

          if (!chapterPassed) {
            allChaptersPassed = false;
            break;
          }
        }
      }

      const finalTest = await prisma.tests.findFirst({
        where: {
          course_id: parseInt(courseId),
          is_course_final: true,
        },
      });

      let finalTestPassed = true;

      if (finalTest) {
        const passedAttempt = await prisma.user_test_attempts.findFirst({
          where: {
            user_id: userId,
            test_id: finalTest.id,
            passed: true,
          },
        });

        finalTestPassed = !!passedAttempt;
      }

      const isEligible = allChaptersPassed && finalTestPassed;

      return {
        success: true,
        isEligible,
        hasCertificate: false,
      };
    } catch (error) {
      console.error("Błąd podczas sprawdzania kwalifikacji:", error);
      return { success: false, error: error.message };
    }
  },

  createCertificate: async (userId, courseId, pdfUrl) => {
    try {
      const certificateCode = `CF-${uuidv4().slice(0, 8).toUpperCase()}`;

      const certificate = await prisma.certificates.create({
        data: {
          user_id: userId,
          course_id: parseInt(courseId),
          certificate_code: certificateCode,
          pdf_url: pdfUrl,
          issued_at: new Date(),
          status: "issued",
        },
      });

      return { success: true, certificate };
    } catch (error) {
      console.error("Błąd podczas tworzenia certyfikatu:", error);
      return { success: false, error: error.message };
    }
  },

  getUserCertificates: async (userId) => {
    try {
      const certificates = await prisma.certificates.findMany({
        where: { user_id: userId },
        include: {
          courses: {
            select: {
              id: true,
              title: true,
              category: true,
              course_image: true,
            },
          },
        },
        orderBy: { issued_at: "desc" },
      });

      return { success: true, certificates };
    } catch (error) {
      console.error("Błąd podczas pobierania certyfikatów:", error);
      return { success: false, error: error.message };
    }
  },

  getCertificateByCode: async (certificateCode) => {
    try {
      const certificate = await prisma.certificates.findFirst({
        where: { certificate_code: certificateCode },
        include: {
          users: {
            select: {
              first_name: true,
              last_name: true,
            },
          },
          courses: {
            select: {
              title: true,
            },
          },
        },
      });

      if (!certificate) {
        return { success: false, message: "Nie znaleziono certyfikatu" };
      }

      return { success: true, certificate };
    } catch (error) {
      console.error("Błąd podczas pobierania certyfikatu:", error);
      return { success: false, error: error.message };
    }
  },
};

module.exports = certificateModel;
