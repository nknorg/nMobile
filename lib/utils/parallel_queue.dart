import 'dart:async';

class _QueuedFuture<T> {
  final String? id;
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
  final List<_QueuedFuture> _queue = [];
  final List<Completer<void>> _completeListeners = [];

  final List<String> _delays = [];
  final List<String> _delaysDel = [];

  final String tag;
  final Function(String, bool)? onLog;

  int parallel;
  int _lastProcessId = 0;
  Set<int> activeItems = {};

  final Duration? interval;
  final Duration? timeout;

  Completer? _runComplete;
  bool _isStopped = false;
  bool get isStopped => _isStopped;

  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  ParallelQueue(this.tag, {this.parallel = 1, this.interval, this.timeout, this.onLog});

  int get length => _delays.length + _queue.length;

  Future get onComplete {
    final completer = Completer();
    _completeListeners.add(completer);
    return completer.future;
  }

  void toggle(bool run) {
    if (run) {
      if ((_runComplete != null) && (_runComplete?.isCompleted != true)) {
        _runComplete?.complete();
      }
    } else {
      _runComplete = Completer();
    }
    _isStopped = !run;
  }

  void cancel() {
    _isCancelled = true;
    _queue.removeWhere((item) => item.completer.isCompleted);
  }

  Future<T?> add<T>(Future<T?> Function() func, {String? id, Duration? delay, bool priority = false}) async {
    if (isCancelled) {
      this.onLog?.call("ParallelQueue - add - isCancelled - tag:$tag", true);
      return null;
    }
    if (id != null && id.isNotEmpty && delay != null) {
      _delays.add(id);
      await Future.delayed(delay);
      if (_delaysDel.contains(id)) {
        _delaysDel.remove(id);
        return null;
      } else if (_delays.contains(id)) {
        _delays.remove(id);
      } else {
        return null;
      }
    }
    final completer = Completer<T?>();
    final item = _QueuedFuture<T>(id, func, completer, timeout: timeout);
    if (priority) {
      if (_queue.length > 0) {
        _queue.insert(1, item);
      } else {
        _queue.insert(0, item);
      }
    } else {
      _queue.add(item);
    }
    unawaited(_process());
    return await completer.future;
  }

  bool deleteDelays(String id) {
    bool deleted = false;
    _delays.removeWhere((element) {
      deleted = (element == id) || deleted;
      return deleted;
    });
    _delaysDel.add(id);
    return deleted;
  }

  bool contains(String id) {
    bool find = false;
    _delays.forEach((element) {
      find = (element == id) || find;
    });
    _queue.forEach((element) {
      find = (element.id == id) || find;
    });
    return find;
  }

  Future<void> _process() async {
    if (activeItems.length < parallel) {
      while (true) {
        if (isStopped) {
          this.onLog?.call("ParallelQueue - _process - on progress stop - tag:$tag - _lastProcessId:$_lastProcessId", true);
          if ((_runComplete != null) && (_runComplete?.isCompleted != true)) {
            await _runComplete?.future;
          }
        }
        bool canLoop = await _onQueueNext();
        if (!canLoop) break;
      }
    } else {
      this.onLog?.call("ParallelQueue - _process - on next full - tag:$tag - parallel:$parallel - actives:${activeItems.length}", false);
    }
  }

  Future<bool> _onQueueNext() async {
    if (isCancelled) {
      this.onLog?.call("ParallelQueue - _onQueueNext - on next cancel - tag:$tag - lastProcessId:$_lastProcessId", true);
      return false;
    } else if (_queue.isNotEmpty && (activeItems.length < parallel)) {
      this.onLog?.call("ParallelQueue - _onQueueNext - on next ok - tag:$tag - lastProcessId:$_lastProcessId - actives:${activeItems.length} - parallel:$parallel", false);
      final item = _queue.first;
      _queue.remove(item);
      final processId = _lastProcessId;
      activeItems.add(processId);
      _lastProcessId++;
      Completer c = Completer();
      item.onComplete = () async {
        this.onLog?.call("ParallelQueue - _onQueueNext - on next complete - tag:$tag - _lastProcessId:$_lastProcessId - id:${item.id}", false);
        activeItems.remove(processId);
        if (interval != null) await Future.delayed(interval!);
        c.complete();
      };
      unawaited(item.execute());
      await c.future;
      return true;
    } else if (activeItems.isEmpty && _queue.isEmpty) {
      this.onLog?.call("ParallelQueue - _onQueueNext - on next complete all - tag:$tag - _lastProcessId:$_lastProcessId", false);
      for (final completer in _completeListeners) {
        if (completer.isCompleted != true) {
          completer.complete();
        }
      }
      _completeListeners.clear();
      return !(activeItems.isEmpty && _queue.isEmpty);
    }
    return false;
  }
}

// Don't throw analysis error on unawaited future.
void unawaited(Future<void> future) {}
