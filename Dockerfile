# [Stage 1: 选择一个高效的 Python 基础镜像]
FROM python:3.12

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# [Stage 2: 安装所有必要的系统依赖并进行诊断]
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    build-essential \
    # <<< 关键修复: 添加 zipalign 所需的 C++ 运行时库
    libc++1 \
    && rm -rf /var/lib/apt/lists/* \
    # <<< 诊断命令 1: 验证 libc++.so 文件是否已安装到系统中
    && echo "--- 正在查找 libc++.so ---" \
    && find / -name "libc++.so" \
    && echo "--- 查找结束 ---"

# [Stage 3: 创建并设置与 Python 代码匹配的工作目录]
WORKDIR /workspace
RUN mkdir -p /workspace/apk_factory

# [Stage 4: 复制工具到正确的路径]
COPY tools/android-sdk.tar.gz /workspace/tools/
COPY tools/apktool.jar /workspace/tools/
RUN tar -xzf /workspace/tools/android-sdk.tar.gz -C /workspace/tools/ \
    && rm /workspace/tools/android-sdk.tar.gz

# <<< 诊断命令 2: 在复制完所有工具后，使用 ldd 命令检查 zipalign 的依赖链接情况
# ldd 是 Linux下查看程序动态链接库依赖的黄金标准
RUN echo "--- 正在使用 ldd 检查 zipalign 依赖 ---" \
    && ldd /workspace/tools/android-sdk/build-tools/34.0.0/zipalign \
    && echo "--- ldd 检查结束 ---"

# [Stage 5: 复制应用代码和资源]
COPY requirements.txt /workspace/apk_factory/
COPY templates/ /workspace/apk_factory/templates/
COPY input/ /workspace/apk_factory/input/
COPY secure/ /workspace/apk_factory/secure/
COPY app.py /workspace/apk_factory/

# [Stage 6: 在新的位置安装 Python 依赖]
WORKDIR /workspace/apk_factory
RUN pip install --no-cache-dir -r requirements.txt

# [Stage 7: 创建应用运行时所需的目录]
RUN mkdir -p output && mkdir -p working

# [Stage 8: 暴露端口并运行应用]
EXPOSE 5000
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
