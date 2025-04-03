const express = require("express");
const router = express.Router();
const courseController = require("../controllers/courseController");
const authMiddleware = require("../middleware/authMiddleware");
const upload = require("../middleware/upload");

router.post(
  "/",
  authMiddleware,
  upload.single("image"),
  courseController.createCourse
);

router.get("/", courseController.getAllCourses);

router.get("/uploads", express.static("public/uploads"));

router.get("/:id", authMiddleware, courseController.getCourseById);

router.patch(
  "/:id",
  authMiddleware,
  upload.single("image"),
  courseController.updateCourse
);

module.exports = router;
