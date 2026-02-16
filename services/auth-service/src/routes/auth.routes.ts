import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { config } from '../config';
import * as authController from '../controllers/auth.controller';
import {
  registerValidation,
  loginValidation,
  refreshTokenValidation,
} from '../middleware/validate';
import { asyncHandler } from '@lessgo/shared';

const router = express.Router();

// Create upload directory if it doesn't exist
const uploadDir = config.sjsuIdUploadDir;
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Configure multer for SJSU ID image uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, `sjsu-id-${uniqueSuffix}${ext}`);
  },
});

const fileFilter = (req: Express.Request, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  // Accept images only
  const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif'];

  if (allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only JPEG, PNG, and GIF are allowed.'));
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: config.maxFileSize, // 5MB
  },
});

/**
 * @route   POST /auth/register
 * @desc    Register a new user with optional SJSU ID upload
 * @access  Public
 */
router.post(
  '/register',
  upload.single('sjsuId'),
  registerValidation,
  asyncHandler(authController.register)
);

/**
 * @route   POST /auth/login
 * @desc    Login user and return tokens
 * @access  Public
 */
router.post('/login', loginValidation, asyncHandler(authController.login));

/**
 * @route   POST /auth/refresh
 * @desc    Refresh access token using refresh token
 * @access  Public
 */
router.post('/refresh', refreshTokenValidation, asyncHandler(authController.refreshToken));

/**
 * @route   GET /auth/verify
 * @desc    Verify token validity
 * @access  Public
 */
router.get('/verify', asyncHandler(authController.verifyTokenEndpoint));

/**
 * @route   POST /auth/logout
 * @desc    Logout user (client-side token deletion)
 * @access  Public
 */
router.post('/logout', asyncHandler(authController.logout));

/**
 * @route   GET /auth/me
 * @desc    Get current user from token
 * @access  Public (requires token)
 */
router.get('/me', asyncHandler(authController.getCurrentUser));

/**
 * @route   POST /auth/test/verify/:userId
 * @desc    Test-only: verify a user's SJSU ID status
 * @access  Development only
 */
if (config.env !== 'production') {
  router.post('/test/verify/:userId', asyncHandler(authController.testVerifyUser));
}

export default router;
