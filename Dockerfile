# Use an official PyTorch image with CUDA support
FROM pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install basic tools (removed ffmpeg from apt)
RUN apt-get update && apt-get install -y \
    p7zip-full \
    par2 \
    git \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Python dependencies
RUN pip install --no-cache-dir \
    pillow \
    numpy

# 3. Manually install a Static FFmpeg build with NVENC support
# We use the BtbN build which includes hardware acceleration enabled
RUN wget https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz -O /tmp/ffmpeg.tar.xz \
    && tar -xf /tmp/ffmpeg.tar.xz -C /tmp \
    && mv /tmp/ffmpeg-master-latest-linux64-gpl/bin/ffmpeg /usr/local/bin/ffmpeg \
    && mv /tmp/ffmpeg-master-latest-linux64-gpl/bin/ffprobe /usr/local/bin/ffprobe \
    && chmod +x /usr/local/bin/ffmpeg \
    && chmod +x /usr/local/bin/ffprobe \
    && rm -rf /tmp/ffmpeg*

# Set the working directory
WORKDIR /app

# Default command
CMD ["/bin/bash"]