# PythonFileToYoutube

Turn any file or folder into one or more MP4 videos (and back again) using the `file_to_video_torch.py` script. 
The script is optimized for YouTube storage (robustness against compression).

## Features

- **End-to-end pipeline**: Archive → Error-Correction (PAR2) → Frame Encoding → Video Stream.
- **GPU-accelerated**: Uses PyTorch (CUDA) for high-performance frame generation.
- **NVENC Support**: Hardware video encoding for massive speed gains.
- **Robust Redundancy**: Splits files into 1GB chunks and generates recovery records.
- **Cross-platform**: Works on Windows and Linux (Docker recommended).

---

## 🐳 Option 1: Docker (Recommended)

Docker handles all dependencies (Python, FFmpeg, 7-Zip, PAR2) automatically. You only need GPU drivers.

### 1. Host Requirements
*   **NVIDIA GPU Drivers**: Installed on your host machine.
*   **Docker**:
    *   **Windows**: Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
        *   *Settings > General*: Ensure "Use the WSL 2 based engine" is checked.
    *   **Linux**: Install Docker Engine + [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

### 2. Setup
1.  Clone this repo.
2.  Run:
    ```bash
    docker compose up -d --build
    ```

### 3. Running Commands
Use `docker compose exec f2yt <command>` to run the script inside the container.
*   **Example:** `docker compose exec f2yt python file_to_video_torch.py -mode encode ...`

---

## 🛠 Option 2: Manual Installation (Windows)

If you are not using Docker, you must install these tools manually.

### 1. Install Python & Libraries
1.  Download and install **Python 3.11+** from [python.org](https://www.python.org/downloads/).
    *   *Check "Add Python to PATH" during installation.*
2.  Open Command Prompt (Admin) and install libraries:
    ```cmd
    # For CUDA 11.8 (Check pytorch.org for your specific version)
    pip install torch --index-url https://download.pytorch.org/whl/cu118
    pip install numpy Pillow
    ```

### 2. Install External Tools
You need `ffmpeg`, `7z`, and `par2` accessible. The easiest way is to download the executables and place them **inside this project folder** alongside the python script.

*   **FFmpeg**: Download `ffmpeg-git-full.7z` from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/). Extract `ffmpeg.exe`.
*   **7-Zip**: Download the **7-Zip Extra** (command line version) from [7-zip.org](https://www.7-zip.org/download.html). Extract `7za.exe` and rename it to `7z.exe`.
*   **PAR2**: Download `par2cmdline` for Windows from [Parchive GitHub](https://github.com/Parchive/par2cmdline/releases). Extract `par2.exe`.

### 3. Verify
Run the provided checker script:
```cmd
check_deps_windows.bat
```

---

## 📖 Usage Guide

The general syntax is:
```bash
python file_to_video_torch.py -mode [encode|decode] -input "[path]"
```

### Arguments

| Argument | Description |
| :--- | :--- |
| `-mode` | **Required.** Set to `encode` to turn files into video, or `decode` to turn video back into files. |
| `-input` | **Required.** The path to the file, folder, or video you want to process. See details below. |
| `-output` | *Optional.* Specify a custom destination folder. |
| `-p` | *Optional.* Encrypt the internal 7-Zip archive with a password. |

### How to use `-input`

#### Encoding (Files → Video)
*   **Single File:** You can point to a single file (e.g., `archive.zip`, `movie.mkv`).
*   **Folder:** You can point to a directory (e.g., `C:\MyBackup\`). The script will compress the *entire* folder contents into the video.

#### Decoding (Video → Files)
*   **Folder (Recommended):** Point the input to the folder containing all the video parts (e.g., `MyFile_F2YT_Output`). The script automatically scans for `.mp4` files in that folder.
*   **Multiple Files:** You can provide a comma-separated list of video paths.
    *   *Important:* If the original file was large and split into segments (`part001.mp4`, `part002.mp4`), **order matters**. The first file in the list (or the folder scan) **must** be `part001` (the one containing the barcode and metadata headers).

---

## ⚙️ Configuration (`f2yt_config.json`)

On the first run, the script generates `f2yt_config.json`. You can edit this to tune performance or change paths.

### Tools & Output
| Key | Default | Description |
| :--- | :--- | :--- |
| `FFMPEG_PATH` | `ffmpeg` | Path to FFmpeg executable. Use `.\\ffmpeg.exe` if in local folder. |
| `SEVENZIP_PATH` | `7z` | Path to 7-Zip executable. |
| `PAR2_PATH` | `par2` | Path to PAR2 executable. |
| `VIDEO_WIDTH` | `720` | Output video resolution width. |
| `VIDEO_HEIGHT` | `720` | Output video resolution height. |
| `VIDEO_FPS` | `60` | Framerate. Higher = faster data transfer but larger files. |

### Encoding Parameters
| Key | Default | Description |
| :--- | :--- | :--- |
| `DATA_K_SIDE` | `180` | Grid size (180x180 pixels). Controls data density per frame. |
| `NUM_COLORS_DATA` | `2` | Colors per pixel (2 = Black/White). Increasing this is risky for YouTube. |
| `DATA_HAMMING_N` | `127` | Hamming Block Size (Error correction density). |
| `DATA_HAMMING_K` | `120` | Hamming Data Size (Payload per block). |
| `ENABLE_NVENC` | `true` | Use NVIDIA GPU hardware encoding. Automatically disables if no GPU found. |
| `X264_CRF` | `33` | Video quality factor (Lower = Higher Quality). 33 balances size/safety. |
| `KEYINT_MAX` | `64` | Max Keyframe Interval. Controls seeking speed and compression efficiency. |
| `PAR2_REDUNDANCY_PERCENT` | `1` | Percentage of extra recovery data (external to the video stream). |
| `MAX_VIDEO_SEGMENT_HOURS` | `11` | Splits output MP4s if they exceed this duration (YouTube limit). |

### Performance Tuning
| Key | Default | Description |
| :--- | :--- | :--- |
| `CPU_WORKER_THREADS` | `2` | Number of threads converting bytes to bits. |
| `CPU_PRODUCER_CHUNK_MB` | `128` | How many MBs of the source file to read into RAM at once. |
| `PIPELINE_QUEUE_DEPTH` | `64` | How many prepared batches to buffer in RAM before the GPU takes them. |
| `GPU_PROCESSOR_BATCH_SIZE` | `512` | How many frames the GPU renders in a single CUDA call. |
| `GPU_OVERLAP_STREAMS` | `8` | Number of concurrent CUDA streams for parallel processing. |

---

## Troubleshooting


### "Command not found"
If you put `ffmpeg.exe` etc. in the project folder but the script fails, verify `f2yt_config.json`:
```json
{
    "FFMPEG_PATH": ".\\ffmpeg.exe",
    "SEVENZIP_PATH": ".\\7z.exe",
    "PAR2_PATH": ".\\par2.exe"
}
```

## License
MIT