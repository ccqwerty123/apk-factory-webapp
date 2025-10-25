# [Stage 1: 使用完整版 Python 镜像]
FROM python:3.12

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# [Stage 2: 安装系统依赖并修复 libc++ 链接]
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    build-essential \
    libc++1 \
    libc++abi1 \
    && rm -rf /var/lib/apt/lists/* \
    # <<< 关键修复: 创建 libc++.so 符号链接
    && ln -sf /usr/lib/x86_64-linux-gnu/libc++.so.1 /usr/lib/x86_64-linux-gnu/libc++.so \
    # 更新动态链接器缓存
    && ldconfig \
    # 诊断: 确认链接创建成功
    && echo "--- 检查 libc++ 文件 ---" \
    && ls -la /usr/lib/x86_64-linux-gnu/libc++* \
    && echo "--- ldconfig 缓存验证 ---" \
    && ldconfig -p | grep libc++

# [Stage 3: 创建工作目录]
WORKDIR /workspace
RUN mkdir -p /workspace/apk_factory

# [Stage 4: 复制并解压工具]
COPY tools/android-sdk.tar.gz /workspace/tools/
COPY tools/apktool.jar /workspace/tools/
RUN tar -xzf /workspace/tools/android-sdk.tar.gz -C /workspace/tools/ \
    && rm /workspace/tools/android-sdk.tar.gz

# [Stage 5: 验证 zipalign 依赖]
RUN echo "--- 使用 ldd 检查 zipalign 依赖 ---" \
    && ldd /workspace/tools/android-sdk/build-tools/34.0.0/zipalign \
    && echo "--- ldd 检查结束 ---" \
    # 额外测试: 直接运行 zipalign 查看版本
    && echo "--- 测试运行 zipalign ---" \
    && /workspace/tools/android-sdk/build-tools/34.0.0/zipalign -h 2>&1 | head -5 || true

# [Stage 6: 复制应用代码和资源]
COPY requirements.txt /workspace/apk_factory/
COPY templates/ /workspace/apk_factory/templates/
COPY input/ /workspace/apk_factory/input/
COPY secure/ /workspace/apk_factory/secure/
COPY app.py /workspace/apk_factory/

# [Stage 7: 安装 Python 依赖]
WORKDIR /workspace/apk_factory
RUN pip install --no-cache-dir -r requirements.txt

# [Stage 8: 创建运行时目录]
RUN mkdir -p output && mkdir -p working

# [Stage 9: 暴露端口并运行]
EXPOSE 5000
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
