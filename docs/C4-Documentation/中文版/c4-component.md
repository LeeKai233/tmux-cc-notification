# C4 组件索引

## 系统组件

| 组件 | 描述 | 文档 |
|-----------|-------------|---------------|
| Hook 事件处理器 | 处理 Claude Code 生命周期事件 | [c4-component-hook-handler.md](c4-component-hook-handler.md) |
| Windows 通知 | 发送 Windows Toast 通知 | [c4-component-windows-notification.md](c4-component-windows-notification.md) |
| 配置 | 管理应用设置 | [c4-component-configuration.md](c4-component-configuration.md) |
| 安装与测试 | 安装与验证脚本 | [c4-component-installation.md](c4-component-installation.md) |

## 组件关系图

```mermaid
C4Component
    title 组件图 - tmux-cc-notification

    Container_Boundary(wsl, "WSL2（Bash）") {
        Component(hooks, "Hook 事件处理器", "Bash", "处理 Claude Code 事件")
        Component(config, "配置", "Bash/TOML", "管理设置")
        Component(install, "安装与测试", "Bash", "安装与验证")
    }

    Container_Boundary(win, "Windows（PowerShell）") {
        Component(notify, "Windows 通知", "PowerShell", "Toast 通知")
    }

    System_Ext(claude, "Claude Code", "AI 编码助手")
    System_Ext(toast, "Windows Toast API", "通知系统")
    System_Ext(tmux, "tmux", "终端复用器")

    Rel(claude, hooks, "Hook 事件", "JSON/stdin")
    Rel(hooks, config, "读取设置")
    Rel(hooks, notify, "发送通知", "pwsh.exe")
    Rel(notify, toast, "显示 Toast", "BurntToast")
    Rel(notify, tmux, "切换窗格", "wsl tmux")
    Rel(install, hooks, "配置")
    Rel(install, notify, "注册协议")
```

## 数据流

```mermaid
flowchart LR
    subgraph "输入"
        CC[Claude Code]
        User[用户配置]
    end

    subgraph "处理"
        Hooks[Hook 事件处理器]
        Config[配置]
    end

    subgraph "输出"
        Notify[Windows 通知]
        State[状态文件]
    end

    subgraph "外部系统"
        Toast[Windows Toast]
        Terminal[Windows Terminal]
    end

    CC -->|JSON 事件| Hooks
    User -->|TOML 文件| Config
    Config -->|环境变量| Hooks
    Hooks -->|通知请求| Notify
    Hooks -->|持久化| State
    Notify -->|显示| Toast
    Toast -->|点击| Notify
    Notify -->|聚焦| Terminal
```

## 组件依赖矩阵

| 组件 | Hook 事件处理器 | Windows 通知 | 配置 | 安装与测试 |
|-----------|:------------:|:----------------:|:-------------:|:------------:|
| Hook 事件处理器 | - | 使用 | 使用 | - |
| Windows 通知 | - | - | - | - |
| 配置 | - | - | - | - |
| 安装与测试 | 配置 | 注册 | 使用 | - |

## 代码级文档索引

| 目录 | 文档 | 描述 |
|-----------|---------------|-------------|
| lib/ | [c4-code-lib.md](c4-code-lib.md) | 核心库模块 |
| hooks/ | [c4-code-hooks.md](c4-code-hooks.md) | Claude Code hook 脚本 |
| ps/ | [c4-code-ps.md](c4-code-ps.md) | PowerShell 脚本 |
| scripts/ | [c4-code-scripts.md](c4-code-scripts.md) | 安装脚本 |
| (root) | [c4-code-root.md](c4-code-root.md) | 配置加载器 |
