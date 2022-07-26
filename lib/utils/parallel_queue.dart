import 'dart:async';

class _QueuedFuture<T> {
  final String id;
  final Future<T?> Function() func;
  final Completer completer;
  final Duration? timeout;
  Function? onComplete;

  _QueuedFuture(this.id, this.func, this.completer, {this.timeout, this.onComplete});

  bool _timedOut = false;

  Future<void> execute() async {
    try {
      T? result;
      Timer? timeoutTimer;
      if (timeout != null) {
        timeoutTimer = Timer(timeout!, () {
          _timedOut = true;
          onComplete?.call();
        });
      }
      result = await func();
      timeoutTimer?.cancel();
      completer.complete(result);
      await Future.microtask(() {});
    } catch (e) {
      completer.completeError(e);
    } finally {
      if (!_timedOut) onComplete?.call();
    }
  }
}

class ParallelQueue {
  final List<_QueuedFuture> _queues = [];
  final List<Completer<void>> _completeListeners = [];

  final String tag;
  final Function(String)? onLog;

  int parallel;
  int _lastProcessId = 0;
  Set<int> activeItems = {};

  final Duration? delay;
  final Duration? timeout;

  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  ParallelQueue(this.tag, {this.parallel = 1, this.delay, this.timeout, this.onLog});

  Future get onComplete {
    final completer = Completer();
    _completeListeners.add(completer);
    return completer.future;
  }

  void cancel() {
    _isCancelled = true;
    _queues.removeWhere((item) => item.completer.isCompleted);
  }

  Future<T?>? add<T>(String id, Future<T?> Function() closure, {bool priority = false}) {
    if (isCancelled) {
      this.onLog?.call("ParallelQueue - add - isCancelled - tag:$tag");
      return null;
    }
    final completer = Completer<T?>();
    final item = _QueuedFuture<T>(id, closure, completer, timeout: timeout);
    if (priority) {
      _queues.insert(0, item);
    } else {
      _queues.add(item);
    }
    unawaited(_process());
    return completer.future;
  }

  bool delete(String id) {
    bool find = false;
    _queues.removeWhere((element) {
      bool isOK = element.id == id;
      find = isOK || find;
      return isOK;
    });
    return find;
  }

  Future<void> _process() async {
    if (activeItems.length < parallel) {
      _onQueueNext();
    }
  }

  void _onQueueNext() {
    if (isCancelled) {
      this.onLog?.call("ParallelQueue - _onQueueNext - isCancelled - tag:$tag");
    } else if (_queues.isNotEmpty && activeItems.length <= parallel) {
      final processId = _lastProcessId;
      activeItems.add(processId);
      final item = _queues.first;
      _lastProcessId++;
      _queues.remove(item);
      item.onComplete = () async {
        this.onLog?.call("ParallelQueue - _onQueueNext - complete - tag:$tag - id:${item.id}");
        activeItems.remove(processId);
        if (delay != null) await Future.delayed(delay!);
        _onQueueNext();
      };
      unawaited(item.execute());
    } else if (activeItems.isEmpty && _queues.isEmpty) {
      for (final completer in _completeListeners) {
        if (completer.isCompleted != true) {
          completer.complete();
        }
      }
      _completeListeners.clear();
    }
  }
}

// Don't throw analysis error on unawaited future.
void unawaited(Future<void> future) {}
