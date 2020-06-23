import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nmobile/blocs/cdn/cdn_event.dart';
import 'package:nmobile/blocs/cdn/cdn_state.dart';
import 'package:nmobile/utils/nlog_util.dart';

class CDNBloc extends Bloc<CDNEvent, CDNState> {
  @override
  CDNState get initialState => NormalSate();
  final CDNBloc cdnBloc;

  CDNBloc({@required this.cdnBloc});

  @override
  Stream<CDNState> mapEventToState(CDNEvent event) async* {
    NLog.v(event);
    if (event is LoadData) {
      yield LoadSate(event.data);
    }
  }
}
