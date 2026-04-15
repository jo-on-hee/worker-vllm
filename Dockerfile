FROM nvidia/cuda:12.9.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y python3-pip python3-dev git && \
    rm -rf /var/lib/apt/lists/*

RUN ldconfig /usr/local/cuda-12.9/compat/

# Install vLLM nightly + transformers 5.x (required for Qwen3.5)
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install -U vllm --pre \
        --extra-index-url https://wheels.vllm.ai/nightly \
        --extra-index-url https://download.pytorch.org/whl/cu129 && \
    python3 -m pip install 'transformers>=5.2.0' && \
    python3 -m pip install 'huggingface_hub>=0.34.0,<1.0'

# Install additional dependencies
COPY builder/requirements.txt /requirements.txt
RUN python3 -m pip install --upgrade -r /requirements.txt

# Environment setup
ARG MODEL_NAME=""
ARG BASE_PATH="/runpod-volume"

ENV MODEL_NAME=$MODEL_NAME \
    BASE_PATH=$BASE_PATH \
    HF_DATASETS_CACHE="${BASE_PATH}/huggingface-cache/datasets" \
    HUGGINGFACE_HUB_CACHE="${BASE_PATH}/huggingface-cache/hub" \
    HF_HOME="${BASE_PATH}/huggingface-cache/hub" \
    HF_HUB_ENABLE_HF_TRANSFER=0 \
    RAY_METRICS_EXPORT_ENABLED=0 \
    RAY_DISABLE_USAGE_STATS=1 \
    TOKENIZERS_PARALLELISM=false \
    RAYON_NUM_THREADS=4 \
    PYTHONPATH="/:/vllm-workspace"

COPY src /src

RUN --mount=type=secret,id=HF_TOKEN,required=false \
    if [ -f /run/secrets/HF_TOKEN ]; then \
        export HF_TOKEN=$(cat /run/secrets/HF_TOKEN); \
    fi && \
    if [ -n "$MODEL_NAME" ]; then \
        python3 /src/download_model.py; \
    fi

CMD ["python3", "/src/handler.py"]
