# [Stage 1: 使用完整版 Python 镜像]
FROM python:3.9-slim

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# [Stage 2: 安装系统依赖并修复 libc++ 链接]
# 这部分完全采纳了您的、经过验证的解决方案
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    build-essential \
    libc++1 \
    libc++abi1 \
    && rm -rf /var/lib/apt/lists/* \
    # 关键修复: 创建 zipalign 需要的 libc++.so 符号链接
    && ln -sf /usr/lib/x86_64-linux-gnu/libc++.so.1 /usr/lib/x86_64-linux-gnu/libc++.so \
    # 更新动态链接器缓存，确保系统能找到新的链接
    && ldconfig

# [Stage 3: 创建工作目录]
WORKDIR /workspace
RUN mkdir -p /workspace/apk_factory

# [Stage 4: 复制并解压工具]
COPY tools/android-sdk.tar.gz /workspace/tools/
COPY tools/apktool.jar /workspace/tools/
RUN tar -xzf /workspace/tools/android-sdk.tar.gz -C /workspace/tools/ \
    && rm /workspace/tools/android-sdk.tar.gz

# [Stage 5: 复制应用代码和资源]
COPY requirements.txt /workspace/apk_factory/
COPY templates/ /workspace/apk_factory/templates/
COPY input/ /workspace/apk_factory/input/
# <<< 最终修正: 将 secure 目录直接复制到 /workspace/secure，以匹配 app.py 中的硬编码路径
COPY secure/ /workspace/secure/
COPY app.py /workspace/apk_factory/

# [Stage 6: 安装 Python 依赖]
WORKDIR /workspace/apk_factory
RUN pip install --no-cache-dir -r requirements.txt

# [Stage 7: 创建运行时目录]
RUN mkdir -p output && mkdir -p working

# [Stage 8: 暴露端口并运行]
EXPOSE 5000
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
