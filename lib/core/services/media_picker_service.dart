import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class PickedFile {
  const PickedFile({required this.file, required this.name, required this.size});
  final File file;
  final String name;
  final int size;
}

class PickedLocation {
  const PickedLocation(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Wraps device pickers so UI code stays free of plugin details.
class MediaPickerService {
  MediaPickerService({ImagePicker? imagePicker}) : _imagePicker = imagePicker ?? ImagePicker();
  final ImagePicker _imagePicker;

  Future<File?> pickImage({bool camera = false}) async {
    final x = await _imagePicker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 2048,
    );
    return x == null ? null : File(x.path);
  }

  Future<List<File>> pickMultiImages() async {
    final list = await _imagePicker.pickMultiImage(imageQuality: 82, maxWidth: 2048, limit: 10);
    return list.map((x) => File(x.path)).toList();
  }

  Future<File?> pickVideo({bool camera = false}) async {
    final x = await _imagePicker.pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    return x == null ? null : File(x.path);
  }

  Future<PickedFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final f = result?.files.single;
    if (f == null || f.path == null) return null;
    return PickedFile(file: File(f.path!), name: f.name, size: f.size);
  }

  /// Returns the current location, asking for permission when needed.
  /// Throws a [String] message the UI can show if unavailable.
  Future<PickedLocation> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are turned off.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw 'Location permission was denied.';
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return PickedLocation(pos.latitude, pos.longitude);
  }
}
