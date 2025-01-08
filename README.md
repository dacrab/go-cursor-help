# 🚀 Cursor Free Trial Reset Tool

<div align="center">

[![Release](https://img.shields.io/github/v/release/mvbureev/go-cursor-help?style=flat-square&logo=github&color=blue)](https://github.com/mvbureev/go-cursor-help/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square&logo=bookstack)](https://github.com/mvbureev/go-cursor-help/blob/master/LICENSE)
[![Stars](https://img.shields.io/github/stars/mvbureev/go-cursor-help?style=flat-square&logo=github)](https://github.com/mvbureev/go-cursor-help/stargazers)

[🌟 English](#english) | [🌏 中文](#chinese)

<img src="https://ai-cursor.com/wp-content/uploads/2024/09/logo-cursor-ai-png.webp" alt="Cursor Logo" width="120"/>

### 💬 WeChat Support
<img src="img/wx_public.jpg" alt="WeChat Support" width="200"/>
<img src="img/wx_public_2.png" alt="WeChat Support 2" width="200"/>

</div>

---

## 🌟 English

### 📝 Description

Resets Cursor's free trial limitation when you see:
```text
Too many free trial accounts used on this machine.
Please upgrade to pro. We have this limit in place
to prevent abuse. Please let us know if you believe
this is a mistake.
```

### 💻 System Support

| Windows | macOS | Linux |
|---------|--------|--------|
| ✅ 64-bit & 32-bit | ✅ Intel & Apple Silicon | ✅ x64, ARM64 & 32-bit |

### 🚀 Quick Install

**Linux/macOS**
```bash
curl -fsSL https://raw.githubusercontent.com/yuaotian/go-cursor-help/master/scripts/install.sh | sudo bash
```

**Windows**
```powershell
irm https://raw.githubusercontent.com/yuaotian/go-cursor-help/master/scripts/install.ps1 | iex
```

### 🔧 Technical Details

<details>
<summary><b>Configuration Files</b></summary>

`storage.json` locations:
- Windows: `%APPDATA%\Cursor\User\globalStorage\storage.json`
- macOS: `~/Library/Application Support/Cursor/User/globalStorage/storage.json`
- Linux: `~/.config/Cursor/User/globalStorage/storage.json`
</details>

<details>
<summary><b>Modified Fields</b></summary>

- `telemetry.machineId`
- `telemetry.macMachineId`
- `telemetry.devDeviceId`
- `telemetry.sqmId`
</details>

---

## 🌏 中文

### 📝 问题描述

当看到以下提示时重置Cursor试用期：
```text
Too many free trial accounts used on this machine.
```

### 💻 系统支持

| Windows | macOS | Linux |
|---------|--------|--------|
| ✅ 64/32位 | ✅ Intel/M系列 | ✅ x64/ARM64/32位 |

### 🚀 快速安装

**Linux/macOS**
```bash
curl -fsSL https://raw.githubusercontent.com/mvbureev/go-cursor-help/master/scripts/install.sh | sudo bash
```

**Windows**
```powershell
irm https://raw.githubusercontent.com/mvbureev/go-cursor-help/master/scripts/install.ps1 | iex
```

### 🔧 技术细节

<details>
<summary><b>配置文件</b></summary>

`storage.json` 位置:
- Windows: `%APPDATA%\Cursor\User\globalStorage\storage.json`
- macOS: `~/Library/Application Support/Cursor/User/globalStorage/storage.json`
- Linux: `~/.config/Cursor/User/globalStorage/storage.json`
</details>

<details>
<summary><b>修改字段</b></summary>

- `telemetry.machineId`
- `telemetry.macMachineId`
- `telemetry.devDeviceId`
- `telemetry.sqmId`
</details>

---

## ⭐ Stats

<div align="center">

[![Star History Chart](https://api.star-history.com/svg?repos=mvbureev/go-cursor-help&type=Date)](https://star-history.com/#mvbureev/go-cursor-help&Date)

</div>

## 📄 License

<details>
<summary><b>MIT License</b></summary>

Copyright (c) 2024 mvbureev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
</details>
