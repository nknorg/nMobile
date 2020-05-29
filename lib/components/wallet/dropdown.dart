import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_event.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_state.dart';
import 'package:nmobile/blocs/wallet/wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/wallets_state.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/utils/image_utils.dart';

class WalletDropdown extends StatefulWidget {
  WalletSchema schema;
  String title;
  WalletDropdown({this.schema, this.title});

  @override
  _WalletDropdownState createState() => _WalletDropdownState();
}

class _WalletDropdownState extends State<WalletDropdown> {
  FilteredWalletsBloc _filteredWalletsBloc;

  @override
  void initState() {
    super.initState();
    _filteredWalletsBloc = BlocProvider.of<FilteredWalletsBloc>(context);
    var filter = widget.schema != null ? (x) => x.address == widget.schema.address : null;
    _filteredWalletsBloc.add(LoadWalletFilter(filter));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        BottomDialog.of(context).showSelectWalletDialog(title: widget.title);
      },
      child: BlocBuilder<FilteredWalletsBloc, FilteredWalletsState>(
        builder: (context, state) {
          if (state is FilteredWalletsLoaded) {
            var wallet = state.filteredWallets.first;
            return Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: DefaultTheme.backgroundColor2)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Flex(
                  direction: Axis.horizontal,
                  children: <Widget>[
                    Expanded(
                      flex: 0,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(0xFFF1F4FF),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: SvgPicture.asset('assets/logo.svg', color: Color(0xFF253A7E)),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        height: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Label(
                                wallet.name,
                                type: LabelType.h3,
                              ),
                              BlocBuilder<WalletsBloc, WalletsState>(
                                builder: (context, state) {
                                  if (state is WalletsLoaded) {
                                    var w = state.wallets.firstWhere((x) => x == wallet, orElse: () => null);
                                    if (w != null) {
                                      return Label(
                                        Format.nknFormat(w == null ? "0" : w.balance, decimalDigits: 4, symbol: 'NKN'),
                                        type: LabelType.bodySmall,
                                      );
                                    }
                                  }
                                  return Label(
                                    '- NKN',
                                    type: LabelType.bodySmall,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 0,
                      child: Container(
                        alignment: Alignment.centerRight,
                        height: 44,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Container(
                                height: 18,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.only(left: 8, right: 8),
                                decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(8)), color: Color(0x1500CC96)),
                                child: Text(NMobileLocalizations.of(context).mainnet, style: TextStyle(color: Color(0xFF00CC96), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 0,
                      child: Container(
                        alignment: Alignment.centerRight,
                        height: 44,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: loadAssetIconsImage(
                            'down2',
                            width: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return null;
          }
        },
      ),
    );
  }
}
