const express = require("express");
const router = express.Router();
const testBlockController = require("../controllers/testBlockController");
const authMiddleware = require("../middleware/authMiddleware");

router.post(
  "/tests/:testId/blocks",
  authMiddleware,
  testBlockController.createTestBlock
);

router.get(
  "/tests/:testId/blocks",
  authMiddleware,
  testBlockController.getTestBlocksByTest
);

router.get(
  "/blocks/:blockId",
  authMiddleware,
  testBlockController.getTestBlock
);

router.delete(
  "/blocks/:blockId",
  authMiddleware,
  testBlockController.deleteTestBlock
);

module.exports = router;
