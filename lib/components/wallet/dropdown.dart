import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_bloc.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_event.dart';
import 'package:nmobile/blocs/wallet/filtered_wallets_state.dart';
import 'package:nmobile/components/dialog/bottom.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/colors.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/format.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/schemas/wallet.dart';
import 'package:nmobile/utils/extensions.dart';
import 'package:nmobile/utils/image_utils.dart';

class WalletDropdown extends StatefulWidget {
  final WalletSchema schema;
  final String title;

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
    var filter = widget.schema != null
        ? (x) => x.address == widget.schema.address
        : null;
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
        // Disable selection, otherwise the page logic becomes very complicated.
        // BottomDialog.of(context).showSelectWalletDialog(title: widget.title);
      },
      child: BlocBuilder<FilteredWalletsBloc, FilteredWalletsState>(
        builder: (context, state) {
          if (state is FilteredWalletsLoaded) {
            var wallet = state.filteredWallets.first;
            return Container(
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: DefaultTheme.backgroundColor2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 0,
                    child: Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colours.light_ff,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: SvgPicture.asset('assets/logo.svg',
                              color: Colours.purple_2e),
                        ).pad(r: 16, t: 12, b: 12),
                        wallet.type == WalletSchema.NKN_WALLET
                            ? Space.empty
                            : Positioned(
                                top: 8,
                                left: 32,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: Colours.purple_53,
                                      shape: BoxShape.circle),
                                  child: SvgPicture.asset(
                                      'assets/ethereum-logo.svg'),
                                ),
                              )
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Label(wallet.name, type: LabelType.h3).pad(b: 4),
                        Label(
                          Format.nknFormat(wallet.balance,
                              decimalDigits: 4, symbol: 'NKN'),
                          type: LabelType.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        wallet.type == WalletSchema.NKN_WALLET
                            ? Container(
                                alignment: Alignment.center,
                                padding: 2.pad(l: 8, r: 8),
                                decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(9)),
                                    color: Colours.green_06_a1p),
                                child: Text(
                                  NL10ns.of(context).mainnet,
                                  style: TextStyle(
                                      color: Colours.green_06,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : Container(
                                alignment: Alignment.center,
                                padding: 2.pad(l: 8, r: 8),
                                decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(9)),
                                    color: Colours.purple_53_a1p),
                                child: Text(
                                  NL10ns.of(context).ERC_20,
                                  style: TextStyle(
                                      color: Colours.purple_53,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                        (wallet.type == WalletSchema.NKN_WALLET
                                ? Space.empty
                                : Label(
                                    Format.nknFormat(wallet.balanceEth,
                                        symbol: 'ETH'),
                                    type: LabelType.bodySmall,
                                  ))
                            .pad(t: 8),
                      ],
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
            );
          } else {
            return null;
          }
        },
      ),
    );
  }
}
