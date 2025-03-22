const checkAdmin = (req, res, next) => {
  console.log(req.user.role);
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Access denied" });
  }
  next();
};

module.exports = checkAdmin;
