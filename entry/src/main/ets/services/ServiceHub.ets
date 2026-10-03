import { AudioService } from './AudioService';

// Lets the ability (which owns the app lifecycle) reach the listening service created by the UI.
export class ServiceHub {
  static audio: AudioService | undefined = undefined;
}
