const certificateModel = require("../models/certificateModel");
const PDFDocument = require("pdfkit");
const fs = require("fs");
const path = require("path");
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const certificateController = {
  checkEligibility: async (req, res) => {
    try {
      const userId = req.user.id;
      const { courseId } = req.params;

      if (!courseId) {
        return res.status(400).json({
          success: false,
          message: "Brak ID kursu",
        });
      }

      const result = await certificateModel.checkEligibility(userId, courseId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Wystąpił błąd podczas sprawdzania uprawnień do certyfikatu",
          error: result.error,
        });
      }

      return res.status(200).json(result);
    } catch (error) {
      console.error("Błąd kontrolera:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas sprawdzania uprawnień do certyfikatu",
      });
    }
  },

  generateCertificate: async (req, res) => {
    try {
      const userId = req.user.id;
      const { courseId } = req.params;

      if (!courseId) {
        return res.status(400).json({
          success: false,
          message: "Brak ID kursu",
        });
      }

      const eligibilityResult = await certificateModel.checkEligibility(
        userId,
        courseId
      );

      if (!eligibilityResult.success) {
        return res.status(500).json({
          success: false,
          message: "Błąd podczas sprawdzania kwalifikacji do certyfikatu",
        });
      }

      if (eligibilityResult.hasCertificate) {
        return res.status(200).json({
          success: true,
          message: "Certyfikat już istnieje",
          certificateId: eligibilityResult.certificateId,
          certificateCode: eligibilityResult.certificateCode,
        });
      }

      if (!eligibilityResult.isEligible) {
        return res.status(403).json({
          success: false,
          message: "Nie spełniasz wymagań do otrzymania certyfikatu",
        });
      }

      const user = await prisma.users.findUnique({
        where: { id: userId },
      });

      const course = await prisma.courses.findUnique({
        where: { id: parseInt(courseId) },
      });

      if (!user || !course) {
        return res.status(404).json({
          success: false,
          message: "Nie znaleziono użytkownika lub kursu",
        });
      }

      const tempPdfUrl = "pending";

      const createResult = await certificateModel.createCertificate(
        userId,
        courseId,
        tempPdfUrl
      );

      if (!createResult.success) {
        return res.status(500).json({
          success: false,
          message: "Błąd podczas tworzenia certyfikatu",
          error: createResult.error,
        });
      }

      const certificate = createResult.certificate;

      const certDir = path.join(__dirname, "../uploads/certificates");
      if (!fs.existsSync(certDir)) {
        fs.mkdirSync(certDir, { recursive: true });
      }

      const pdfPath = path.join(certDir, `${certificate.certificate_code}.pdf`);
      await generatePDF(pdfPath, {
        courseName: course.title,
        userName: `${user.first_name} ${user.last_name}`,
        certificateCode: certificate.certificate_code,
        issueDate: new Date().toLocaleDateString("pl-PL"),
      });

      const pdfUrl = `/uploads/certificates/${certificate.certificate_code}.pdf`;
      await prisma.certificates.update({
        where: { id: certificate.id },
        data: { pdf_url: pdfUrl },
      });

      return res.status(201).json({
        success: true,
        message: "Certyfikat został pomyślnie wygenerowany",
        certificateId: certificate.id,
        certificateCode: certificate.certificate_code,
      });
    } catch (error) {
      console.error("Błąd kontrolera:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas generowania certyfikatu",
      });
    }
  },

  getUserCertificates: async (req, res) => {
    try {
      const userId = req.user.id;
      const result = await certificateModel.getUserCertificates(userId);

      if (!result.success) {
        return res.status(500).json({
          success: false,
          message: "Błąd podczas pobierania certyfikatów",
          error: result.error,
        });
      }

      return res.status(200).json({
        success: true,
        certificates: result.certificates,
      });
    } catch (error) {
      console.error("Błąd kontrolera:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania certyfikatów",
      });
    }
  },

  downloadCertificate: async (req, res) => {
    try {
      const { certificateCode } = req.params;
      const userId = req.user.id;

      if (!certificateCode) {
        return res.status(400).json({
          success: false,
          message: "Brak kodu certyfikatu",
        });
      }

      const result = await certificateModel.getCertificateByCode(
        certificateCode
      );

      if (!result.success) {
        return res.status(404).json({
          success: false,
          message: "Certyfikat nie został znaleziony",
        });
      }

      const certificate = result.certificate;

      if (certificate.user_id !== userId && req.user.role_id !== 1) {
        return res.status(403).json({
          success: false,
          message: "Brak uprawnień do pobrania certyfikatu",
        });
      }

      const pdfPath = path.join(
        __dirname,
        "../uploads/certificates",
        `${certificateCode}.pdf`
      );

      if (!fs.existsSync(pdfPath)) {
        await generatePDF(pdfPath, {
          courseName: certificate.courses.title,
          userName: `${certificate.users.first_name} ${certificate.users.last_name}`,
          certificateCode: certificate.certificate_code,
          issueDate: certificate.issued_at
            ? new Date(certificate.issued_at).toLocaleDateString("pl-PL")
            : new Date().toLocaleDateString("pl-PL"),
        });
      }

      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename=certyfikat-${certificateCode}.pdf`
      );

      const fileStream = fs.createReadStream(pdfPath);
      fileStream.pipe(res);
    } catch (error) {
      console.error("Błąd kontrolera:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania pliku certyfikatu",
      });
    }
  },
};

async function generatePDF(filePath, data) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: "A4",
      layout: "landscape",
      margin: 0,
      info: {
        Title: `Certyfikat ukończenia kursu ${data.courseName}`,
        Author: "CourseFlow",
        Subject: "Certyfikat ukończenia kursu",
      },
    });

    const stream = fs.createWriteStream(filePath);
    doc.pipe(stream);

    const fontPath = path.join(__dirname, "../fonts/DejaVuSans.ttf");
    const boldFontPath = path.join(__dirname, "../fonts/DejaVuSans-Bold.ttf");

    doc.registerFont("PolishFont", fontPath);
    doc.registerFont("PolishFontBold", boldFontPath);

    doc.rect(0, 0, doc.page.width, doc.page.height).fill("#ffffff");

    const margin = 30;
    doc
      .rect(
        margin,
        margin,
        doc.page.width - margin * 2,
        doc.page.height - margin * 2
      )
      .lineWidth(3)
      .stroke("#eb5757");

    const centerBlockWidth = 500;
    const centerX = (doc.page.width - centerBlockWidth) / 2;

    doc
      .font("PolishFontBold")
      .fontSize(36)
      .fillColor("#eb5757")
      .text("CourseFlow", centerX, 80, {
        align: "center",
        width: centerBlockWidth,
      });

    doc
      .font("PolishFontBold")
      .fontSize(32)
      .fillColor("#333333")
      .text("Certyfikat ukończenia kursu", centerX, 140, {
        align: "center",
        width: centerBlockWidth,
      });

    doc
      .font("PolishFont")
      .fontSize(16)
      .fillColor("#333333")
      .text("Niniejszym zaświadcza się, że", centerX, 230, {
        align: "center",
        width: centerBlockWidth,
      });

    doc
      .font("PolishFontBold")
      .fontSize(28)
      .fillColor("#eb5757")
      .text(data.userName, centerX, 270, {
        align: "center",
        width: centerBlockWidth,
      });

    doc
      .font("PolishFont")
      .fontSize(16)
      .fillColor("#333333")
      .text("pomyślnie ukończył(a) kurs o nazwie", centerX, 320, {
        align: "center",
        width: centerBlockWidth,
      });

    doc
      .font("PolishFontBold")
      .fontSize(24)
      .fillColor("#333333")
      .text(data.courseName, centerX, 360, {
        align: "center",
        width: centerBlockWidth,
      });

    doc
      .font("PolishFont")
      .fontSize(14)
      .fillColor("#333333")
      .text(`Data wystawienia: ${data.issueDate}`, 100, 430);

    doc
      .font("PolishFont")
      .fontSize(12)
      .text(`Numer certyfikatu: ${data.certificateCode}`, 100, 460);

    doc
      .font("PolishFontBold")
      .fontSize(14)
      .text("Administracja CourseFlow", doc.page.width - 250, 430, {
        align: "center",
        width: 150,
      });

    doc.end();

    stream.on("finish", () => {
      resolve();
    });

    stream.on("error", (err) => {
      reject(err);
    });
  });
}
module.exports = certificateController;
