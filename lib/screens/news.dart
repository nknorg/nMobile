import 'package:flustars/flustars.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:flutter_easyrefresh/material_header.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:nmobile/components/box/body.dart';
import 'package:nmobile/components/label.dart';
import 'package:nmobile/consts/theme.dart';
import 'package:nmobile/helpers/api.dart';
import 'package:nmobile/helpers/utils.dart';
import 'package:nmobile/l10n/localization_intl.dart';
import 'package:nmobile/model/entity/news.dart';
import 'package:nmobile/screens/view/news_header_view.dart';
import 'package:nmobile/utils/image_utils.dart';
import 'package:nmobile/utils/nkn_date_util.dart';

class NewsScreen extends StatefulWidget {
  static const String routeName = '/new/new_page';

  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen>
    with AutomaticKeepAliveClientMixin {
  List<NewsSchema> banners = [];
  List<NewsSchema> lastDatas = [];
  EasyRefreshController _controller;

  @override
  initState() {
    super.initState();
    _controller = EasyRefreshController();
    Future.delayed(Duration(milliseconds: 200), () {
      getData();
    });
  }

  getData() async {
    getCacheData();
    Api().getBanner().then((data) {
      if (mounted && data != null) {
        setState(() {
          banners = data;
          SpUtil.putObjectList('new_banners', data);
        });
      }
    });

    Api().getNews().then((data) {
      if (mounted && data != null) {
        setState(() {
          lastDatas = data;
          SpUtil.putObjectList('lastDatas', data);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: DefaultTheme.primaryColor,
      appBar: NewHeaderPage.getHeader(context),
      body: BodyBox(
        padding: const EdgeInsets.only(top: 4),
        child: EasyRefresh(
          controller: _controller,
          header: MaterialHeader(),
          onRefresh: () async {
            getData();
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: <Widget>[getBannerView(), getListView()],
          ),
        ),
      ),
    );
  }

  getListView() {
    if (lastDatas == null || lastDatas.length == 0) {
      return Container();
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Label(
                    NL10ns.of(context).latest,
                    type: LabelType.h3,
                  ),
                ],
              ),
            ),
            Container(
              child: ListView.builder(
                  itemCount: lastDatas.length,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    NewsSchema newsSchema = lastDatas[index];
                    return Column(
                      children: <Widget>[
                        InkWell(
                          onTap: () {
                            launchURL(getUri(newsSchema.newsId.toString()));
                          },
                          child: Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.w)),
                            child: Row(
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6.w),
                                  child: loadNetworkImage(
                                    newsSchema.image,
                                    fit: BoxFit.cover,
                                    width: 64.h,
                                    height: 64.h,
                                  ),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Label(
                                        newsSchema.title,
                                        type: LabelType.h3,
                                        height: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4.h),
                                      Label(
                                        newsSchema.desc,
                                        type: LabelType.bodyRegular,
                                        color: DefaultTheme.fontColor2,
                                        height: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4.h),
                                      Row(
                                        children: <Widget>[
                                          loadAssetIconsImage(
                                            'calendar',
                                            width: 14,
                                          ),
                                          SizedBox(width: 4.w),
                                          Label(
                                            NknDateUtil.getNewDate(
                                                DateTime.parse(
                                                    newsSchema.time)),
                                            type: LabelType.bodySmall,
                                            color: DefaultTheme.fontColor2,
                                            height: 1.2,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h)
                      ],
                    );
                  }),
            ),
          ],
        ),
      );
    }
  }

  getUri(id) {
    return 'https://forum.nkn.org/t/nkn/' + id;
  }

  getBannerView() {
    if (banners == null || banners.length == 0) {
      return Container(
        width: double.infinity,
        height: 240.h,
      );
    } else {
      return Column(
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.only(top: 16, bottom: 16, left: 20, right: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Label(
                  NL10ns.of(context).featured,
                  type: LabelType.h3,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 240.h,
            child: Swiper(
                autoplay: true,
                autoplayDelay: 4000,
                duration: 100,
                viewportFraction: 0.8,
                scale: 0.9,
                itemCount: banners.length,
                itemBuilder: (BuildContext context, int index) {
                  NewsSchema newsSchema = banners[index];
                  return InkWell(
                    onTap: () {
                      launchURL(getUri(newsSchema.newsId.toString()));
                    },
                    child: Column(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8.w),
                              topRight: Radius.circular(8.w)),
                          child: loadNetworkImage(
                            newsSchema.image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 158.h,
                          ),
                        ),
                        Container(
                          height: 72.h,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(8.w),
                                  bottomRight: Radius.circular(8.w))),
                          child: Flex(
                            direction: Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                flex: 0,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16, right: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(40.w),
                                    child: loadAssetImage('ic_launcher',
                                        width: 30.w, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Label(
                                        newsSchema.title,
                                        type: LabelType.h3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4.h),
                                      Label(
                                        NL10ns.of(context).news_from +
                                            ' NKN.org - ' +
                                            NknDateUtil.getNewDate(
                                                DateTime.parse(
                                                    newsSchema.time)),
                                        type: LabelType.bodyRegular,
                                        color: DefaultTheme.fontColor2,
                                        height: 1,
                                        textAlign: TextAlign.left,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }),
          ),
        ],
      );
    }
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;

  getCacheData() async {
    if (banners == null || banners.length == 0) {
      List<NewsSchema> b =
          SpUtil.getObjList("new_banners", (v) => NewsSchema.fromJson(v));
      List<NewsSchema> l =
          SpUtil.getObjList("lastDatas", (v) => NewsSchema.fromJson(v));
      if (b == null) b = [];
      if (l == null) l = [];
      if (mounted) {
        setState(() {
          this.banners = b;
          this.lastDatas = l;
        });
      }
    }
  }
}
