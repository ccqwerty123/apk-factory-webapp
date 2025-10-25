# [Stage 0: 选择基础镜像]
# 使用官方的 Ubuntu 22.04 LTS 作为基础镜像，以确保与测试环境一致
FROM ubuntu:22.04

# 设置环境变量，防止 apt-get 在安装时弹出交互式对话框
ENV DEBIAN_FRONTEND=noninteractive

# 设置工作目录
WORKDIR /app

# [Stage 1: 安装所有系统依赖]
# 在一个步骤中，安装所有需要的系统软件包
# 这包括：Python 3.9, Pip, Java, 以及编译 dbus-python 所需的所有工具和库
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python 环境
    python3.9 \
    python3-pip \
    python3.9-venv \
    # Java 环境 (Apktool 需要)
    default-jre-headless \
    # 之前发现的所有编译依赖
    build-essential \
    libdbus-1-dev \
    libglib2.0-dev \
    dbus \
    # 应用需要的其他工具
    wget \
    unzip \
    # 清理 apt 缓存，减小镜像体积
    && rm -rf /var/lib/apt/lists/*

# [Stage 2: 复制和解压工具包]
# 这一部分保持不变
COPY tools/android-sdk.tar.gz /app/tools/
COPY tools/apktool.jar /app/tools/
RUN tar -xzf /app/tools/android-sdk.tar.gz -C /app/tools/ \
    && rm /app/tools/android-sdk.tar.gz

# [Stage 3: 安装 Python 依赖]
# 复制需求文件
COPY requirements.txt .
# 使用 pip 安装 Python 库 (现在系统中有完整的编译环境，应该会很顺利)
RUN pip install --no-cache-dir -r requirements.txt

# [Stage 4: 复制应用代码]
# 这一部分保持不变
COPY templates/ /app/templates/
COPY input/ /app/input/
COPY secure/ /app/secure/
COPY app.py .

# [Stage 5: 配置和运行]
# 这一部分保持不变
EXPOSE 5000
RUN mkdir -p /app/output && mkdir -p /app/working
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]```
