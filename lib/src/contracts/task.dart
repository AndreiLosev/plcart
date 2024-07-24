abstract class PeriodicTask {
  Duration get period => const Duration(milliseconds: 100);
  void execute();
}

abstract class EventTask<T extends Event> {
  Set<Type> get eventSubscriptions => {T};
  void execute(T event);
}

abstract class Event {
}
