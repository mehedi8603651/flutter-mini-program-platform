/// Stable wire names for host-dispatched mobile MVP actions.
abstract final class ActionNames {
  static const String openNativeScreen = 'openNativeScreen';
  static const String callSecureApi = 'callSecureApi';
  static const String trackEvent = 'trackEvent';
  static const String openMiniProgramScreen = 'openMiniProgramScreen';
  static const String replaceMiniProgramScreen = 'replaceMiniProgramScreen';
  static const String popMiniProgramScreen = 'popMiniProgramScreen';
  static const String resetMiniProgramStack = 'resetMiniProgramStack';
  static const String popToMiniProgramRoot = 'popToMiniProgramRoot';
  static const String popToMiniProgramScreen = 'popToMiniProgramScreen';
  static const String locationGetCurrent = 'location.getCurrent';
  static const String fileUpload = 'file.upload';
  static const String fileDownload = 'file.download';
  static const String fileCancel = 'file.cancel';
  static const String cameraCapturePhoto = 'camera.capturePhoto';
  static const String cameraCancel = 'camera.cancel';
  static const String mediaRelease = 'media.release';
  static const String flashlightTurnOn = 'flashlight.turnOn';
  static const String flashlightTurnOff = 'flashlight.turnOff';
  static const String flashlightToggle = 'flashlight.toggle';
  static const String flashlightGetStatus = 'flashlight.getStatus';
  static const String qrScan = 'qr.scan';
}
