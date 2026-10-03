import { vibrator } from '@kit.SensorServiceKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { AlertPort } from './SoundPipeline';

const LOG_DOMAIN: number = 0x3201;
const TAG: string = 'AlertService';
const SHORT_PULSE_MS: number = 300;
const LONG_PULSE_MS: number = 500;
const LONG_PULSE_COUNT: number = 3;
const LONG_PULSE_GAP_MS: number = 250;

function twoDigits(n: number): string {
  return n < 10 ? '0' + n : n.toString();
}

function clock(ms: number): string {
  const d = new Date(ms);
  return twoDigits(d.getHours()) + ':' + twoDigits(d.getMinutes()) + ':' + twoDigits(d.getSeconds());
}

// Vibration and notifications. Everything degrades silently when unavailable: an alert problem must never
// interrupt listening.
export class AlertService implements AlertPort {
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

  // One short pulse for a sound the user has not named.
  vibrateUnknown(): void {
    this.pulse(SHORT_PULSE_MS);
  }

  // Three long pulses: distinct from the short one and long enough to notice in a pocket.
  vibrateNamed(): void {
    for (let i = 0; i < LONG_PULSE_COUNT; i++) {
      setTimeout((): void => {
        this.pulse(LONG_PULSE_MS);
      }, i * (LONG_PULSE_MS + LONG_PULSE_GAP_MS));
    }
  }

  notifyNamed(name: string, timeMs: number): void {
    this.publish(name + ' detected', 'at ' + clock(timeMs));
  }

  notifyPrompt(): void {
    this.publish("I've heard this sound before", "Do you want to name it? Open Safe'n'Sound.");
  }

  private publish(title: string, text: string): void {
    notificationManager.publish({
      id: this.nextNotificationId++,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: title, text: text }
      }
    }).catch((e: Object): void => {
      hilog.warn(LOG_DOMAIN, TAG, 'Could not publish notification: %{public}s', JSON.stringify(e));
    });
  }

  private pulse(durationMs: number): void {
    vibrator.startVibration({ type: 'time', duration: durationMs }, { id: 0, usage: 'alarm' })
      .catch((e: Object): void => {
        hilog.warn(LOG_DOMAIN, TAG, 'Vibration failed: %{public}s', JSON.stringify(e));
      });
  }
}
