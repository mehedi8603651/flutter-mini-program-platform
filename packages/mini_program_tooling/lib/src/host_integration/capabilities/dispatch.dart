import 'camera/installer.dart' as camera;
import 'file_transfer/installer.dart' as file;
import 'flashlight/installer.dart' as flashlight;
import 'location/installer.dart' as location;
import 'media_playback/installer.dart' as media_playback;
import 'models.dart';
import 'qr/installer.dart' as qr;

const String locationCapability = location.locationCapability;
const String fileCapability = file.fileCapability;
const String cameraCapability = camera.cameraCapability;
const String flashlightCapability = flashlight.flashlightCapability;
const String qrCapability = qr.qrCapability;
const String audioCapability = media_playback.audioCapability;
const String videoCapability = media_playback.videoCapability;
const String androidPlatform = location.androidPlatform;

Future<MiniProgramHostCapabilityInitResult> dispatchHostCapability(
  MiniProgramHostCapabilityInitRequest request,
) async => await switch (request.capability.trim().toLowerCase()) {
  locationCapability => location.initializeMiniProgramHostCapability(request),
  fileCapability => file.initializeMiniProgramHostFileCapability(request),
  cameraCapability => camera.initializeMiniProgramHostCameraCapability(request),
  flashlightCapability =>
    flashlight.initializeMiniProgramHostFlashlightCapability(request),
  qrCapability => qr.initializeMiniProgramHostQrCapability(request),
  audioCapability || videoCapability =>
    media_playback.initializeMiniProgramHostMediaPlaybackCapability(request),
  _ => throw MiniProgramHostCapabilityException(
    'Unsupported host capability "${request.capability}". Supported '
    'capabilities: $locationCapability, $fileCapability, $cameraCapability, '
    '$flashlightCapability, $qrCapability, $audioCapability, $videoCapability.',
  ),
};
