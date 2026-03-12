const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { prisma } = require('../lib/prisma');

const router = express.Router();

const uploadDir = path.join(process.cwd(), 'uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_, __, cb) => cb(null, uploadDir),
  filename: (_, file, cb) => {
    const safeName = Date.now() + '-' + file.originalname.replace(/\s+/g, '-');
    cb(null, safeName);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
});

router.post('/tickets/:id/attachments', upload.single('file'), async (req, res) => {
  try {
    const ticketId = req.params.id;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    const attachment = await prisma.attachment.create({
      data: {
        ticketId,
        uploadedById: req.user.id,
        originalName: file.originalname,
        storedName: file.filename,
        mimeType: file.mimetype,
        size: file.size,
        path: file.path,
      },
    });

    res.json({ data: attachment });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to upload attachment' });
  }
});

module.exports = router;