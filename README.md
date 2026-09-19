# danmakulx
适用于 MPV 播放器的弹幕加载和管理插件

## ！当前处于前期开发阶段！
| 功能| 实现 |
| --- | --- |
| 基于 ass-overlay 的弹幕渲染 | ok |
| 基于 sub-add 的弹幕渲染 | no |
| bilibili 源支持 | ok |
| bahamut 源支持 | ok |
| dandanplay 源支持 | ok |
| 自动弹幕加载 | no |
| UI 适配 | no |
| 历史记录 | no |

### 试用方法
安装前需先安装依赖库 [elxlib](https://github.com/Erlonealpha/elxlib)

目前可以通过命令行加载弹幕
```shell
# 目前支持解析的 url 类别
# 可以是 bilibili{BV,av,ss,ep} bahamut{sn}
# 例如：
# https://www.bilibili.com/video/BV1YuYR6hEyV
# https://www.bilibili.com/bangumi/play/ss48029
# https://ani.gamer.com.tw/animeVideo.php?sn=51295
# 支持一次性添加多个 url
script-message-to danmakulx test add {url}...
script-message-to danmakulx test add https://www.bilibili.com/video/BV1YuYR6hEyV
```

弹幕显示开关
```shell
# 提供 source_id (源ID) 可以单独开关指定源
script-message-to danmakulx test enable {source_id}?
script-message-to danmakulx test disable {source_id}?
# 显示弹幕
script-message-to danmakulx test enable
# 禁用指定源显示
script-message-to danmakulx test disable bilibili_c41841986977
```

设置弹幕延迟
```shell
# 提供 source_id (源ID) 可以设置指定源
# -10 弹幕提前 10 秒出现
#  10 弹幕延后 10 秒出现
script-message-to danmakulx test set_delay {source_id}?
script-message-to danmakulx test set_delay -7
```

更新渲染设置
```shell
script-message-to danmakulx test update {key} {value}
```
