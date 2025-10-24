# 使用官方的 Python 3.9 slim 版本作为基础镜像
FROM python:3.9-slim

# 设置工作目录
WORKDIR /app

# [Stage 1: 安装系统依赖和工具]
# 安装 Java (Apktool 需要) 和其他必要工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-11-jre-headless \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# --- [!!! 核心修改区域 !!!] ---
# 复制我们预先下载并压缩好的工具包
COPY tools/android-sdk.tar.gz /app/tools/
COPY tools/apktool.jar /app/tools/

# 运行 tar 命令解压工具包，并清理原始压缩文件
# -C /app/tools/ 表示在解压前先进入 /app/tools 目录，确保解压后的目录结构正确
RUN tar -xzf /app/tools/android-sdk.tar.gz -C /app/tools/ \
    && rm /app/tools/android-sdk.tar.gz
# --- [!!! 修改结束 !!!] ---


# [Stage 2: 安装 Python 依赖]
# 复制需求文件
COPY requirements.txt .

# 安装 Python 库
RUN pip install --no-cache-dir -r requirements.txt

# [Stage 3: 复制应用代码]
# 复制 templates 文件夹
COPY templates/ /app/templates/
# 复制输入模板和密钥
COPY input/ /app/input/
COPY secure/ /app/secure/
# 复制主应用文件
COPY app.py .

# [Stage 4: 配置和运行]
# 暴露 Flask 运行的端口
EXPOSE 5000

# 创建必要的文件夹，防止运行时因缺少目录而出错
RUN mkdir -p /app/output && mkdir -p /app/working

# 容器启动时运行的命令
# 为了方便调试，我们先用 Flask 自带的服务器
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
