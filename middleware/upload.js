const multer = require("multer");
const path = require("path");
const fs = require("fs");

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, path.join(__dirname, "../uploads"));
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, file.fieldname + "-" + uniqueSuffix + ext);
  },
});

const fileFilter = (req, file, cb) => {
  const imageTypes = ["image/jpeg", "image/png", "image/gif", "image/webp"];

  const videoTypes = [
    "video/mp4",
    "video/webm",
    "video/ogg",
    "video/quicktime",
  ];

  if (imageTypes.includes(file.mimetype)) {
    cb(null, true);
  } else if (videoTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(
      new Error(
        "Niedozwolony format pliku. Akceptujemy tylko JPG, PNG, GIF, WEBP, MP4, WEBM, OGG i MOV."
      ),
      false
    );
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 100 * 1024 * 1024,
  },
});

module.exports = upload;
