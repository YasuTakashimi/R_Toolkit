# R_Calc.ijm — User Manual

*[日本語版はこちら](README_ja.md)*

**Version:** 1.0 (2026)  
**Author:** TAKASHIMIZU, Yasuhiro (Laboratory of Geology, Faculty of Education, Niigata University)  
**License:** MIT License

---

## Table of Contents

1. [What is R_Calc?](#1-what-is-r_calc)
2. [Citation](#2-citation)
3. [Requirements](#3-requirements)
4. [Folder Structure](#4-folder-structure)
5. [Photography Recommendations](#5-photography-recommendations)
6. [Installation](#6-installation)
7. [How to Use](#7-how-to-use)
8. [Output Files](#8-output-files)
9. [Formulas](#9-formulas)
10. [Particle Exclusion Criteria](#10-particle-exclusion-criteria)
11. [Re-analysis](#11-re-analysis)
12. [Notes and Limitations](#12-notes-and-limitations)
13. [FAQ](#13-faq)
14. [License](#14-license)
15. [Support & Feedback](#15-support--feedback)

---

## 1. What is R_Calc?

R_Calc.ijm is an ImageJ macro that semi-automatically calculates the roundness parameter *R* of particles (gravel, sand grains, industrial powders, microplastics, crushed stone, railway ballast, etc.) from optical photographs, microscope images, and scanner images.

R_Calc.ijm is a simplified version of R_Lab.ijm. **It does not perform scale calibration (pixels / mm) and calculates *R* values in pixel units only.** Use R_Calc when actual grain size in mm is not required, or when working with images that lack scale information. If scale calibration and mm-unit output are needed, use R_Lab.ijm instead.

### Key Features

- Removal of unwanted objects (labels, scale bars, dust, etc.)
- Automatic binarization using the Otsu method
- Automatic particle detection and shape measurement
- CSV output of *R* values and aspect ratio (pixel units)
- Re-analysis and version management per sample

### What is *R*?

*R* is a roundness parameter proposed by Takashimizu & Iiyoshi (2016), defined as **circularity corrected by aspect ratio**. It resolves the problem of conventional circularity being underestimated for elongated particles.

---

## 2. Citation

When publishing research using R_Calc.ijm, please cite the following paper:

> Takashimizu, Y. & Iiyoshi, M., 2016,  
> New parameter of roundness *R*: circularity corrected by aspect ratio.  
> *Progress in Earth and Planetary Science*, **3**, 2, pp. 1–16.  
> DOI: [10.1186/s40645-015-0078-x](https://doi.org/10.1186/s40645-015-0078-x)

---

## 3. Requirements

| Item | Requirement |
|------|-------------|
| Software | Fiji (ImageJ 2.x) |
| Java | Java 21 or later |
| OS | Windows 10/11, macOS, Linux |

Fiji is available free of charge at [https://fiji.sc](https://fiji.sc).

---

## 4. Folder Structure

Before using R_Calc, prepare the following folder structure:

```
Any folder (project folder)/
├── input_R_Calc/              ← Place image data here (name is fixed)
│   ├── SampleA/              ← Sample folder (any name)
│   │   ├── image001.jpg
│   │   └── image002.jpg
│   └── SampleB/
│       └── image001.jpg
└── output_R_Calc/             ← Created automatically (name is fixed)
```

### Folder and File Naming Rules

- The names `input_R_Calc` and `output_R_Calc` **cannot be changed**
- **Commas (,) cannot be used** in sample folder names or image file names
- Sample folder names cannot contain `..`, `/`, or `\`
- Supported image formats: JPG, JPEG, TIF, TIFF, BMP, PNG

---

## 5. Photography Recommendations

For accurate roundness measurement, it is important to prepare images in which particle silhouettes can be clearly identified. **Backlit (transmitted light) photography is recommended.**

- **Indoors:** Placing particles on a light transmission table provides sharper outlines.
- **Outdoors:** Placing particles on a transparent plate and photographing from below with the sky as background yields well-defined particle contours.

---

## 6. Installation

### Quick Test (First Time)

If you want to try the macro before installing:

1. Launch Fiji
2. Drag and drop `R_Calc.ijm` onto the Fiji window
3. The Script Editor will open
4. Click the **Run** button (or press Ctrl+R) to execute

Alternatively, select `R_Calc.ijm` from the menu via `Plugins > Macros > Run...`.

### Permanent Installation (Regular Use)

Once you are satisfied with the macro, install it permanently so it is always accessible from the menu:

1. Launch Fiji
2. Drag and drop `R_Calc.ijm` onto the Fiji window
3. The Script Editor will open
4. Click the **Install** button
5. R_Calc will appear in the **Plugins** menu
6. You can run it anytime via **Plugins → R_Calc**

---

## 7. How to Use

### Step 1: Launch — Splash Screen

When the macro is executed, author information and citation details are displayed. Click "OK" to proceed.

---

### Step 2: Select the `input_R_Calc` Folder

A dialog opens to select the `input_R_Calc` folder.  
**An error will occur if the folder name is not `input_R_Calc`.**

---

### Step 3: Sample Selection (Dialog 1)

Select the samples to analyze.

```
┌──────────────────────────────────────┐
│ Select Samples to Analyze            │
│                                      │
│ Samples found:                       │
│   SampleA   [new]                    │
│   SampleB   [previous run found]     │
│                                      │
│ Analyze:                             │
│ ○ New only  ← default                │
│ ○ All                                │
│ ○ Individual                         │
└──────────────────────────────────────┘
```

| Option | Behavior |
|--------|----------|
| **New only** | Select only samples not previously analyzed (default) |
| **All** | Select all samples |
| **Individual** | Select individually via checkboxes (Dialog 2 opens) |

`[new]` indicates a first-time analysis; `[previous run found]` indicates a previously analyzed sample.

---

### Step 3b: Individual Selection (Individual option only)

When Individual is selected, a checkbox list for each sample is displayed.  
By default, only `[new]` samples are checked.

---

### Step 4: Re-analysis Mode (only if previously analyzed samples are selected)

Displayed when previously analyzed samples are included in the selection.

| Option | Behavior |
|--------|----------|
| **Keep previous results (versioned re-run)** | Retain previous results and output as a new version (`_v2`, `_v3`, …) |
| **Delete previous results** | Delete the specified version(s) before re-analyzing |

Choosing "Delete" opens a dialog to select which versions to delete per sample (all unchecked by default to prevent accidental deletion).  
The analysis completion timestamp for each version is shown next to the version name.

---

### Step 5: Removal of Unwanted Objects (per image)

Remove unwanted objects — scale bars, labels, dust, etc. — by painting them white.

1. Select the region to remove using the Rectangle, Polygon, or Freehand tool
2. Click "OK" to paint it white
3. The following options are presented:
   - **Yes - proceed to binarization**: removal complete, proceed to binarization
   - **No - select another object**: continue removing another region
   - **Redo - undo last fill and reselect**: undo the last white fill

If OK is pressed without a selection:
- **Yes - proceed to binarization**: proceed to binarization without removal
- **No - select another object**: redo the selection

---

### Step 6: Automated Processing (Binarization → Particle Detection → *R* Calculation)

The following steps run automatically:

1. **Automatic binarization** using the Otsu method
2. **Save binarized PNG** (in the `output_R_Calc/SampleA/` folder)
3. **Particle detection** via Analyze Particles
4. ***R* value calculation** and CSV output

---

### Step 7: Completion Dialog

When all samples have been processed, the total detected particles, valid particles, and exclusion rate are displayed.

---

## 8. Output Files

### Folder Structure

```
output_R_Calc/
├── SampleA/                      ← Binarized PNGs (per sample)
│   ├── image001.png
│   └── image002.png
├── Particle_R_SampleA.csv        ← Particle data (per sample)
└── Particle_R_Summary.csv        ← Exclusion summary (cumulative across all runs)
```

With re-analysis (Keep mode):

```
output_R_Calc/
├── SampleA/                      ← First run
├── SampleA_v2/                   ← Second run
├── Particle_R_SampleA.csv
├── Particle_R_SampleA_v2.csv
└── Particle_R_Summary.csv
```

---

### Columns in Particle_R_SampleA.csv

| Column | Description |
|--------|-------------|
| FolderName | Sample folder name |
| FileName | Original image file name |
| ParticleID | Sequential particle number within the image (valid particles only) |
| Area_px2 | Particle area (px²) |
| Perimeter_px | Particle perimeter (px) |
| Major_px | Major axis length of the best-fit ellipse to the particle silhouette (px) |
| Minor_px | Minor axis length of the best-fit ellipse to the particle silhouette (px) |
| AR_I | Aspect ratio (Major / Minor) |
| R | Roundness parameter *R* |

> **Note:** R_Calc.ijm does not perform scale calibration; all measurements are in pixel units. If grain size in mm is required, use R_Lab.ijm instead.

---

### Columns in Particle_R_Summary.csv

| Column | Description |
|--------|-------------|
| FolderName | Sample folder name (including version suffix) |
| ExcludedMajor | Number of particles excluded for Major < 100 px |
| ExcludedAR | Number of particles excluded for AR > 10 |
| RunTimestamp | Analysis completion timestamp for the sample (yyyy/mm/dd hh:mm) |

This file is **appended** across runs. If the same sample is analyzed multiple times, a new row is added each time.

---

## 9. Formulas

Based on Takashimizu & Iiyoshi (2016):

### Circularity

$$C_I = \frac{4\pi \cdot \text{Area}}{\text{Perimeter}^2}$$

### Aspect Ratio

$$AR_I = \frac{\text{Major}}{\text{Minor}}$$

### Aspect Ratio Correction Factor (6th-degree polynomial)

$$C_{AR} = 0.826261 + 0.337479 \cdot AR - 0.335455 \cdot AR^2 + 0.103642 \cdot AR^3 - 0.0155562 \cdot AR^4 + 0.00114582 \cdot AR^5 - 0.0000330834 \cdot AR^6$$

### Roundness Parameter R

$$R = C_I + (0.913 - C_{AR})$$

Particles in the 0.1–0.9 range of Krumbein (1941) yield *R* values between 0.7 and 0.913 (Takashimizu and Iiyoshi, 2016). Lower values indicate more angular particles; values approaching 0.913 indicate well-rounded particles.

---

## 10. Particle Exclusion Criteria

Particles meeting the following conditions are excluded from calculation and counted in the Summary CSV:

| Condition | Reason |
|-----------|--------|
| Major < 100 px | Pixelation error is too large for reliable shape measurement. This also means that small scratches or particles in the background of the digital image are automatically excluded. Conversely, any object with Major > 100 px is treated as a particle. Remove scale bars and large scratches in Step 5. |
| AR > 10 | Too elongated to be meaningful as a roundness indicator |

> **Recommendation:** Set the magnification and resolution so that particle images have a major axis of at least 100 px.

---

## 11. Re-analysis

When re-analyzing the same sample, two modes are available:

### Keep Mode (version management)

Output is saved as a new version while retaining previous results:

```
SampleA        → first run
SampleA_v2     → second run
SampleA_v3     → third run
```

A new row for each version is appended to the Summary CSV (distinguishable by the completion timestamp).

### Delete Mode (delete and re-analyze)

The specified version(s) are deleted before re-analysis.  
All checkboxes in the deletion dialog default to unchecked, minimizing the risk of accidental deletion.

> **Note:** Rows in the Summary CSV are not deleted (they are retained as a record of analysis history).

---

## 12. Notes and Limitations

- **Commas cannot be used** in folder or file names (CSV output will be corrupted)
- Folder names cannot contain `..`, `/`, or `\`
- A maximum of **100** sample folders are supported within a single `input_R_Calc` folder
- Up to **50** re-analysis versions are managed per sample (`_v2` through `_v51`)
- R_Calc.ijm does not perform scale calibration; grain size in mm units is not output

---

## 13. FAQ

**Q. I get the error "The selected folder must be named 'input_R_Calc'"**  
A. Please select a folder named `input_R_Calc`. If the spelling differs, rename the folder accordingly.

**Q. No particles are detected at all**  
A. Check the saved PNG to verify that the image was binarized correctly. Also confirm that particles were not accidentally painted white during Step 5.

**Q. The Summary CSV has multiple rows for the same sample name**  
A. This is the record of multiple analyses of the same sample (Keep mode or re-analysis after deletion). Use the RunTimestamp column to distinguish between runs.

**Q. A large number of particles are excluded**  
A. Check the ExcludedMajor column in the Summary CSV. If many particles have Major < 100 px, consider increasing the magnification or using a higher-resolution scanner.

**Q. I also want grain size output in mm**  
A. Use R_Lab.ijm, which includes scale calibration. R_Lab.ijm outputs arithmetic mean diameter, geometric mean diameter, and minimum/maximum Feret diameter in millimeters.

---

## 14. License

```
MIT License

Copyright (c) 2026 TAKASHIMIZU, Yasuhiro, Niigata University

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

*The scientific design and validation of this macro were performed entirely by the author. AI coding assistance (Claude, Anthropic) was used during development.*

---

## 15. Support & Feedback

If you encounter bugs, have questions, or want to suggest improvements, please open an Issue on GitHub:

→ [https://github.com/Yasu-Takashimi/R_Toolkit/issues](https://github.com/Yasu-Takashimi/R_Toolkit/issues)

When reporting a bug, please include:
- Error message (if any)
- Steps to reproduce the issue
- ImageJ/Fiji version
- Sample image (if possible)
