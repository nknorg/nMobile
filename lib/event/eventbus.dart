import 'package:event_bus/event_bus.dart';

EventBus eventBus = EventBus();

class QMScan {
  String content;
  QMScan(this.content);
}

class AddContactEvent {}
