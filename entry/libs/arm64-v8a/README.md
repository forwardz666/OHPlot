# entry/libs/arm64-v8a

此目录由 `scripts/deploy-libs.sh` 自动填充，勿手工维护。内容包括：

| 库 | 来源 |
|----|------|
| libscidavis.so（导出 main 的应用库）| scripts/build-scidavis.sh 构建产物 |
| liblibscidavis.so、libqwt*.so、libfitplugins 等 | 同上 |
| libgsl.so / libgslcblas.so / libmuparser.so / libz.so | scripts/build-deps.sh |
| libQt5Core/Gui/Widgets/Xml/Svg/PrintSupport/OpenGL.so | Qt for OpenHarmony SDK 的 lib/ |
| libqohos.so（外层 + platforms/ 各一份）| Qt SDK 的 plugins/platforms/ |

所有 .so 必须经 `binary-sign-tool -selfSign 1` 签名后才能装入真机。

图标占位：请把 SciDAVis 图标放到 `../src/main/resources/base/media/app_icon.png`。
