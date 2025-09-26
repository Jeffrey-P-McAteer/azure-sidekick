#!/usr/bin/env bash

if [[ -z "$NFS_MOUNT_PT" ]] ; then
  NFS_MOUNT_PT="/mnt/nfs"
fi

if ! [[ -e "$NFS_MOUNT_PT" ]] ; then
  echo "Refusing to run w/o NFS_MOUNT_PT=$NFS_MOUNT_PT drive"
  exit 1
fi

AI_FOLDER="$NFS_MOUNT_PT/invoke-ai"
if ! [[ -e "$AI_FOLDER" ]] ; then
  sudo mkdir -p "$AI_FOLDER"
fi


# Mounts ~/invokeai/models for models and ~/invokeai/outputs for generated images.

# Host folders (change if you like)
HOST_MODELS="$AI_FOLDER/models"
HOST_OUTPUTS="$AI_FOLDER/outputs"
HOST_CONFIG="$HOST_BASE/config"

sudo mkdir -p "$HOST_MODELS"
sudo mkdir -p "$HOST_OUTPUTS"
sudo mkdir -p "$HOST_CONFIG"

# Docker image (official InvokeAI or community variant)
#IMAGE="ghcr.io/invoke-ai/invokeai:latest"
IMAGE="ghcr.io/invoke-ai/invokeai:main-cuda"

# Container ephemeral run
exec sudo docker run --rm -it \
  --gpus all \
  -p 127.0.0.1:9100:9090 \
  -v "$HOST_MODELS:/root/.invokeai/models" \
  -v "$HOST_OUTPUTS:/root/.invokeai/outputs" \
  -v "$HOST_CONFIG:/root/.invokeai/config" \
  "$IMAGE" \
    /opt/venv/bin/invokeai-web --root /root/.invokeai
    # /opt/venv/bin/invokeai-web --web \
    # --port 9100 \
    # --model_dir /root/.invokeai/models \
    # --output_dir /root/.invokeai/outputs \
    # --config_dir /root/.invokeai/config

