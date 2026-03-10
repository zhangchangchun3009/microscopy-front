# 显微镜代理 — Flutter macOS 客户端

智能显微镜代理系统的桌面前端，运行在 Mac 上，通过 WebSocket 与树莓派上的 MicroClaw Agent 交互，同时显示显微镜实时视频流。

## 功能

- **实时视频流**：通过 MJPEG 协议显示显微镜摄像头画面
- **Agent 对话**：文本输入框发送自然语言指令，Agent 自主调用显微镜工具执行
- **工具调用可视化**：展示 Agent 的工具调用过程（调用参数、执行结果），可展开查看详情
- **连接管理**：支持自定义 WebSocket 和视频流地址，实时显示连接状态

## 架构

```
Flutter (Mac)  ──WebSocket──>  MicroClaw (Pi)  ──MCP──>  microscopy_server (Pi)
     │                                                          │
     └──────────────── MJPEG 视频流 ────────────────────────────┘
```

## 默认配置

| 参数 | 默认值 |
|------|--------|
| WebSocket 地址 | `ws://10.198.31.242:42617/ws/chat` |
| 视频流地址 | `http://10.198.31.242:5000/video_feed` |

可在应用内通过设置按钮修改。

## 运行

```bash
flutter pub get
flutter run -d macos
```

## 依赖

- `flutter_mjpeg` — MJPEG 视频流渲染
- `web_socket_channel` — WebSocket 通信

## WebSocket 消息协议

客户端发送：
```json
{"type": "message", "content": "自动对焦"}
```

服务端推送：
```json
{"type": "chunk", "content": "正在执行..."}
{"type": "tool_call", "name": "fast_focus", "args": {"steps": 200}}
{"type": "tool_result", "name": "fast_focus", "output": "..."}
{"type": "done", "full_response": "自动对焦已完成，Z轴位置 10.5mm"}
```
