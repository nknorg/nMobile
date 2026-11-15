.DEFAULT_GOAL:=all

USE_PROXY=GOPROXY=https://goproxy.io
GOMOBILE=gomobile
GOBIND=$(GOMOBILE) bind
BUILDDIR=$(shell pwd)/build
IMPORT_PATH=nkn
LDFLAGS='-s -w -extldflags=-lresolv -checklinkname=0'
ANDROID_LDFLAGS='-s -w -extldflags=-Wl,-z,max-page-size=16384 -checklinkname=0'

ANDROID_BUILDDIR=$(BUILDDIR)/android
ANDROID_ARTIFACT=$(ANDROID_BUILDDIR)/nkn.aar
IOS_BUILDDIR=$(BUILDDIR)/ios
IOS_ARTIFACT=$(IOS_BUILDDIR)/Nkn.xcframework

BUILD_PACKAGE=./ ./crypto ./search github.com/nknorg/nkn-sdk-go github.com/nknorg/ncp-go github.com/nknorg/nkn/v2/transaction github.com/nknorg/nkngomobile github.com/nknorg/reedsolomon github.com/nknorg/eth-resolver-go github.com/nknorg/dns-resolver-go
ANDROID_BUILD_CMD="$(GOBIND) -ldflags $(ANDROID_LDFLAGS) -target=android -androidapi=21 -o $(ANDROID_ARTIFACT) $(BUILD_PACKAGE)"
IOS_BUILD_CMD="$(GOBIND) -ldflags $(LDFLAGS) -target=ios -o $(IOS_ARTIFACT) $(BUILD_PACKAGE)"


define build
	mkdir -p $(1)
	eval $(2)
endef

.PHONY: mobile android ios clean

mobile: android ios

android:
	$(call build,$(ANDROID_BUILDDIR),$(ANDROID_BUILD_CMD))
	rm -rf ../android/golib/nkn.aar
	rm -rf ../android/golib/nkn-sources.jar
	mv $(ANDROID_BUILDDIR)/nkn.aar ../android/golib/
	mv $(ANDROID_BUILDDIR)/nkn-sources.jar ../android/golib/
ios:
	$(call build,$(IOS_BUILDDIR),$(IOS_BUILD_CMD))
	rm -rf ../plugins/nkn-sdk-flutter/ios/Frameworks/Nkn.xcframework/
	mv $(IOS_BUILDDIR)/Nkn.xcframework ../plugins/nkn-sdk-flutter/ios/Frameworks/
clean:
	rm -rf $(BUILDDIR)