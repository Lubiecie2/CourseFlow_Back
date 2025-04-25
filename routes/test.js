const express = require("express");
const router = express.Router();
const testController = require("../controllers/testController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/:testId", authMiddleware, testController.getTest);
router.patch("/:testId", authMiddleware, testController.updateTest);
router.delete("/:testId", authMiddleware, testController.deleteTest);

module.exports = router;
