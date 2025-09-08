# 🐘 PHP & Extensions Pack Build Repository

[PHP](https://img.shields.io/badge/php-%23777BB4.svg?style=for-the-badge&logo=php&logoColor=white)  
[Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)  
[GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)  
[OSPanel](https://img.shields.io/badge/OSPanel-Compatible-orange?style=for-the-badge)

**Automated PHP and extensions build for OSPanel**

---

## ✨ Features

> 🚀 **Optimized builds** for Windows 10+ with SSE4.2 support  
> 🔧 **Automated build** via GitHub Actions  
> 📦 **Full set of extensions** for web development  
> 🎯 **Specially for OSPanel** – ready-to-use builds

## ⚠️ Important Compatibility Notice

| ✅ Compatible | ❌ Not compatible |
|---------------|-------------------|
| Windows 10+   | Windows 7/8.1 |
| CPU with SSE4.2+ | Older processors |
| OSPanel       | Official PHP builds |

**🔍 Compatibility details:**
- All builds are generated for Windows 10 and newer
- CPU optimizations use SSE4.2 instructions
- Binaries are not compatible with official php.net builds

## 📋 System Requirements

| 💻 Minimum Requirements | 🚀 Recommended Requirements |
|--------------------------|------------------------------|
| **OS:** Windows 10 (version 1903+) | **OS:** Windows 11 |
| **Architecture:** x86_64 (64-bit) | **CPU:** Intel Core i5 / AMD Ryzen 5 |
| **CPU:** Intel Core i3 / AMD Ryzen 3 | **RAM:** 8GB+ |
| **Instructions:** SSE4.2 support | **SSD:** For optimal performance |

## 🧪 Testing

| Test type | Command | Description |
|-----------|---------|-------------|
| **Syntax** | `php -l script.php` | Syntax check |
| **Modules** | `php -m` | List of loaded modules |
| **Configuration** | `php --ini` | Configuration files |
| **Info** | `php -i` | Full PHP information |

## 🔍 Diagnostics

### 🚨 Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| `"VCRUNTIME140.dll not found"` | Missing Visual C++ Redistributable | Install [VC++ Redist](https://aka.ms/vs/17/release/vc_redist.x64.exe) |
| `"Illegal instruction"` | CPU does not support SSE4.2 | Use a compatible build |
| `"Extension not loaded"` | Missing extension DLL | Ensure the file exists in `ext/` |

## 📊 Comparison with Official Builds

| Feature | Our Builds | Official |
|---------|------------|----------|
| ⚡ **Optimizations** | SSE4.2 | Generic x86_64 |
| 📦 **Extensions** | Preinstalled | Basic set |
| 🔧 **OSPanel** | ✅ Ready to use | ⚙️ Requires setup |
| 🚀 **Performance** | +15% | Baseline |
| 📥 **Size** | Larger (~50MB) | Smaller (~30MB) |

## 🙏 Acknowledgements

### 🏆 Team & Community

| Project | Contribution | Link |
|---------|--------------|------|
| **PHP Project** | Core programming language | [php.net](https://www.php.net/) |
| **OSPanel** | Development environment | [ospanel.io](https://ospanel.io/) |
| **PECL** | PHP extensions | [pecl.php.net](https://pecl.php.net/) |
| **Microsoft** | Build Tools and Runtime | [visualstudio.microsoft.com](https://visualstudio.microsoft.com/) |

---

**Made with ❤️ for the PHP developers and OSPanel users community**
