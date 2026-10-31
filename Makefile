TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Pixel17HUD

Pixel17HUD_FILES = Tweak.x
Pixel17HUD_CFLAGS = -fobjc-arc
Pixel17HUD_FRAMEWORKS = UIKit QuartzCore CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk