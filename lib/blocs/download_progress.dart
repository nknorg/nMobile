import 'package:bloc/bloc.dart';

class DownloadProgressBloc extends Bloc<double, DownloadState> {
  @override
  DownloadState get initialState => DownloadState();

  @override
  Stream<DownloadState> mapEventToState(double event) async* {
    yield DownloadState(progress: event);
  }
}

class DownloadState {
  double progress;

  // ignore: avoid_init_to_null
  DownloadState({this.progress = null});
}
