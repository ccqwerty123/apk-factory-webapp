# [Stage 1: 选择一个高效的 Python 基础镜像]
FROM python:3.12-slim

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# [Stage 2: 安装必要的系统依赖]
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# [Stage 3: 创建并设置与 Python 代码匹配的工作目录]
# <<< 修改点 1: 创建 Python 代码中期望的完整路径
WORKDIR /workspace
RUN mkdir -p /workspace/apk_factory

# [Stage 4: 复制工具到正确的路径]
# <<< 修改点 2: 将工具复制到 /workspace/tools 而不是 /app/tools
COPY tools/android-sdk.tar.gz /workspace/tools/
COPY tools/apktool.jar /workspace/tools/
RUN tar -xzf /workspace/tools/android-sdk.tar.gz -C /workspace/tools/ \
    && rm /workspace/tools/android-sdk.tar.gz

# [Stage 5: 复制应用代码和资源到正确的路径]
# <<< 修改点 3: 将所有应用文件复制到 /workspace/apk_factory
COPY requirements.txt /workspace/apk_factory/
COPY templates/ /workspace/apk_factory/templates/
COPY input/ /workspace/apk_factory/input/
COPY secure/ /workspace/apk_factory/secure/
COPY app.py /workspace/apk_factory/

# [Stage 6: 在新的位置安装 Python 依赖]
# <<< 修改点 4: 进入 apk_factory 目录再安装依赖
WORKDIR /workspace/apk_factory
RUN pip install --no-cache-dir -r requirements.txt

# [Stage 7: 创建应用运行时所需的目录 (路径现在是正确的)]
RUN mkdir -p output && mkdir -p working

# [Stage 8: 暴露端口并运行应用]
EXPOSE 5000
# <<< 修改点 5: CMD 现在直接运行 app.py 即可，因为我们已在正确的工作目录中
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
