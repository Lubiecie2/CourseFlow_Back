var createError = require("http-errors");
var express = require("express");
var path = require("path");
var cookieParser = require("cookie-parser");
var logger = require("morgan");
const swaggerJsdoc = require("swagger-jsdoc");
const swaggerUi = require("swagger-ui-express");
const bcrypt = require("bcryptjs");
const { connectRedis } = require("./config/redis");

const cors = require("cors");
const pool = require("./models/db");

const { wafMiddleware } = require("./middleware/waf");

const adminRouter = require("./routes/admin");
var indexRouter = require("./routes/index");
const authRouter = require("./routes/auth");
const roleRouter = require("./routes/role");
const courseRouter = require("./routes/course");
const chapterRouter = require("./routes/chapter");
const userCourseRouter = require("./routes/userCourse");
const testRouter = require("./routes/test");
const chapterTestRouter = require("./routes/chapterTest");
const testBlockRouter = require("./routes/testBlock");
const userTestRouter = require("./routes/userTest");
const certificateRouter = require("./routes/certificate");
const contactRoutes = require("./routes/contact");
const logsRoutes = require("./routes/logs");
const notificationsRouter = require("./routes/notifications");
const partitionsRouter = require("./routes/partitions");
const courseQuestionRoutes = require("./routes/courseQuestion");
const courseAnswerRoutes = require("./routes/courseAnswer");
const courseNoteRoutes = require("./routes/courseNoteRoutes");
const userRoutes = require("./routes/user");
const wafRoutes = require("./routes/waf");

var app = express();

app.use(logger("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());

app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.use(
  cors({
    origin: [
      "http://localhost",
      "http://localhost:3000",
      "https://courseflow.pl",
    ],
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH"],
    credentials: true,
  })
);

const swaggerOptions = {
  definition: {
    openapi: "3.0.0",
    info: {
      title: "CourseFlow API",
      version: "1.0.0",
      description: "API Documentation for CourseFlow Learning Platform",
    },
    servers: [{ url: "https://api.courseflow.pl" }],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: "http",
          scheme: "bearer",
          bearerFormat: "JWE",
        },
      },
    },
  },
  apis: ["./routes/*.js"],
};

module.exports = swaggerOptions;

const swaggerSpec = swaggerJsdoc(swaggerOptions);
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));

console.log("🛡️ Inicjalizacja lokalnego WAF...");
app.use(wafMiddleware);

app.use("/api", indexRouter);
app.use("/api/auth", authRouter);
app.use("/api/admin", adminRouter);
app.use("/api/role", roleRouter);
app.use("/api/courses", courseRouter);
app.use("/api/courses", chapterRouter);
app.use("/api/userCourse", userCourseRouter);
app.use("/api/tests", testRouter);
app.use("/api/chapterTest", chapterTestRouter);
app.use("/api", testBlockRouter);
app.use("/api/userTest", userTestRouter);
app.use("/api/certificates", certificateRouter);
app.use("/api/contact", contactRoutes);
app.use("/api/logs", logsRoutes);
app.use("/api/notifications", notificationsRouter);
app.use("/api/partitions", partitionsRouter);
app.use("/api", courseQuestionRoutes);
app.use("/api", courseAnswerRoutes);
app.use("/api/notes", courseNoteRoutes);
app.use("/api/user", userRoutes);
app.use("/api/waf", wafRoutes);

app.use(function (req, res, next) {
  next(createError(404));
});

connectRedis();

module.exports = app;
