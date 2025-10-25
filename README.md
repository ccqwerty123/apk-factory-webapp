# APK Factory Pro 🚀

![APK Factory Pro](https://your-image-url-here.png)  <!-- 建议在这里放一张项目界面的截图 -->

一个简单、强大的在线工具，用于快速修改和重新打包 Android APK 文件。通过友好的网页界面，您可以搜索应用信息、修改包名、版本号，甚至精细化管理 APK 的权限，然后一键生成已签名的新 APK。

**在线体验地址**: [https://glvkgxtchcds.ap-northeast-1.clawcloudrun.com/](https://glvkgxtchcds.ap-northeast-1.clawcloudrun.com/)

该服务部署于 **Claw Cloud** 的免费容器，每月有 10G 流量限制。如果超出，服务可能会在下个月重置前暂时不可用。

---

## ✨ 功能特性

*   **🔍 在线应用信息搜索**: 输入应用名称，即可从腾讯应用宝自动抓取包名、版本、图标等信息，省去手动查找的麻烦。
*   **✏️ 核心信息自定义**: 自由修改应用的显示名称、包名 (Package Name)、版本名 (Version Name) 和版本代码 (Version Code)。
*   **🛡️ 权限精细化管理**: 自动读取模板 APK 的所有权限，您可以像勾选菜单一样，选择在新 APK 中保留哪些权限，轻松移除不必要的敏感权限。
*   **⚙️ 自动防冲突修复**: 在修改包名时，工具会自动修复 `AndroidManifest.xml` 中常见的 Content Provider `authorities` 冲突问题，大大提高了重打包的成功率。
*   **✍️ 一键自动签名**: 无需复杂的命令行操作，生成的所有 APK 都会使用内置的密钥库自动完成 `zipalign` 优化和 `apksigner` v2 签名，可直接安装使用。
*   **📦 基于 Docker, 轻松部署**: 项目已完全容器化，只需一行命令即可在您自己的服务器上运行此工具。

---

## 🛠️ 技术栈

*   **后端**: Flask (Python)
*   **APK 操作**: `apktool`, `apksigner`, `zipalign`
*   **前端**: 原生 HTML, CSS, JavaScript (服务器端渲染)
*   **应用信息源**: 腾讯应用宝 (爬虫解析)

---

## 🚀 快速开始 (本地部署)

想要在本地或您自己的服务器上运行此项目吗？只需安装 Docker，然后执行以下命令：

```bash
docker pull ox85nyhv/apk-factory-webapp:latest

docker run -p 5000:5000 -d --name apk-factory ox85nyhv/apk-factory-webapp:latest
