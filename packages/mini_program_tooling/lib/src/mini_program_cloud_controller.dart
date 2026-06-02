import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'local_cli_state.dart';
import 'miniprogram_doctor.dart';

part 'mini_program_cloud/models.dart';
part 'mini_program_cloud/controller.dart';
part 'mini_program_cloud/aws_stack_settings.dart';
part 'mini_program_cloud/generated_backend_files.dart';
