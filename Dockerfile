# [Stage 0: 选择基础镜像]
# 使用最新的 Ubuntu 24.04 LTS 作为基础镜像
FROM ubuntu:24.04

# 设置环境变量，防止 apt-get 在安装时弹出交互式对话框
ENV DEBIAN_FRONTEND=noninteractive

# 设置工作目录
WORKDIR /app

# [Stage 1: 安装所有系统依赖]
# 在一个步骤中，安装所有需要的系统软件包
# !! 最终修改：使用 apt 安装 python3-apt !!
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python 环境
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    # 核心修改：安装 python-apt 的系统包
    python3-apt \
    # Java 环境
    default-jre-headless \
    # C/C++ 编译工具链
    build-essential \
    # C 扩展库的开发依赖
    libdbus-1-dev \
    libglib2.0-dev \
    dbus \
    libcairo2-dev \
    libgirepository1.0-dev \
    # 应用需要的其他工具
    wget \
    unzip \
    # 清理 apt 缓存
    && rm -rf /var/lib/apt/lists/*

# [Stage 2: 复制和解压工具包]
COPY tools/android-sdk.tar.gz /app/tools/
COPY tools/apktool.jar /app/tools/
RUN tar -xzf /app/tools/android-sdk.tar.gz -C /app/tools/ \
    && rm /app/tools/android-sdk.tar.gz

# [Stage 3: 安装 Python 依赖]
# 复制需求文件
COPY requirements.txt .
# 安装 Python 依赖 (requirements.txt 中必须移除 python-apt)
RUN python3 -m pip install --no-cache-dir --break-system-packages -r requirements.txt

# [Stage 4: 复制应用代码]
COPY templates/ /app/templates/
COPY input/ /app/input/
COPY secure/ /app/secure/
COPY app.py .

# [Stage 5: 配置和运行]
EXPOSE 5000
RUN mkdir -p /app/output && mkdir -p /app/working
# 启动应用
CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0", "--port=5000"]
