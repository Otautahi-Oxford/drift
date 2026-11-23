#!/bin/bash
drift_checkout=$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")/..")
apptainer run -B "$drift_checkout:/data/drift" --writable-tmpfs --no-mount home --home /data/home/leo --nv --cleanenv --cwd /data/drift drift.sif
