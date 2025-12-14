#!/usr/bin/env bash
set -u

print_header() {
  printf '\033[1;36m%s\033[0m\n' "PythonFileToYoutube Dependency Check (Linux)"
  printf '%s\n' "------------------------------------------------"
}

add_missing() {
  missing+=("- $1: $2")
}

check_bin() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '[\033[32mOK\033[0m] %s found\n' "$1"
    return 0
  else
    return 1
  fi
}

missing=()
print_header

# 1. Check Python
PY_BIN="python3"
if ! command -v "$PY_BIN" >/dev/null 2>&1; then
  add_missing "Python 3" "Install python3 (version 3.11+ recommended)"
else
  VER=$($PY_BIN --version 2>&1)
  printf '[\033[32mOK\033[0m] %s\n' "$VER"
fi

# 2. Check Torch
if command -v "$PY_BIN" >/dev/null 2>&1; then
  printf "[..] Checking PyTorch... "
  TORCH_INFO=$($PY_BIN -c 'import torch; print(f"{torch.__version__}|{torch.cuda.is_available()}")' 2>/dev/null)
  
  if [ -z "$TORCH_INFO" ]; then
    printf '\033[31mNot Found\033[0m\n'
    add_missing "PyTorch" "Run: pip install torch numpy Pillow"
  else
    IFS='|' read -r TVER CUDA_OK <<< "$TORCH_INFO"
    if [ "$CUDA_OK" == "True" ]; then
      printf '\033[32m%s (CUDA Active)\033[0m\n' "$TVER"
    else
      printf '\033[33m%s (CPU Only)\033[0m\n' "$TVER"
      echo "    (Warning: Encoding will be slow without CUDA)"
    fi
  fi
fi

# 3. Check Binaries
if check_bin "ffmpeg"; then
  : # Do nothing, already printed
else
  add_missing "FFmpeg" "Install via: sudo apt install ffmpeg"
fi

# Check for either 7z or 7za
if command -v "7z" >/dev/null 2>&1; then
  printf '[\033[32mOK\033[0m] 7z found\n'
elif command -v "7za" >/dev/null 2>&1; then
  printf '[\033[32mOK\033[0m] 7za found (Update config.json to use '7za')\n'
else
  add_missing "7-Zip" "Install via: sudo apt install p7zip-full"
fi

if check_bin "par2"; then
  :
else
  add_missing "PAR2" "Install via: sudo apt install par2"
fi

if check_bin "nvidia-smi"; then
  :
else
  echo "    (Note: nvidia-smi not found. Ensure NVIDIA drivers are installed for GPU support)"
fi

echo ""
if [ ${#missing[@]} -eq 0 ]; then
  printf '\033[1;32mAll systems go!\033[0m\n'
  exit 0
else
  printf '\033[1;31mMissing Dependencies:\033[0m\n'
  for item in "${missing[@]}"; do
    echo "$item"
  done
  exit 1
fi 