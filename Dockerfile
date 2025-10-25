# [Stage 1: 选择一个高效的 Python 基础镜像]
# 使用官方的 Python 3.12 slim 版本，它基于 Debian，体积小且预装了 Python 环境。
FROM python:3.12-slim

# 设置环境变量，有助于在容器中运行
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# [Stage 2: 安装必要的系统依赖]
# 在这里，我们安装运行 APK 工具链所必需的包。
RUN apt-get update && apt-get install -y --no-install-recommends \
    # **必需**: 为 apktool.jar 和 apksigner 提供 Java 运行环境
    default-jre-headless \
    # **强烈推荐**: 用于编译 lxml 等可能需要 C 扩展的 Python 包
    build-essential \
    # 清理 apt 缓存以减小镜像体积
    && rm -rf /var/lib/apt/lists/*

# [Stage 3: 设置工作目录并复制和解压工具]
WORKDIR /app
COPY tools/android-sdk.tar.gz /app/tools/
COPY tools/apktool.jar /app/tools/
# 解压 Android SDK 并删除压缩包
RUN tar -xzf /app/tools/android-sdk.tar.gz -C /app/tools/ \
    && rm /app/tools/android-sdk.tar.gz

# [Stage 4: 安装精简后的 Python 依赖]
# 复制新的、干净的 requirements.txt
COPY requirements.txt .
# --no-cache-dir 减少镜像体积。这里会安装 Flask, requests, beautifulsoup4, lxml
RUN pip install --no-cache-dir -r requirements.txt

# [Stage 5: 复制应用代码和资源]
COPY templates/ /app/templates/
COPY input/ /app/input/
COPY secure/ /app/secure/
COPY app.py .

# [Stage 6: 创建应用运行时所需的目录]
RUN mkdir -p /app/output && mkdir -p /app/working

# [Stage 7: 暴露端口并运行应用]
EXPOSE 5000

# 使用 Flask 内置服务器运行。对于生产部署，可以考虑换成 Gunicorn。
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]```
