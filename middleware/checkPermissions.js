const db = require("../models/db");
const User = require("../models/userModel");
const Role = require("../models/roleModel");

const checkPermission = (requiredPermissions) => {
  return async (req, res, next) => {
    try {
      if (!req.user || !req.user.id) {
        return res.status(401).json({
          success: false,
          message: "Wymagane uwierzytelnienie",
        });
      }

      const userId = req.user.id;
      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: "Użytkownik nie został znaleziony",
        });
      }

      req.user.role_id = user.role_id;

      const userPermissionsData = await Role.getPermissionByRole(user.role_id);
      const userPermissions = userPermissionsData.map((p) => p.name);

      const permissions = Array.isArray(requiredPermissions)
        ? requiredPermissions
        : [requiredPermissions];

      const hasAllRequiredPermissions = permissions.every((permission) => {
        const has = userPermissions.includes(permission);
        return has;
      });

      if (!hasAllRequiredPermissions) {
        console.log("Odmowa dostępu - brak wymaganych uprawnień");
        return res.status(403).json({
          success: false,
          message: "Brak wymaganych uprawnień do wykonania tej operacji",
        });
      }

      console.log("Weryfikacja uprawnień zakończona pomyślnie");
      next();
    } catch (error) {
      console.error("Błąd podczas sprawdzania uprawnień:", error);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas weryfikacji uprawnień",
      });
    }
  };
};

module.exports = checkPermission;
