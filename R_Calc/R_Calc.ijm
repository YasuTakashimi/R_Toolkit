// ============================================================
// R_Calc.ijm
// ------------------------------------------------------------
// Description:
//   Simplified macro for particle R calculation without scale
//   calibration. Outputs R values in pixel units.
//
// Author  : TAKASHIMIZU, Yasuhiro
//           Faculty of Education, Niigata University, Japan
//
// Copyright (c) 2026 TAKASHIMIZU, Yasuhiro, Niigata University.
// Released under the MIT License.
//
// If you use this macro in published work, please cite:
//   Takashimizu, Y. & Iiyoshi, M. (2016).
//   "New parameter of roundness *R*: circularity corrected
//    by aspect ratio."
//   Progress in Earth and Planetary Science, 3, 2, pp. 1-16.
//   DOI: 10.1186/s40645-015-0078-x
//   URL: https://doi.org/10.1186/s40645-015-0078-x
//
// Developed with AI coding assistance (Claude, Anthropic).
// All scientific design and validation by the author.
//
// Software : Fiji (ImageJ 2.x), Java 21
// Version  : 1.0  (TBD)
// ============================================================

// ========== Block 0: Splash screen ==========

Dialog.create("R_Calc");
Dialog.addMessage("R_Calc - Roundness Calculator (no scale)\n" +
    "TAKASHIMIZU, Yasuhiro, Niigata University (2026)");
Dialog.addMessage("We appreciate your use of this tool.");
Dialog.addMessage("If you use this tool in published work, please cite:\n" +
    "  Takashimizu & Iiyoshi (2016)\n" +
    "  Progress in Earth and Planetary Science, 3, 2\n" +
    "  DOI: 10.1186/s40645-015-0078-x");
Dialog.show();


// ========== Block 1: Initialization ==========

// Block 1.1: Select and validate input_R_Calc folder
inputDir = getDirectory("Select the 'input_R_Calc' folder");

// Extract the native path separator from inputDir (last character).
// getDirectory() returns paths ending with the OS-native separator:
//   Windows -> "\"  /  macOS/Linux -> "/"
// Using this separator consistently prevents mixed-slash path issues on Windows,
// where File.makeDirectory() can fail silently on paths like "C:\foo/bar".
nativeSep = substring(inputDir, lengthOf(inputDir) - 1);

inputDirTrimmed = substring(inputDir, 0, lengthOf(inputDir) - 1);
lastSlash = lastIndexOf(inputDirTrimmed, "/");
if (lastSlash == -1) lastSlash = lastIndexOf(inputDirTrimmed, "\\");
inputFolderName = substring(inputDirTrimmed, lastSlash + 1);
parentDir       = substring(inputDirTrimmed, 0, lastSlash + 1);

if (inputFolderName != "input_R_Calc") {
    exit("Error: The selected folder must be named 'input_R_Calc'.\n" +
         "Selected: '" + inputFolderName + "'\n\n" +
         "Please re-run the macro and select the correct folder.");
}
print("input_R_Calc : " + inputDir);

// Block 1.2: Create output_R_Calc (sibling of input_R_Calc)
outputDir = parentDir + "output_R_Calc" + nativeSep;
if (!File.isDirectory(outputDir)) {
    File.makeDirectory(outputDir);
    print("Created output folder: " + outputDir);
} else {
    print("Using existing output folder: " + outputDir);
}

// Block 1.3: Scan input_R_Calc for sample subfolders
// sampleHasPrev: 0 = new (no previous output), 1 = previous run found
maxSamples    = 100;
sampleNames   = newArray(maxSamples);
sampleHasPrev = newArray(maxSamples);
nSamples = 0;

allEntries = getFileList(inputDir);
for (i = 0; i < allEntries.length; i++) {
    // Identify subfolders robustly across platforms.
    // Case 1 (standard): getFileList() appends "/" -> strip it to get folderLabel.
    // Case 2 (fallback): no trailing "/" -> treat full entry as folderLabel if it IS
    //   a directory (covers Windows environments where "\" may be used instead).
    // Files (images, etc.) are skipped in both cases.
    if (endsWith(allEntries[i], "/")) {
        folderLabel = substring(allEntries[i], 0, lengthOf(allEntries[i]) - 1);
    } else if (File.isDirectory(inputDir + allEntries[i])) {
        folderLabel = allEntries[i];
    } else {
        continue;  // not a folder -> skip
    }

    // Security: reject folder names that could cause CSV injection or path traversal.
    // Comma      -> would corrupt CSV column structure.
    // ".."       -> could escape outputDir when used in path construction.
    // "/" or "\" -> path separator in a folder name indicates an unsafe entry.
    if (indexOf(folderLabel, ",") >= 0) {
        print("WARNING: Skipping folder '" + folderLabel +
              "': commas are not allowed in sample folder names.");
        continue;
    }
    if (indexOf(folderLabel, "..") >= 0 ||
        indexOf(folderLabel, "/")  >= 0 ||
        indexOf(folderLabel, "\\") >= 0) {
        print("WARNING: Skipping folder '" + folderLabel +
              "': path separators and '..' are not allowed in sample folder names.");
        continue;
    }

    // Guard against array overflow: skip folders beyond maxSamples.
    if (nSamples >= maxSamples) {
        print("WARNING: More than " + maxSamples + " sample folders found.");
        print("         Only the first " + maxSamples + " folders will be processed.");
        print("         Increase maxSamples in Block 1.3 if needed.");
        i = allEntries.length;  // exit the for loop
        continue;
    }
    sampleNames[nSamples] = folderLabel;

    // Check if any output already exists for this sample.
    prevExists = 0;
    if (File.isDirectory(outputDir + folderLabel)) {
        prevExists = 1;
    }
    if (prevExists == 0 && File.exists(outputDir + "Particle_R_" + folderLabel + ".csv")) {
        prevExists = 1;
    }
    if (prevExists == 0) {
        for (ve = 2; ve <= 50; ve++) {
            veName = folderLabel + "_v" + d2s(ve, 0);
            if (File.isDirectory(outputDir + veName)) {
                prevExists = 1;
                ve = 51;
            }
            if (prevExists == 0 && File.exists(outputDir + "Particle_R_" + veName + ".csv")) {
                prevExists = 1;
                ve = 51;
            }
        }
    }
    sampleHasPrev[nSamples] = prevExists;
    nSamples++;
}
if (nSamples == 0) {
    exit("No sample subfolders found in:\n" + inputDir);
}

// Block 1.4: Sample selection - two-dialog design.
// Dialog 1 (always): shows sample list and Quick select radio buttons.
// Dialog 2 (Individual only): shows per-sample checkboxes.
sampleListMsg = "";
for (i = 0; i < nSamples; i++) {
    if (sampleHasPrev[i] == 0) {
        sampleStatusStr = "[new]";
    } else {
        sampleStatusStr = "[previous run found]";
    }
    sampleListMsg = sampleListMsg + "  " + sampleNames[i] + "   " + sampleStatusStr + "\n";
}

// Dialog 1: Quick select
Dialog.create("Select Samples to Analyze");
Dialog.addMessage("input_R_Calc: " + inputDir);
Dialog.addMessage(" ");
Dialog.addMessage("Samples found:\n" + sampleListMsg);
Dialog.addRadioButtonGroup("Analyze:",
    newArray("New only", "All", "Individual"),
    3, 1, "New only");
Dialog.show();

quickSelect = Dialog.getRadioButton();
selectedFlags = newArray(nSamples);

if (quickSelect == "All") {
    for (i = 0; i < nSamples; i++) selectedFlags[i] = 1;

} else if (quickSelect == "New only") {
    for (i = 0; i < nSamples; i++) {
        if (sampleHasPrev[i] == 0) {
            selectedFlags[i] = 1;
        } else {
            selectedFlags[i] = 0;
        }
    }

} else {
    // Individual: Dialog 2 - checkbox per sample.
    Dialog.create("Individual Sample Selection");
    Dialog.addMessage("Check the samples to analyze:");
    Dialog.addMessage(" ");
    for (i = 0; i < nSamples; i++) {
        if (sampleHasPrev[i] == 0) {
            sampleStatusStr = "[new]";
        } else {
            sampleStatusStr = "[previous run found]";
        }
        defaultCheck = (sampleHasPrev[i] == 0);
        Dialog.addCheckbox(sampleNames[i] + "   " + sampleStatusStr, defaultCheck);
    }
    Dialog.show();
    for (i = 0; i < nSamples; i++) {
        if (Dialog.getCheckbox()) {
            selectedFlags[i] = 1;
        } else {
            selectedFlags[i] = 0;
        }
    }
}

nSelected = 0;
for (i = 0; i < nSamples; i++) {
    if (selectedFlags[i]) nSelected++;
}
if (nSelected == 0) {
    exit("No samples selected. Macro terminated.");
}

// Block 1.5: Re-analysis mode
anyPrevSelected = 0;
for (i = 0; i < nSamples; i++) {
    if (selectedFlags[i] == 1 && sampleHasPrev[i] == 1) anyPrevSelected = 1;
}

reanalysisMode = "keep";
if (anyPrevSelected == 1) {
    Dialog.create("Re-analysis Mode");
    Dialog.addMessage(
        "One or more selected samples have previous analysis results.");
    Dialog.addRadioButtonGroup("",
        newArray("Keep previous results (versioned re-run)",
                 "Delete previous results (select versions to delete)"),
        2, 1, "Keep previous results (versioned re-run)");
    Dialog.show();
    modeLabel = Dialog.getRadioButton();
    if (indexOf(modeLabel, "Delete") >= 0) reanalysisMode = "delete";
}

if (reanalysisMode == "delete") {
    for (i = 0; i < nSamples; i++) {
        if (selectedFlags[i] == 0 || sampleHasPrev[i] == 0) continue;

        verNames = newArray(52);
        nVers    = getVersionNames(sampleNames[i], verNames);
        if (nVers == 0) continue;

        Dialog.create("Delete Previous Results - " + sampleNames[i]);
        Dialog.addMessage(
            "Select versions to DELETE:\n" +
            "(default: none selected = keep all)");
        for (v = 0; v < nVers; v++) {
            verTS = "";
            summaryPathChk = outputDir + "Particle_R_Summary.csv";
            if (File.exists(summaryPathChk)) {
                sumContent = File.openAsString(summaryPathChk);
                sumLines   = split(sumContent, "\n");
                for (ll = 1; ll < sumLines.length; ll++) {
                    sumLine = replace(sumLines[ll], "\r", "");
                    if (sumLine == "") continue;
                    sumCols = split(sumLine, ",");
                    if (sumCols.length >= 4 && sumCols[0] == verNames[v]) {
                        verTS = sumCols[3];
                    }
                }
            }
            label = verNames[v];
            if (verTS != "") label = label + "   [" + verTS + "]";
            Dialog.addCheckbox(label, 0);
        }
        Dialog.show();

        for (v = 0; v < nVers; v++) {
            if (Dialog.getCheckbox()) {
                deleteVersionOutput(verNames[v], nativeSep);
                print("Deleted previous run: " + verNames[v]);
            }
        }
    }
}

// Block 1.6: Store indices of selected samples
selectedIndices = newArray(nSelected);
idx = 0;
for (i = 0; i < nSamples; i++) {
    if (selectedFlags[i] == 0) continue;
    selectedIndices[idx] = i;
    idx++;
}

// Block 1.7: Initialize statistics and runtime variables
summaryNewRows  = "";
layerLabelsList = "";

totalValidGlobal    = 0;
totalDetectedGlobal = 0;

// Set Measurements once here (not repeated per image)
run("Set Measurements...",
    "area perimeter shape fit feret's redirect=None decimal=6");


// ========== Block 3: Sample loop ==========

print("");
print("============================================================");
print("Block 3-8: Image Processing");
print("============================================================");

for (s = 0; s < nSelected; s++) {
    sIdx           = selectedIndices[s];
    layerInputName = sampleNames[sIdx];

    // Determine output name (versioned if previous run exists).
    layerLabel = layerInputName;
    if (File.isDirectory(outputDir + layerLabel) ||
        File.exists(outputDir + "Particle_R_" + layerLabel + ".csv")) {
        layerLabelFound = 0;
        for (vn = 2; vn <= 100; vn++) {
            if (layerLabelFound == 0) {
                vnCandidate = layerInputName + "_v" + d2s(vn, 0);
                if (!File.isDirectory(outputDir + vnCandidate) &&
                    !File.exists(outputDir + "Particle_R_" + vnCandidate + ".csv")) {
                    layerLabel      = vnCandidate;
                    layerLabelFound = 1;
                    vn = 101;
                }
            }
        }
        if (layerLabelFound == 0) {
            layerLabel = layerInputName + "_v101";
        }
    }

    layerDir = inputDir + layerInputName + nativeSep;

    print("");
    if (layerLabel != layerInputName) {
        print("Sample '" + layerInputName + "' -> output as '" + layerLabel + "':");
    } else {
        print("Sample '" + layerInputName + "':");
    }
    print("------------------------------------------------------------");

    // Create layer output folder for PNG
    layerOutputDir = outputDir + layerLabel + nativeSep;
    if (!File.isDirectory(outputDir + layerLabel)) {
        File.makeDirectory(outputDir + layerLabel);
    }

    // Open layer-specific CSV
    layerCSVPath = outputDir + "Particle_R_" + layerLabel + ".csv";
    layerFileOut = File.open(layerCSVPath);
    print(layerFileOut, "FolderName,FileName,ParticleID," +
        "Area_px2,Perimeter_px,Major_px,Minor_px," +
        "AR_I,R");

    // Layer-level statistics
    layerTotalDetected   = 0;
    layerTotalValid      = 0;
    layerExcludedMajorCount = 0;
    layerExcludedARCount    = 0;


    // ========== Block 4: Image file loop ==========

    fileList = getFileList(layerDir);
    for (i = 0; i < fileList.length; i++) {
        fname  = fileList[i];
        flower = toLowerCase(fname);

        // Filter image files
        if (!endsWith(flower, ".jpg") && !endsWith(flower, ".jpeg") &&
            !endsWith(flower, ".tif") && !endsWith(flower, ".tiff") &&
            !endsWith(flower, ".bmp") && !endsWith(flower, ".png")) continue;

        // Security: reject file names with commas (CSV injection) or
        // path-traversal sequences.
        if (indexOf(fname, ",") >= 0) {
            print("  WARNING: Skipping '" + fname +
                  "': commas are not allowed in image file names.");
            continue;
        }
        if (indexOf(fname, "..") >= 0) {
            print("  WARNING: Skipping '" + fname +
                  "': '..' sequence is not allowed in image file names.");
            continue;
        }

        print("  Processing: " + fname);
        open(layerDir + fname);

        if (nImages == 0) {
            print("  WARNING: Failed to open " + fname + " - skipping.");
            continue;
        }


        // ========== Block 5: Label/object removal ==========
        // Remove unwanted objects (labels, debris, etc.) by painting white.
        run("Select None");
        setBackgroundColor(255, 255, 255);
        setForegroundColor(255, 255, 255);
        setTool("rectangle");

        selectionDone  = 0;
        selectionCount = 0;
        snapshotIDs    = newArray(0);

        while (selectionDone == 0) {
            waitForUser("Remove Unwanted Objects",
                "Exclude unnecessary objects (labels, debris, etc.).\n\n" +
                "1. Enclose the object with Rectangle, Polygon, or Freehand tool.\n" +
                "2. Click OK to fill with white.\n\n" +
                "Image: " + fname);

            type = selectionType();

            // Pattern C: Invalid selection tool
            if (type != -1 && type != 0 && type != 2 && type != 3) {
                showMessage("Error",
                    "Invalid selection type.\n" +
                    "Please use Rectangle, Polygon, or Freehand tool.\n" +
                    "Try again.");
                continue;
            }

            // Pattern A: Valid selection -> fill with white
            if (type == 0 || type == 2 || type == 3) {
                currentID = getImageID();
                run("Select None");
                run("Duplicate...", "title=snap_" + d2s(selectionCount + 1, 0));
                snapID = getImageID();
                setLocation(-9999, 0);
                snapshotIDs = Array.concat(snapshotIDs, snapID);
                selectImage(currentID);

                run("Restore Selection");
                run("Fill", "slice");
                run("Select None");
                selectionCount++;
                print("    Filled selection " + selectionCount);

                Dialog.create("Continue?");
                Dialog.addMessage("Finish object removal and proceed to binarization?");
                Dialog.addRadioButtonGroup("",
                    newArray("Yes - proceed to binarization",
                             "No - select another object",
                             "Redo - undo last fill and reselect"),
                    3, 1, "No - select another object");
                Dialog.show();
                ans = Dialog.getRadioButton();

                if (ans == "Yes - proceed to binarization") {
                    selectionDone = 1;
                } else if (ans == "Redo - undo last fill and reselect") {
                    lastSnapID = snapshotIDs[snapshotIDs.length - 1];

                    if (!isOpen(lastSnapID)) {
                        showMessage("Redo unavailable",
                            "The snapshot image is no longer available.\n" +
                            "Redo cannot be performed.");
                        continue;
                    } else {
                        currentTitle = getTitle();
                        currentID    = getImageID();
                        getLocationAndSize(wrkX, wrkY, wrkW, wrkH);

                        selectImage(lastSnapID);
                        rename(currentTitle);

                        selectImage(currentID);
                        close();

                        selectImage(lastSnapID);
                        setLocation(wrkX, wrkY);

                        snapshotIDs = Array.trim(snapshotIDs, snapshotIDs.length - 1);
                        selectionCount--;
                        print("    Redo: restored to state before fill " +
                              (selectionCount + 1));
                        continue;
                    }
                }
                // "No" -> selectionDone remains 0 -> loop continues

            } else {
                // Pattern B: No selection
                Dialog.create("Continue?");
                Dialog.addMessage("Finish object removal and proceed to binarization?");
                Dialog.addRadioButtonGroup("",
                    newArray("Yes - proceed to binarization",
                             "No - select another object"),
                    2, 1, "No - select another object");
                Dialog.show();
                ans = Dialog.getRadioButton();

                if (ans == "Yes - proceed to binarization") {
                    selectionDone = 1;
                }
            }
        }

        // Clean up remaining snapshots
        for (k = 0; k < snapshotIDs.length; k++) {
            if (isOpen(snapshotIDs[k])) {
                selectImage(snapshotIDs[k]);
                close();
            }
        }


        // ========== Block 6: Binarization (Otsu) + PNG save ==========

        if (bitDepth() != 8) {
            run("8-bit");
        }

        setAutoThreshold("Otsu dark");
        run("Convert to Mask");

        dotIndex = lastIndexOf(fname, ".");
        baseName = substring(fname, 0, dotIndex);
        pngName  = baseName + ".png";
        pngPath  = layerOutputDir + pngName;
        saveAs("PNG", pngPath);
        print("    Saved PNG: " + pngName);


        // ========== Block 7: Analyze Particles ==========

        run("Invert");
        setThreshold(1, 255);

        run("Analyze Particles...",
            "show=Nothing display clear exclude include");
        n = nResults;
        layerTotalDetected += n;
        print("    Detected: " + n + " particles");


        // ========== Block 8: Per-particle R calculation ==========

        validInFile = 0;
        for (j = 0; j < n; j++) {
            major    = getResult("Major",  j);
            minor    = getResult("Minor",  j);
            ari      = getResult("AR",     j);
            ci       = getResult("Circ.",  j);
            area     = getResult("Area",   j);
            perim    = getResult("Perim.", j);

            // Filtering
            if (major < 100) {
                layerExcludedMajorCount++;
                continue;
            }
            if (ari > 10) {
                layerExcludedARCount++;
                continue;
            }

            // R value calculation (Takashimizu & Iiyoshi 2016)
            car = 0.826261 + 0.337479*ari - 0.335455*pow(ari,2) +
                  0.103642*pow(ari,3) - 0.0155562*pow(ari,4) +
                  0.00114582*pow(ari,5) - 0.0000330834*pow(ari,6);
            r = ci + (0.913 - car);

            validInFile++;
            layerTotalValid++;
            totalValidGlobal++;

            print(layerFileOut,
                layerLabel + "," + fname + "," + validInFile + "," +
                d2s(area,  2) + "," + d2s(perim, 4) + "," +
                d2s(major, 4) + "," + d2s(minor, 4) + "," +
                d2s(ari,   4) + "," + d2s(r, 6)
            );
        }

        print("    Valid: " + validInFile + " particles");
        close();
    }

    // Close layer CSV
    File.close(layerFileOut);

    totalDetectedGlobal += layerTotalDetected;

    // Record end-of-sample timestamp
    getDateAndTime(ts_year, ts_month, ts_dow, ts_day, ts_hour, ts_min, ts_sec, ts_msec);
    ts_mm = ts_month + 1;
    if (ts_mm  < 10) { ts_mm_s = "0" + d2s(ts_mm,  0); } else { ts_mm_s = d2s(ts_mm,  0); }
    if (ts_day < 10) { ts_dd_s = "0" + d2s(ts_day, 0); } else { ts_dd_s = d2s(ts_day, 0); }
    if (ts_hour< 10) { ts_hh_s = "0" + d2s(ts_hour,0); } else { ts_hh_s = d2s(ts_hour,0); }
    if (ts_min < 10) { ts_mi_s = "0" + d2s(ts_min, 0); } else { ts_mi_s = d2s(ts_min, 0); }
    layerTimestamp = d2s(ts_year, 0) + "/" + ts_mm_s + "/" + ts_dd_s + " " + ts_hh_s + ":" + ts_mi_s;

    summaryNewRows = summaryNewRows + layerLabel + "," +
        layerExcludedMajorCount + "," + layerExcludedARCount + "," +
        layerTimestamp + "\n";
    if (layerLabelsList == "") {
        layerLabelsList = layerLabel;
    } else {
        layerLabelsList = layerLabelsList + "|" + layerLabel;
    }

    print("");
    print("Summary for '" + layerLabel + "':");
    print("  Detected        : " + layerTotalDetected);
    print("  Valid           : " + layerTotalValid);
    print("  Excl (major<100): " + layerExcludedMajorCount);
    print("  Excl (AR>10)    : " + layerExcludedARCount);
    print("");
}


// ========== Block 9: Summary CSV ==========

summaryPath   = outputDir + "Particle_R_Summary.csv";
summaryExists = File.exists(summaryPath);

if (summaryExists == 0) {
    finalContent = "FolderName,ExcludedMajor,ExcludedAR,RunTimestamp\n" + summaryNewRows;
} else {
    existingContent = File.openAsString(summaryPath);
    finalContent    = existingContent + summaryNewRows;
}

File.saveString(finalContent, summaryPath);


// ========== Block 10: Final log and dialog ==========

if (totalDetectedGlobal > 0) {
    globalExcRate = 100 * (totalDetectedGlobal - totalValidGlobal) / totalDetectedGlobal;
} else {
    globalExcRate = 0;
}

print("");
print("============================================================");
print("R_Calc Analysis Complete");
print("============================================================");
print("  Total detected : " + totalDetectedGlobal);
print("  Total valid    : " + totalValidGlobal);
print("  Exclusion rate : " + d2s(globalExcRate, 1) + "%");
print("");
print("Output files:");
labelParts = split(layerLabelsList, "|");
for (i = 0; i < labelParts.length; i++) {
    print("  Particle_R_" + labelParts[i] + ".csv");
}
print("  Particle_R_Summary.csv  (excluded particle counts per folder)");
print("  Location: " + outputDir);
print("============================================================");

showMessage("R_Calc Analysis Complete",
    "Total detected: " + totalDetectedGlobal + "\n" +
    "Total valid   : " + totalValidGlobal + "\n" +
    "Exclusion rate: " + d2s(globalExcRate, 1) + "%" +
    "\n\nOutput files:" +
    "\n  - Particle_R_FolderName.csv" +
    "\n  - Particle_R_Summary.csv  (excluded counts per folder)" +
    "\n\nLocation: " + outputDir);


// ============================================================
// Helper functions
// ============================================================

function getVersionNames(sampleLabel, verNames) {
    count = 0;
    if (File.isDirectory(outputDir + sampleLabel) ||
        File.exists(outputDir + "Particle_R_" + sampleLabel + ".csv")) {
        verNames[count] = sampleLabel;
        count++;
    }
    for (v = 2; v <= 50; v++) {
        if (count >= verNames.length - 1) {
            v = 51;
        } else {
            vName = sampleLabel + "_v" + d2s(v, 0);
            if (File.isDirectory(outputDir + vName) ||
                File.exists(outputDir + "Particle_R_" + vName + ".csv")) {
                verNames[count] = vName;
                count++;
            } else {
                v = 51;
            }
        }
    }
    return count;
}

function deleteVersionOutput(versionName, sep) {
    folderPath = outputDir + versionName + sep;
    if (File.isDirectory(folderPath)) {
        files = getFileList(folderPath);
        for (f = 0; f < files.length; f++) {
            File.delete(folderPath + files[f]);
        }
        File.delete(folderPath);
    }
    csvPath = outputDir + "Particle_R_" + versionName + ".csv";
    if (File.exists(csvPath)) {
        File.delete(csvPath);
    }
}
