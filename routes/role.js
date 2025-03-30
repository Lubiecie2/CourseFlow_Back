const express = require("express");
const router = express.Router();
const adminController = require("../controllers/roleController");
const authMiddleware = require("../middleware/authMiddleware");
const checkAdmin = require("../middleware/checkAdmin");
const roleController = require("../controllers/roleController");

router.post(
  "/createrole",
  authMiddleware,
  checkAdmin,
  adminController.createRole
);

router.get(
  "/getrole",
  authMiddleware,
  checkAdmin,
  adminController.getRolesWithPermissions
);

router.get(
  "/permissions",
  authMiddleware,
  checkAdmin,
  adminController.getPermissions
);

router.patch(
  "/updaterole/:roleId",
  authMiddleware,
  checkAdmin,
  adminController.updateRole
);
module.exports = router;
