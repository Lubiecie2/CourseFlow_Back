const express = require("express");
const router = express.Router();
const partitionController = require("../controllers/partitionController");
const authMiddleware = require("../middleware/authMiddleware");

router.get("/", authMiddleware, partitionController.getPartitions);

router.post("/", authMiddleware, partitionController.createPartition);

router.post("/detach", authMiddleware, partitionController.detachPartition);

router.post("/attach", authMiddleware, partitionController.attachPartition);

router.post("/prepare", authMiddleware, partitionController.preparePartitions);

module.exports = router;
