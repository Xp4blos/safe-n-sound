import { vibrator } from '@kit.SensorServiceKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const LOG_DOMAIN: number = 0x3201;
const TAG: string = 'AlertService';
const PULSE_MS: number = 300;
const PULSE_GAP_MS: number = 150;

// Vibration on every detection, notification for named sounds. Both degrade silently when unavailable.
export class AlertService {
  private nextNotificationId: number = 1000;

  // Resolves to whether notifications may be shown, asking the user once if they have not decided yet.
  async ensureNotificationPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      if (await notificationManager.isNotificationEnabled()) {
        return true;
      }
      await notificationManager.requestEnableNotification(context);
      return await notificationManager.isNotificationEnabled();
    } catch (e) {
      hilog.warn(LOG_DOMAIN, TAG, 'Notifications not enabled: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  // Two short pulses. Failures are swallowed: a vibration problem must never interrupt listening.
  vibrate(): void {
    this.pulse();
    setTimeout((): void => {
      this.pulse();
    }, PULSE_MS + PULSE_GAP_MS);
  }

  async notifyKnownSound(name: string): Promise<void> {
    try {
      await notificationManager.publish({
        id: this.nextNotificationId++,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: name,
            text: 'Heard again'
          }
        }
      });
    } catch (e) {
      hilog.warn(LOG_DOMAIN, TAG, 'Could not publish notification: %{public}s', JSON.stringify(e));
    }
  }

  private pulse(): void {
    vibrator.startVibration({ type: 'time', duration: PULSE_MS }, { id: 0, usage: 'alarm' })
      .catch((e: Object): void => {
        hilog.warn(LOG_DOMAIN, TAG, 'Vibration failed: %{public}s', JSON.stringify(e));
      });
  }
}
