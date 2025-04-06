const nodemailer = require("nodemailer");
const crypto = require("crypto");
const SibApiV3Sdk = require("sib-api-v3-sdk");

const brevoApiKey = process.env.BREVO_API_KEY;

const defaultClient = SibApiV3Sdk.ApiClient.instance;
const apiKey = defaultClient.authentications["api-key"];
apiKey.apiKey = brevoApiKey;

const apiClient = new SibApiV3Sdk.TransactionalEmailsApi();

const transporter = nodemailer.createTransport({
  host: process.env.MAIL_HOST,
  port: process.env.MAIL_PORT,
  auth: {
    user: process.env.MAIL_USER,
    pass: process.env.MAIL_PASS,
  },
});

const sendVerificationEmail = async (userEmail, verificationCode) => {
  const mailOptions = {
    from: "course.flow@interia.com",
    to: userEmail,
    subject: "Weryfikacja e-maila",
    html: `<p>Twój kod weryfikacyjny to: <strong>${verificationCode}</strong></p>`,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log("E-mail wysłany przez Nodemailer");
  } catch (error) {
    console.error("Błąd wysyłania e-maila przez Nodemailer: ", error);
    throw new Error("Nie udało się wysłać e-maila przez Nodemailer");
  }
  /*  W PRZYSZŁOSCI DODANIE WYSYŁANIA E-MAILI PRZEZ BREVO
  const sendSmtpEmail = new SibApiV3Sdk.SendSmtpEmail();
  sendSmtpEmail.subject = "Weryfikacja e-maila";
  sendSmtpEmail.sender = { email: "course.flow@interia.com" };
  sendSmtpEmail.to = [{ email: userEmail }];
  sendSmtpEmail.htmlContent = `<p>Twój kod weryfikacyjny to: <strong>${verificationCode}</strong></p>`;

  try {
    await apiClient.sendTransacEmail(sendSmtpEmail);
    console.log("E-mail wysłany przez Brevo");
  } catch (error) {
    console.error("Błąd wysyłania e-maila przez Brevo: ", error);
    throw new Error("Nie udało się wysłać e-maila przez Brevo");
  }
  */
};

const generateVerificationToken = () => {
  return crypto.randomBytes(3).toString("hex");
};

module.exports = { sendVerificationEmail, generateVerificationToken };
