# AI with HPC — Scaling Deep Learning Workflows in MATLAB on an HPC Cluster

A hands-on workshop demonstrating how to **scale up deep learning workflows in MATLAB on an HPC cluster**. The workshop uses a brain-MRI age-classification example (ResNet-18 transfer learning on the OpenNEURO `ds000228` dataset) as the vehicle to walk from a single-machine training run to GPU-accelerated training and parallel multi-model sweeps that map naturally onto cluster execution.

## Workshop Goals

- Show the progression from a desktop deep learning workflow to a parallel/HPC one in MATLAB.
- Demonstrate **GPU-accelerated training** (`ExecutionEnvironment="auto"`, GPU selection via Parallel Computing Toolbox).
- Demonstrate **parallel hyperparameter sweeps** using `parfor` over a parallel pool — directly extendable to a cluster pool/cluster profile.
- Provide a realistic end-to-end pipeline (data prep → training → evaluation → deployment) that learners can re-target to a cluster (`parcluster`, `batch`, cluster profiles) and to multi-GPU workers.

## Example Pipeline

The brain-MRI example is intentionally small enough to run on a laptop, but every stage is structured so that it can be scaled out:

1. **Data prep** — read 3D anatomical MRI brain volumes (NIfTI), extract 2D axial midslices, normalize intensities, optionally apply skull-stripping and offline augmentation.
2. **Single-model transfer learning** — fine-tune a pretrained ResNet-18 to classify participants into three age groups (Ages 3–5, Ages 7–12, Adults 18+).
3. **Evaluation** — accuracy, confusion matrix, and occlusion-sensitivity visualization of learned features.
4. **Parallel multi-model training** — sweep training hyperparameters (`valFrequency` / `miniBatchSize`) with `parfor` so each worker trains an independent network. This step is the bridge to cluster scale-out.

The example also shows that even with a small dataset (155 subjects), transfer learning on a lightweight pretrained CNN can recover age-related structural features that are not obvious to human observers.

## Repository Layout

| Path | Description |
| --- | --- |
| [E00_DataPrep.m](E00_DataPrep.m) | **Stage 0** — Live Script that reads 3D NIfTI volumes, inspects participant demographics, and prepares the 2D image dataset. Single-machine, CPU. |
| [E01_TransferLearning.m](E01_TransferLearning.m) | **Stage 1** — Live Script that performs transfer learning on ResNet-18 with `ExecutionEnvironment="auto"` (uses GPU if available), evaluates accuracy, and visualizes learned features. Single GPU. |
| [E02_multiModel.m](E02_multiModel.m) | **Stage 2** — Live Script that trains multiple networks **in parallel via `parfor`**, sweeping `valFrequency`/`miniBatchSize`. Each iteration runs on its own worker; swap the local pool for a cluster pool to scale out. |
| [prepare2DImageDataset.m](prepare2DImageDataset.m) | Helper function — extracts axial midslices, normalizes intensities, optionally applies skull-stripping and 180° rotation augmentation, and writes PNGs grouped by age class. |
| [predictfcn.m](predictfcn.m) | Codegen-compatible entry-point function that loads a saved network and runs inference on a single image. |
| [ds000228-1.1.0-subset/](ds000228-1.1.0-subset/) | BIDS-formatted subset of the OpenNEURO `ds000228` dataset — 155 preprocessed anatomical scans, skull-stripping masks, and participant metadata. |
| [2DImageSet_28May2026_064146/](2DImageSet_28May2026_064146/) | Generated 2D PNG image set produced by `prepare2DImageDataset`, organized into `Adults/`, `Ages3-5/`, `Ages7-12/` subfolders. |
| [image-classifier-app/](image-classifier-app/) | MATLAB App Designer–based image classifier app (see its own [README](image-classifier-app/README.md)). |
| [LICENSE.md](LICENSE.md) | MathWorks BSD-style license. |

## Dataset

The MRI data is a subset of the publicly available [OpenNEURO ds000228](https://openneuro.org/datasets/ds000228/versions/1.1.0) dataset:

> Richardson, H., Lisandrelli, G., Riobueno-Naylor, A., & Saxe, R. (2018). *Development of the social brain from age three to twelve years.* Nature Communications, 9(1), 1027.

The included files under [ds000228-1.1.0-subset/derivatives/preprocessed_data/](ds000228-1.1.0-subset/derivatives/preprocessed_data/) contain, for each of 155 participants:
- `sub-pixar###_normed_anat.nii.gz` — anatomical volume normalized to the MNI template (SPM8).
- `sub-pixar###_analysis_mask.nii.gz` — skull-stripping mask.

Participant ages and demographics are in [participants.tsv](ds000228-1.1.0-subset/participants.tsv).

Class distribution: 65 subjects aged 3–5, 57 aged 7–12, 33 adults.

## Requirements

- MATLAB R2025a or later
- Deep Learning Toolbox
- Image Processing Toolbox
- Medical Imaging Toolbox (for `niftiread`)
- Deep Learning Toolbox Model for ResNet-18 Network support package
- **Parallel Computing Toolbox** — required for GPU training (Stage 1) and `parfor`-based multi-model training (Stage 2). Essential for the HPC scaling portion of the workshop.
- **MATLAB Parallel Server** — required to run the same scripts against an HPC cluster instead of a local pool.
- (Optional) MATLAB Coder + GPU Coder — to generate deployable inference code from `predictfcn.m`.

## Getting Started — Desktop Walk-Through

1. Open MATLAB in this directory.
2. Run [E00_DataPrep.m](E00_DataPrep.m) to build the 2D image dataset from the 3D volumes (or use the pre-generated `2DImageSet_28May2026_064146/` folder).
3. Run [E01_TransferLearning.m](E01_TransferLearning.m) to train and evaluate a single ResNet-18 model on the local GPU.
4. Run [E02_multiModel.m](E02_multiModel.m) to train several models in parallel on a local parallel pool.

## Scaling Out to an HPC Cluster

The Stage 2 script is the entry point for cluster execution. The same `parfor` body that runs on a local pool will run on a cluster pool once an appropriate cluster profile is configured.

**1. Configure a cluster profile** (one-time setup, MATLAB → *Parallel* → *Discover Clusters* / *Create and Manage Clusters*). Common backends:
- Slurm, PBS, LSF, SGE, HTCondor (via MATLAB Parallel Server)
- AWS, Azure (via Cloud Center)

**2. Start a pool on the cluster** instead of locally:

```matlab
c = parcluster('myClusterProfile');   % your configured profile
pool = parpool(c, 8);                 % 8 workers on the cluster
```

**3. Run the existing script** — `E02_multiModel.m` will distribute its `parfor` iterations to cluster workers without code changes. Each worker can claim a GPU on its node when `ExecutionEnvironment="auto"` is set in the training options.

**4. Submit non-interactively** with `batch` for long-running sweeps:

```matlab
job = batch(c, 'E02_multiModel', 'Pool', 7, 'CurrentFolder', '.');
wait(job);
load(job);
```

**Tips for scaling further:**
- For larger datasets, replace `imageDatastore` with a partitionable datastore so workers read disjoint shards.
- Use `trainingOptions("...", "ExecutionEnvironment", "multi-gpu")` or `"parallel"` to use multiple GPUs *within* a single training run.
- Combine the two levels of parallelism — multi-GPU within a worker, `parfor` across workers — for large hyperparameter sweeps on multi-GPU nodes.

## Inference Function

[predictfcn.m](predictfcn.m) is a codegen-friendly entry-point intended for deployment:

```matlab
[score, infTime] = predictfcn(inputImage);
```

It loads a saved network (`finetundedNet.mat`) the first time it is called, resizes the input to 227×227, and returns class scores plus inference time. Save your trained network to `finetundedNet.mat` before using it.

## Image Classifier App

The [image-classifier-app/](image-classifier-app/) subdirectory contains an App Designer application for interactively training image classification models — useful as a no-code alternative to the scripts above. See [image-classifier-app/README.md](image-classifier-app/README.md) for details.

## References

1. Richardson, H. et al. (2018). Development of the social brain from age three to twelve years. *Nature Communications*, 9(1), 1027.
2. OpenNEURO dataset ds000228 — https://openneuro.org/datasets/ds000228/versions/1.1.0
3. Statistical Parametric Mapping (SPM) — https://www.fil.ion.ucl.ac.uk/spm/software/

## License

See [LICENSE.md](LICENSE.md). Copyright © 2020–2026 The MathWorks, Inc.
