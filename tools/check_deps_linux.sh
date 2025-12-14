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
  local bin_name="$1"
  local desc="$2"
  
  # 1. Check Global PATH
  if command -v "$bin_name" >/dev/null 2>&1; then
    printf '[\033[32mOK\033[0m] Found %s in PATH\n' "$bin_name"
    return 0
  fi

  # 2. Check Current Directory
  if [[ -x "./$bin_name" ]]; then
    printf '[\033[32mOK\033[0m] Found %s in current directory\n' "$bin_name"
    return 0
  fi

  return 1
}

missing=()
print_header

# --- 1. Check Python ---
PY_BIN="python3"
if ! command -v "$PY_BIN" >/dev/null 2>&1; then
  add_missing "Python 3" "Install python3 (version 3.11+ recommended)"
else
  VER=$($PY_BIN --version 2>&1)
  printf '[\033[32mOK\033[0m] %s detected\n' "$VER"
fi

# --- 2. Check Torch (Robust Method) ---
if command -v "$PY_BIN" >/dev/null 2>&1; then
  printf "[..] Checking PyTorch and CUDA... "
  
  # Create a temp script to avoid stdout pollution from shell profiles
  TORCH_SCRIPT=$(mktemp)
  cat <<EOF > "$TORCH_SCRIPT"
import importlib.util
state = {'installed': False, 'cuda': False, 'version': 'unknown'}
if importlib.util.find_spec('torch') is not None:
    import torch
    state['installed'] = True
    state['version'] = getattr(torch, '__version__', 'unknown')
    try:
        state['cuda'] = bool(torch.cuda.is_available())
    except:
        state['cuda'] = False
print(f"{state['installed']}|{state['cuda']}|{state['version']}")
EOF

  # Run and capture
  TORCH_INFO=$($PY_BIN "$TORCH_SCRIPT" 2>/dev/null)
  rm "$TORCH_SCRIPT"

  if [ -z "$TORCH_INFO" ]; then
    printf '\033[31mError running Python check\033[0m\n'
    add_missing "PyTorch" "Could not run detection script."
  else
    IFS='|' read -r INSTALLED CUDA_OK TVER <<< "$TORCH_INFO"
    
    if [ "$INSTALLED" == "True" ]; then
        if [ "$CUDA_OK" == "True" ]; then
            printf '\033[32m%s - CUDA Active\033[0m\n' "$TVER"
        else
            printf '\033[33m%s - CPU Only\033[0m\n' "$TVER"
            echo "    (Warning: Encoding will be slow. Install NVIDIA drivers/toolkit for speed)"
        fi
    else
        printf '\033[31mNot Found\033[0m\n'
        add_missing "PyTorch" "Run: pip install torch numpy Pillow"
    fi
  fi
fi

echo ""

# --- 3. Check Binaries ---

# FFmpeg
if ! check_bin "ffmpeg" "FFmpeg"; then
  add_missing "FFmpeg" "Install via 'sudo apt install ffmpeg' or place 'ffmpeg' binary here."
fi

# 7-Zip (Complex check for variants)
SEVEN_ZIP_FOUND=0
for cand in "7z" "7za" "7zz"; do
  if check_bin "$cand" "7-Zip"; then
    SEVEN_ZIP_FOUND=1
    if [ "$cand" != "7z" ]; then
        echo "    (Note: Update 'SEVENZIP_PATH' in config.json to '$cand')"
    fi
    break
  fi
done

if [ $SEVEN_ZIP_FOUND -eq 0 ]; then
  add_missing "7-Zip" "Install 'p7zip-full' or place '7z' binary here."
fi

# PAR2
if ! check_bin "par2" "PAR2"; then
  add_missing "PAR2" "Install 'par2' package or place 'par2' binary here."
fi

# NVIDIA-SMI (Optional but good to check)
if command -v "nvidia-smi" >/dev/null 2>&1; then
    : # Found
else
    echo "    (Note: 'nvidia-smi' not found. GPU encoding requires NVIDIA Drivers)"
fi

echo ""
if [ ${#missing[@]} -eq 0 ]; then
  printf '\033[1;32m[SUCCESS] All dependencies satisfied.\033[0m\n'
  exit 0
else
  printf '\033[1;31m[ERROR] Missing Dependencies:\033[0m\n'
  for item in "${missing[@]}"; do
    echo "$item"
  done
  exit 1
fi