import axios from 'axios';
import { config } from '../config';

/**
 * Notify the user via the Notification Service
 */
export const notifyUser = async (user_id: string, title: string, message: string, data?: any) => {
  try {
    await axios.post(`${config.notificationServiceUrl}/notifications/push`, {
      user_id,
      title,
      message,
      data
    });
    console.log(`[Notification] Sent push to ${user_id}: ${title}`);
  } catch (error) {
    console.error(`[Notification Error] Failed to notify ${user_id}:`, error);
  }
};
