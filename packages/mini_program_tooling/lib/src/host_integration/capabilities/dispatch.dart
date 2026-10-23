import 'camera/installer.dart' as camera;
import 'gallery/installer.dart' as gallery;
import 'microphone/installer.dart' as microphone;
import 'file_transfer/installer.dart' as file;
import 'flashlight/installer.dart' as flashlight;
import 'display_brightness/installer.dart' as display_brightness;
import 'location/installer.dart' as location;
import 'media_playback/installer.dart' as media_playback;
import 'models.dart';
import 'qr/installer.dart' as qr;
import 'share/installer.dart' as share;
import 'system/installer.dart' as system;

const String locationCapability = location.locationCapability;
const String fileCapability = file.fileCapability;
const String cameraCapability = camera.cameraCapability;
const String galleryCapability = gallery.galleryCapability;
const String microphoneCapability = microphone.microphoneCapability;
const String flashlightCapability = flashlight.flashlightCapability;
const String displayBrightnessCapability =
    display_brightness.displayBrightnessCapability;
const String qrCapability = qr.qrCapability;
const String shareCapability = share.shareCapability;
const String audioCapability = media_playback.audioCapability;
const String videoCapability = media_playback.videoCapability;
const String androidPlatform = location.androidPlatform;

Future<MiniProgramHostCapabilityInitResult> dispatchHostCapability(
  MiniProgramHostCapabilityInitRequest request,
) async => await switch (request.capability.trim().toLowerCase()) {
  'clipboard' ||
  'vibration' ||
  'phone' ||
  'maps' ||
  'bluetooth' => system.initializeSystemCapability(request),
  'nfc' => system.initializeSystemCapability(request),
  locationCapability => location.initializeMiniProgramHostCapability(request),
  fileCapability => file.initializeMiniProgramHostFileCapability(request),
  cameraCapability => camera.initializeMiniProgramHostCameraCapability(request),
  galleryCapability => gallery.initializeMiniProgramHostGalleryCapability(
    request,
  ),
  microphoneCapability =>
    microphone.initializeMiniProgramHostMicrophoneCapability(request),
  flashlightCapability =>
    flashlight.initializeMiniProgramHostFlashlightCapability(request),
  displayBrightnessCapability =>
    display_brightness.initializeMiniProgramHostDisplayBrightnessCapability(
      request,
    ),
  qrCapability => qr.initializeMiniProgramHostQrCapability(request),
  shareCapability => share.initializeMiniProgramHostShareCapability(request),
  audioCapability || videoCapability =>
    media_playback.initializeMiniProgramHostMediaPlaybackCapability(request),
  _ => throw MiniProgramHostCapabilityException(
    'Unsupported host capability "${request.capability}". Supported '
    'capabilities: $locationCapability, $fileCapability, $cameraCapability, '
    '$flashlightCapability, $displayBrightnessCapability, $qrCapability, $shareCapability, '
    '$audioCapability, $videoCapability, $galleryCapability, $microphoneCapability, clipboard, vibration, phone, maps, bluetooth, nfc.',
  ),
};
