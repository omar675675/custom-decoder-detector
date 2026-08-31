> This is a showcase of a custom decoder/detector module. Its source code cannot be shown here due to confidentiality.

# 7 streams, one laptop GPU

This pipeline runs **7 simultaneous 1080p video streams** through a YOLO11
detector on a single **RTX 4060 Laptop GPU**. Below is how it compares against
the two standard ways of building the same thing.

**Headline:** at the same model and the same input, this pipeline delivers
**1.6–2.1× the sustained throughput** of the common approaches, on **a third of
the system RAM**, and it is the **only one of the three that actually saturates
the GPU**.

---

## What's being compared

| | decode | detector |
|---|:--|:--|
| **OpenCV + PyTorch** | `cv2.VideoCapture` (CPU / FFmpeg) | PyTorch YOLO11 |
| **GPU decode + PyTorch** | hardware video decode | PyTorch YOLO11 |
| **This pipeline** | hardware video decode | optimized inference engine, end to end |

**Setup.** 7 local 1080p H.264 clips (25–60 fps each). RTX 4060 Laptop GPU,
8 GB. YOLO11**n** and YOLO11**m**, FP16 — the *same* model for all three configs
in each round. Every run also composites a live 7-tile mosaic and H.264-encodes
it, so the numbers include real output work, not just inference.

*Sustained FPS = detector invocations per second at steady state (aggregate
across the 7 streams).*

---

## YOLO11n (nano)

| | OpenCV + PyTorch | GPU decode + PyTorch | **This pipeline** |
|:--|--:|--:|--:|
| **sustained FPS** | 356 | 263 | **563** |
| vs. this pipeline | 0.63× | 0.47× | **1.00×** |
| per-stream FPS | 50 – 71 | 38 – 56 | **80 – 134** |
| GPU utilisation | ~33 % | ~33 % | **~70 %** |
| system RAM | 3 278 MiB | 2 855 MiB | **1 088 MiB** |
| CPU | ~570 % | ~300 % | **~210 %** |
| GPU memory | 330 MiB | 712 MiB | 1 062 MiB |

## YOLO11m (medium)

| | OpenCV + PyTorch | GPU decode + PyTorch | **This pipeline** |
|:--|--:|--:|--:|
| **sustained FPS** | 184 | 157 | **290** |
| vs. this pipeline | 0.63× | 0.54× | **1.00×** |
| per-stream FPS | 26 – 28 | 22.3 (flat) | **41 – 64** |
| GPU utilisation | ~67 % | ~59 % | **~100 %** |
| system RAM | 3 251 MiB | 2 833 MiB | **1 093 MiB** |
| CPU | ~360 % | ~230 % | ~420 % |
| GPU memory | 648 MiB | 1 028 MiB | 1 320 MiB |

Full per-stream and per-run detail: [`bench/metrics.txt`](bench/metrics.txt).

---

## Why it comes out ahead

**It keeps the GPU busy.** The two PyTorch stacks leave 30–65 % of the card
idle — the work is stuck on the CPU and in shuffling frames back and forth. This
pipeline runs the GPU at 70 % on nano and pegs it at 100 % on medium: the GPU is
the limit, which is where you want it.

**Its memory stays flat and small.** ~1.1 GB of system RAM regardless of model —
a third of the OpenCV baseline's ~3.3 GB. The frame buffers the other stacks
hold in system memory, this one keeps on the GPU (~1.3 GB), which on an 8 GB
card is a non-issue.

**Every stream stays ahead of real time.** On the medium model it holds the
60 fps clips at ~64 fps and the 30 fps clips at ~42 fps — real-time with margin
on all seven at once. The OpenCV stack drops to ~27 fps per stream (behind the
30 fps sources); the GPU-decode-plus-PyTorch stack throttles every stream down
to 22 fps.

**It frees the CPU.** On nano it uses ~2 cores where the OpenCV baseline burns
~6. On medium it uses more (~4 cores) but is doing 1.6× the throughput for it.

*Notes: detection counts differ slightly between the CPU decode path and the
hardware path (they hand the model marginally different pixels); that isn't a
throughput signal so it isn't tabulated. All figures include the mosaic
compositing and encoding.*

---

## See it running

Each clip tiles all 7 streams with the live per-camera and total FPS burnt in.

### YOLO11n

| OpenCV + PyTorch | GPU decode + PyTorch | This pipeline |
|:--:|:--:|:--:|
| <video src="https://github.com/user-attachments/assets/5c11ac49-f2a6-4be8-8c17-20c3ae9743d1" controls width="440"></video> | <video src="https://github.com/user-attachments/assets/a31663de-bef1-47c2-8e55-3c42e4afe54f" controls width="440"></video> | <video src="https://github.com/user-attachments/assets/42db8d08-f111-4f5b-a359-e9062491d8ac" controls width="440"></video> |

### YOLO11m

| OpenCV + PyTorch | GPU decode + PyTorch | This pipeline |
|:--:|:--:|:--:|
| <video src="https://github.com/user-attachments/assets/0f138814-dd21-4e14-85ca-cdfd76ef546f" controls width="440"></video> | <video src="https://github.com/user-attachments/assets/680ff6ab-b204-49be-869e-c87aba4d0103" controls width="440"></video> | <video src="https://github.com/user-attachments/assets/c8ebd5d1-5ad4-47b7-a42f-43d43108754a" controls width="440"></video> |
