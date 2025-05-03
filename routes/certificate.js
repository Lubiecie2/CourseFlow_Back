const express = require("express");
const router = express.Router();
const certificateController = require("../controllers/certificateController");
const authMiddleware = require("../middleware/authMiddleware");

router.get(
  "/eligibility/:courseId",
  authMiddleware,
  certificateController.checkEligibility
);

router.post(
  "/generate/:courseId",
  authMiddleware,
  certificateController.generateCertificate
);

router.get("/user", authMiddleware, certificateController.getUserCertificates);

router.get(
  "/download/:certificateCode",
  authMiddleware,
  certificateController.downloadCertificate
);

module.exports = router;
