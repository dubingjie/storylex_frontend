import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api.dart';
import 'core/session_store.dart';
import 'core/learning_store.dart';
import 'state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    StoryLexRepository(ApiClient()),
    DeviceSessionStore(),
    learningStore: DeviceLearningStore(),
  );
  runApp(StoryLexApp(controller: controller));
  controller.bootstrap();
}
