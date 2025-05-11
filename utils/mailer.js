const nodemailer = require("nodemailer");
const crypto = require("crypto");
const SibApiV3Sdk = require("sib-api-v3-sdk");

const ipThrottleMap = new Map();
const THROTTLE_TIME = 120000;

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

const sanitizeHtml = (text) => {
  if (!text) return "";
  return text
    .toString()
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
};

const canSendEmail = (ip, email) => {
  if (!ip) return true;

  const now = Date.now();
  const key = `${ip}:${email || ""}`;
  const lastSentTime = ipThrottleMap.get(key);

  if (lastSentTime && now - lastSentTime < THROTTLE_TIME) {
    return false;
  }

  ipThrottleMap.set(key, now);
  return true;
};

const sendVerificationEmail = async (
  userEmail,
  verificationCode,
  ipAddress
) => {
  if (!canSendEmail(ipAddress)) {
    throw new Error(
      "Proszę poczekać 2 minuty przed ponownym wysłaniem wiadomości e-mail"
    );
  }

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
};

const sendContactEmail = async (name, email, subject, message, ipAddress) => {
  if (!canSendEmail(ipAddress)) {
    throw new Error(
      "Proszę poczekać 2 minuty przed ponownym wysłaniem wiadomości"
    );
  }

  const sanitizedName = sanitizeHtml(name);
  const sanitizedSubject = sanitizeHtml(subject);
  const sanitizedMessage = sanitizeHtml(message);

  const mailOptions = {
    from: "course.flow@interia.com",
    replyTo: email,
    to: "course.flow@interia.com",
    subject: `Formularz kontaktowy: ${sanitizedSubject}`,
    html: `
      <h2>Nowa wiadomość z formularza kontaktowego</h2>
      <p><strong>Od:</strong> ${sanitizedName} (${email})</p>
      <p><strong>Temat:</strong> ${sanitizedSubject}</p>
      <p><strong>Wiadomość:</strong></p>
      <p>${sanitizedMessage}</p>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log("E-mail kontaktowy wysłany");
    return true;
  } catch (error) {
    console.error("Błąd wysyłania e-maila kontaktowego:", error);
    throw new Error("Nie udało się wysłać e-maila kontaktowego");
  }
};

const sendPasswordResetEmail = async (userEmail, resetUrl, ipAddress) => {
  const emailKey = `${ipAddress}_${userEmail}_reset`;

  if (!canSendEmail(ipAddress, emailKey)) {
    throw new Error(
      "Proszę poczekać przed ponownym wysłaniem wiadomości e-mail dotyczącej resetowania hasła."
    );
  }

  const mailOptions = {
    from: process.env.EMAIL_USER || "course.flow@interia.com",
    to: userEmail,
    subject: "Resetowanie hasła w CourseFlow",
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.6; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #333; text-align: center; margin-bottom: 20px;">Resetowanie hasła</h2>
        <p>Witaj,</p>
        <p>Otrzymaliśmy prośbę o zresetowanie hasła dla Twojego konta w CourseFlow.</p>
        <p>Aby ustawić nowe hasło, kliknij w poniższy link:</p>
        <p style="text-align: center;">
          <a href="${resetUrl}" style="display: inline-block; background-color: #eb5757; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold;">
            Ustaw nowe hasło
          </a>
        </p>
        <p>Jeśli nie prosiłeś(aś) o reset hasła, zignoruj tę wiadomość.</p>
        <p>Link jest ważny przez 1 godzinę od momentu wysłania.</p>
        <p style="margin-top: 30px; font-size: 14px; color: #666;">
          Pozdrawiamy,<br />
          Zespół CourseFlow
        </p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Email resetujący hasło wysłany do ${userEmail}`);
    ipThrottleMap.set(emailKey, Date.now());
  } catch (error) {
    console.error("Błąd wysyłania emaila resetującego hasło:", error);
    throw new Error("Nie udało się wysłać emaila resetującego hasło.");
  }
};

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

const generateVerificationToken = () => {
  return crypto.randomBytes(4).toString("hex");
};

const cleanupThrottleMap = () => {
  const now = Date.now();
  for (const [ip, time] of ipThrottleMap.entries()) {
    if (now - time > THROTTLE_TIME) {
      ipThrottleMap.delete(ip);
    }
  }
};

setInterval(cleanupThrottleMap, 600000);

module.exports = {
  sendVerificationEmail,
  generateVerificationToken,
  sendContactEmail,
  canSendEmail,
  sendPasswordResetEmail,
};
