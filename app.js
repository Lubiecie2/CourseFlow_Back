var createError = require("http-errors");
var express = require("express");
var path = require("path");
var cookieParser = require("cookie-parser");
var logger = require("morgan");
const swaggerJsdoc = require("swagger-jsdoc");
const swaggerUi = require("swagger-ui-express");
const bcrypt = require("bcryptjs");

const cors = require("cors");
const pool = require("./models/db");

const adminRouter = require("./routes/admin");
var indexRouter = require("./routes/index");
const authRouter = require("./routes/auth");
const roleRouter = require("./routes/role");

var app = express();

app.use(logger("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());

app.use(
  cors({
    origin: ["http://localhost", "http://localhost:3000"],
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
    servers: [{ url: "http://localhost:4000" }],
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

app.use("/api", indexRouter);
app.use("/api/auth", authRouter);
app.use("/api/admin", adminRouter);
app.use("/api/role", roleRouter);

app.use(function (req, res, next) {
  next(createError(404));
});

module.exports = app;
