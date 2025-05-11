const { sendContactEmail } = require("../utils/mailer");

const contactController = {
  submitContact: async (req, res) => {
    try {
      const { name, email, subject, message } = req.body;
      const ipAddress = req.ip;

      if (!name || !email || !subject || !message) {
        return res.status(400).json({
          success: false,
          message: "Wszystkie pola są wymagane",
        });
      }
      await sendContactEmail(name, email, subject, message, ipAddress);

      return res.status(200).json({
        success: true,
        message: "Wiadomość została wysłana pomyślnie",
      });
    } catch (error) {
      console.error(
        "Błąd podczas przetwarzania formularza kontaktowego:",
        error
      );
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas przetwarzania formularza",
      });
    }
  },
};

module.exports = contactController;
