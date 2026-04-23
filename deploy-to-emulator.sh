#关闭模拟器上的 app：
# 命令行方式
~/Library/Android/sdk/platform-tools/adb shell am force-stop com.yingxi.microscope_app
#模拟器上也可以点击底部导航栏的 方块图标（Recent Apps），然后向上滑动关闭。
# 1. 构建 APK（在 microscopy-front 目录下）
flutter build apk --debug

# 2. 安装到模拟器
~/Library/Android/sdk/platform-tools/adb install build/app/outputs/flutter-apk/app-debug.apk

