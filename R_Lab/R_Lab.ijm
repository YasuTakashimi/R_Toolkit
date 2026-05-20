// ============================================================
// R_Lab.ijm
// ------------------------------------------------------------
// Description:
//   Semi-automated macro for particle silhouette extraction,
//   diameter measurement, and roundness index R calculation.
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

Dialog.create("R_Lab");
Dialog.addMessage("R_Lab - Roundness Analysis Tool\n" +
    "TAKASHIMIZU, Yasuhiro, Niigata University (2026)");
Dialog.addMessage("We appreciate your use of this tool.");
Dialog.addMessage("If you use this tool in published work, please cite:\n" +
    "  Takashimizu & Iiyoshi (2016)\n" +
    "  Progress in Earth and Planetary Science, 3, 2\n" +
    "  DOI: 10.1186/s40645-015-0078-x");
Dialog.show();


// ========== Block 1: Initialization ==========

// Block 1.1: Select and validate input_R_Lab folder
inputDir = getDirectory("Select the 'input_R_Lab' folder");

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

if (inputFolderName != "input_R_Lab") {
    exit("Error: The selected folder must be named 'input_R_Lab'.\n" +
         "Selected: '" + inputFolderName + "'\n\n" +
         "Please re-run the macro and select the correct folder.");
}
print("input_R_Lab : " + inputDir);

// Block 1.2: Create output_R_Lab (sibling of input_R_Lab)
outputDir = parentDir + "output_R_Lab" + nativeSep;
if (!File.isDirectory(outputDir)) {
    File.makeDirectory(outputDir);
    print("Created output folder: " + outputDir);
} else {
    print("Using existing output folder: " + outputDir);
}

// Block 1.3: Scan input_R_Lab for sample subfolders
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
    // Inlined because IJM string assignments inside functions do not
    // propagate back to the outer scope reliably.
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
// Split design ensures radio button and checkbox state are always consistent,
// which is impossible in a single static IJM dialog.

// Build read-only sample list for Dialog 1.
// Uses validated sampleNames (no commas or path separators guaranteed by Block 1.3).
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
Dialog.addMessage("input_R_Lab: " + inputDir);
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
    // Default: [new] samples checked, [previous run found] unchecked.
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
// Shown only when at least one selected sample has previous output.
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

// Delete mode: show per-sample version deletion dialog
if (reanalysisMode == "delete") {
    for (i = 0; i < nSamples; i++) {
        if (selectedFlags[i] == 0 || sampleHasPrev[i] == 0) continue;

        // Size 52 = base name (1) + up to 50 versions (_v2.._v51) + 1 safety margin.
        // Matches the loop range in getVersionNames (v = 2..50).
        verNames = newArray(52);
        nVers    = getVersionNames(sampleNames[i], verNames);
        if (nVers == 0) continue;

        Dialog.create("Delete Previous Results - " + sampleNames[i]);
        Dialog.addMessage(
            "Select versions to DELETE:\n" +
            "(default: none selected = keep all)");
        for (v = 0; v < nVers; v++) {
            // Read RunTimestamp from Summary.csv for verNames[v] (inlined).
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
// Use a numeric index array to avoid string-array limitations of newArray().
// Output names are computed on demand in Block 3 (inlined logic).
selectedIndices = newArray(nSelected);
idx = 0;
for (i = 0; i < nSamples; i++) {
    if (selectedFlags[i] == 0) continue;
    selectedIndices[idx] = i;
    idx++;
}

// Block 1.7: Initialize statistics and runtime variables
// layerNames (string array) is replaced by summaryNewRows and layerLabelsList
// strings to avoid the "Numeric return value expected" issue with newArray().
summaryNewRows  = "";  // accumulates CSV rows for Block 9
layerLabelsList = "";  // "|"-separated labels for Block 10 log

totalValidGlobal    = 0;
totalDetectedGlobal = 0;

// Set Measurements once here (not repeated per image)
run("Set Measurements...",
    "area perimeter shape fit feret's redirect=None decimal=6");

lastRefChoice   = "10 cm";
lastRefOtherStr = "";  // blank by default; value here overrides radio button



// ========== Block 3: Sample loop ==========

print("");
print("============================================================");
print("Block 3-8: Image Processing");
print("============================================================");

for (s = 0; s < nSelected; s++) {
    sIdx           = selectedIndices[s];          // index into sampleNames
    layerInputName = sampleNames[sIdx];           // folder name in input_R_Lab

    // Determine output name: use base name if no prior output exists,
    // otherwise find the next available versioned name (_v2, _v3, ...).
    // Inlined here because IJM string assignments inside functions do not
    // propagate back to the outer scope reliably.
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
                    vn = 101;  // found; exit loop immediately
                }
            }
        }
        if (layerLabelFound == 0) {
            layerLabel = layerInputName + "_v101";  // fallback; should never be reached
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
    // All path separators use nativeSep (extracted from inputDir) to avoid
    // mixed-slash paths on Windows where File.makeDirectory() can fail silently.
    layerOutputDir = outputDir + layerLabel + nativeSep;
    if (!File.isDirectory(outputDir + layerLabel)) {
        File.makeDirectory(outputDir + layerLabel);
    }

    // Open layer-specific CSV
    layerCSVPath = outputDir + "Particle_R_" + layerLabel + ".csv";
    layerFileOut = File.open(layerCSVPath);
    print(layerFileOut, "FolderName,FileName,ParticleID," +
        "Scale_pxPerMm," +
        "Area_px2,Perimeter_px,Major_px,Minor_px," +
        "D_arith_mm,D_geo_mm,D_Feret_min_mm,D_Feret_max_mm," +
        "AR_I,R");

    // Layer-level statistics
    layerTotalDetected = 0;
    layerTotalValid = 0;
    layerExcludedMajorCount = 0;
    layerExcludedARCount = 0;


    // ========== Block 4: Image file loop ==========

    fileList = getFileList(layerDir);
    for (i = 0; i < fileList.length; i++) {
        fname = fileList[i];
        flower = toLowerCase(fname);

        // Filter image files
        if (!endsWith(flower, ".jpg") && !endsWith(flower, ".jpeg") &&
            !endsWith(flower, ".tif") && !endsWith(flower, ".tiff") &&
            !endsWith(flower, ".bmp") && !endsWith(flower, ".png")) continue;

        // Security: reject file names that could cause CSV injection or path traversal.
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

        // Verify that the image was successfully opened
        if (nImages == 0) {
            print("  WARNING: Failed to open " + fname + " - skipping.");
            continue;
        }

        // ========== NEW Block: Per-Image Scale Calibration ==========
        // Two-level loop structure:
        //   Outer loop (calibrationOK): reference length selection
        //   Inner loop (lineOK):        line drawing and confirmation only
        // This allows retrying the line without repeating reference length selection.
        //
        // Note: waitForUser's Cancel button terminates the macro (ImageJ spec).
        //       This cannot be controlled from within the macro.
        calibrationOK = 0;
        pxPerMm = 0;
        pixelLength = 0;
        micronPerPx = 0;

        while (calibrationOK == 0) {
            // --- Outer loop: reference length selection ---
            Dialog.create("Scale Calibration - " + fname);
            Dialog.addMessage("Check the image and select the reference length of the scale bar:");
            Dialog.addRadioButtonGroup("Reference length",
                newArray("15 cm", "12 cm", "10 cm", "5 cm", "2 cm", "1 cm", "Other"), 7, 1, lastRefChoice);
            Dialog.addString("Custom length in cm (overrides radio button; leave blank if not used):",
                lastRefOtherStr);
            Dialog.show();

            lastRefChoice  = Dialog.getRadioButton();
            lastRefOtherStr = Dialog.getString();

            // If a value is entered, it overrides the radio button selection.
            if (lastRefOtherStr != "") {
                refLengthCm = parseFloat(lastRefOtherStr);
                // Validate: must be a positive finite number.
                // d2s() converts NaN/Infinity to string for reliable detection
                // in IJM, where NaN arithmetic behavior is not guaranteed.
                refLengthCmStr = d2s(refLengthCm, 6);
                if (indexOf(refLengthCmStr, "NaN") >= 0 ||
                    indexOf(refLengthCmStr, "Inf") >= 0 ||
                    refLengthCm <= 0) {
                    showMessage("Invalid Input",
                        "Custom length must be a positive number (e.g. 10.5).\n" +
                        "Entered: '" + lastRefOtherStr + "'\n\n" +
                        "Please enter the length in cm and try again.");
                    lastRefOtherStr = "";  // clear invalid input before retrying
                    continue;  // -> outer loop: back to reference length selection
                }
            } else if (lastRefChoice == "15 cm") {
                refLengthCm = 15;
            } else if (lastRefChoice == "12 cm") {
                refLengthCm = 12;
            } else if (lastRefChoice == "10 cm") {
                refLengthCm = 10;
            } else if (lastRefChoice == "5 cm") {
                refLengthCm = 5;
            } else if (lastRefChoice == "2 cm") {
                refLengthCm = 2;
            } else if (lastRefChoice == "1 cm") {
                refLengthCm = 1;
            } else {
                refLengthCm = 10;  // fallback: should not reach here
            }

            refLengthMm = refLengthCm * 10;

            // --- Inner loop: line drawing and confirmation ---
            // "continue" here returns to waitForUser, not to reference length selection.
            lineOK = 0;
            while (lineOK == 0) {
                run("Select None");  // Clear any previous line before user draws
                setTool("line");
                // waitForUser uses JTextArea (plain text); HTML is not rendered.
                // Target length is shown in the title bar (visually distinct)
                // and repeated with >>> <<< emphasis in the body.
                waitForUser("Scale Calibration  -  Target: " + refLengthCm + " cm (" + refLengthMm + " mm)",
                    ">>> " + refLengthCm + " cm (" + refLengthMm + " mm) <<<\n\n" +
                    "Please draw a straight line over the scale bar.\n\n" +
                    "1. Draw a line using the Line tool.\n" +
                    "2. Click OK when finished.\n" +
                    "   (To change reference length: click OK without drawing,\n" +
                    "    then select 'Change reference length' below.)\n\n" +
                    "*** WARNING: Clicking Cancel or pressing Escape will terminate the macro. ***\n" +
                    "*** To retry, click OK and select 'Redo' in the next dialog. ***\n\n" +
                    "Image: " + fname);

                // Validate: must be a straight line (type 5)
                if (selectionType() != 5) {
                    // No line drawn -> ask whether to retry or change reference length
                    Dialog.create("No Line Detected");
                    Dialog.addMessage("No straight line was detected.\n" +
                                      "Please choose an action:");
                    Dialog.addRadioButtonGroup("",
                        newArray("Retry - draw the line again",
                                 "Change reference length"),
                        2, 1, "Retry - draw the line again");
                    Dialog.show();
                    action = Dialog.getRadioButton();

                    if (action == "Retry - draw the line again") {
                        continue;  // -> inner loop: back to waitForUser
                    } else {
                        lineOK = -1;  // signal to exit inner loop without confirming
                        continue;    // skip getLine() and Confirm dialog below;
                                     // inner loop re-checks lineOK==0 (false) and exits
                    }
                }

                // Get line endpoints (Method A)
                getLine(x1, y1, x2, y2, lineWidth);
                pixelLength = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));

                pxPerMm = pixelLength / refLengthMm;
                micronPerPx = 1000.0 / pxPerMm;

                // Confirmation dialog
                Dialog.create("Confirm Calibration");
                // 100 px threshold is shown explicitly as it is the exclusion criterion in the paper.
                Dialog.addMessage(
                    ">> " + refLengthMm + " mm = " + d2s(pixelLength, 1) + " px\n" +
                    d2s(pxPerMm, 3) + " px/mm\n" +
                    "(1 px = " + d2s(micronPerPx, 2) + " um)\n" +
                    "100 px = " + d2s(100 / pxPerMm, 3) + " mm  (excl. threshold: major < 100 px)\n\n" +
                    "Is this calibration acceptable?");
                Dialog.addRadioButtonGroup("",
                    newArray("OK - proceed",
                             "Redo - draw the line again",
                             "Change reference length"),
                    3, 1, "OK - proceed");
                Dialog.show();

                confirm = Dialog.getRadioButton();
                if (confirm == "OK - proceed") {
                    lineOK = 1;        // exit inner loop
                    calibrationOK = 1; // exit outer loop
                } else if (confirm == "Redo - draw the line again") {
                    continue;  // -> inner loop: back to waitForUser
                } else {
                    lineOK = -1;  // signal to exit inner loop for reference length change
                }
            }
        }
        
        // Reset custom length field to blank after each image
        // to prevent accidental carryover to the next image.
        lastRefOtherStr = "";


        // ========== Block 5: Label/scale bar removal ==========
        // Clear the line selection left over from scale calibration.
        run("Select None");
        // Explicitly set both background and foreground to white once per image.
        // This ensures that both "Fill" and "Clear" operations produce white,
        // guaranteeing consistency regardless of how the operation is interpreted.
        setBackgroundColor(255, 255, 255);
        setForegroundColor(255, 255, 255);
        setTool("rectangle");

        selectionDone = 0;
        selectionCount = 0;
        // Snapshot stack: stores image IDs of pre-fill duplicates.
        // Allows multiple-level Undo (one Redo per fill).
        snapshotIDs = newArray(0);

        while (selectionDone == 0) {
            waitForUser("Remove Label and Scale Bar",
                "Exclude unnecessary objects (labels, scale bars, etc.).\n\n" +
                "1. Enclose the object with Rectangle, Polygon, or Freehand tool.\n" +
                "2. Click OK to fill with white.\n\n" +
                "Image: " + fname);

            type = selectionType();
            // Valid types: 0=Rectangle, 2=Polygon, 3=Freehand
            // (Oval excluded intentionally)

            // Pattern C: Invalid selection tool used
            // -> show error and loop back to waitForUser (no "Continue?" dialog)
            if (type != -1 && type != 0 && type != 2 && type != 3) {
                showMessage("Error",
                    "Invalid selection type.\n" +
                    "Please use Rectangle, Polygon, or Freehand tool.\n" +
                    "Try again.");
                continue;
            }

            // Pattern A: Valid selection -> fill with white
            if (type == 0 || type == 2 || type == 3) {
                // Save snapshot BEFORE fill (for multi-level Redo).
                // "Select None" is called first so that Duplicate copies
                // the ENTIRE image, not just the selected region.
                // "Restore Selection" then recovers the selection for Fill.
                currentID = getImageID();
                run("Select None");
                run("Duplicate...", "title=snap_" + d2s(selectionCount + 1, 0));
                snapID = getImageID();
                setLocation(-9999, 0);  // Move snapshot window off-screen (avoids workspace clutter)
                snapshotIDs = Array.concat(snapshotIDs, snapID);
                selectImage(currentID);

                // Restore the selection and fill
                run("Restore Selection");
                run("Fill", "slice");
                run("Select None");
                selectionCount++;
                print("    Filled selection " + selectionCount);

                // Pattern A: 3-choice dialog (Redo available after fill)
                Dialog.create("Continue?");
                Dialog.addMessage("Finish object exclusion and proceed to binarization?");
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

                    // Guard: verify snapshot still exists
                    if (!isOpen(lastSnapID)) {
                        showMessage("Redo unavailable",
                            "The snapshot image is no longer available.\n" +
                            "Redo cannot be performed.");
                        continue;  // -> waitForUser: notify user and let them re-select
                    } else {
                        currentTitle = getTitle();
                        currentID = getImageID();

                        // Save working window position before closing
                        // so the restored snapshot can appear in the same place.
                        getLocationAndSize(wrkX, wrkY, wrkW, wrkH);

                        // Step 1: Rename snapshot FIRST (before closing working image)
                        //         to ensure an active image always exists.
                        selectImage(lastSnapID);
                        rename(currentTitle);

                        // Step 2: Close the current (filled) working image
                        selectImage(currentID);
                        close();

                        // Step 3: Bring the snapshot (now working image) to front
                        //         and move it on-screen to the saved position.
                        selectImage(lastSnapID);
                        setLocation(wrkX, wrkY);

                        // Remove from snapshot stack
                        snapshotIDs = Array.trim(snapshotIDs, snapshotIDs.length - 1);
                        selectionCount--;
                        print("    Redo: restored to state before fill " +
                              (selectionCount + 1));
                        continue;  // -> back to waitForUser
                    }
                }
                // "No" -> selectionDone remains 0 -> loop continues

            } else {
                // Pattern B: No selection (type == -1) -> 2-choice dialog (no Redo needed)
                Dialog.create("Continue?");
                Dialog.addMessage("Finish object exclusion and proceed to binarization?");
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

        // Clean up any remaining snapshots (no longer needed after Block 5)
        for (k = 0; k < snapshotIDs.length; k++) {
            if (isOpen(snapshotIDs[k])) {
                selectImage(snapshotIDs[k]);
                close();
            }
        }


        // ========== Block 6: Binarization (Otsu) + PNG save ==========

        // Convert to 8-bit if needed
        if (bitDepth() != 8) {
            run("8-bit");
        }

        // Otsu auto threshold (dark particles on bright background)
        setAutoThreshold("Otsu dark");
        run("Convert to Mask");

        // Save as PNG
        dotIndex = lastIndexOf(fname, ".");
        baseName = substring(fname, 0, dotIndex);
        pngName = baseName + ".png";
        pngPath = layerOutputDir + pngName;
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


        // ========== Block 8: Per-particle processing ==========

        validInFile = 0;
        for (j = 0; j < n; j++) {
            major = getResult("Major", j);
            minor = getResult("Minor", j);
            ari = getResult("AR", j);
            ci = getResult("Circ.", j);
            area = getResult("Area", j);
            perim = getResult("Perim.", j);
            feret = getResult("Feret", j);
            minFeret = getResult("MinFeret", j);

            // Filtering (consistent with R_calculator.ijm)
            if (major < 100) {
                layerExcludedMajorCount++;
                continue;
            }
            if (ari > 10) {
                layerExcludedARCount++;
                continue;
            }

            // Diameter calculation (mm unit)
            D_arith_mm = (major + minor) / (2 * pxPerMm);
            D_geo_mm = sqrt(major * minor) / pxPerMm;
            D_Feret_min_mm = minFeret / pxPerMm;
            D_Feret_max_mm = feret / pxPerMm;

            // R value calculation
            car = 0.826261 + 0.337479*ari - 0.335455*pow(ari,2) +
                  0.103642*pow(ari,3) - 0.0155562*pow(ari,4) +
                  0.00114582*pow(ari,5) - 0.0000330834*pow(ari,6);
            r = ci + (0.913 - car);

            validInFile++;
            layerTotalValid++;
            totalValidGlobal++;

            // Write to CSV
            // All numeric values formatted with d2s() for consistency
            print(layerFileOut,
                layerLabel + "," + fname + "," + validInFile + "," +
                d2s(pxPerMm, 4) + "," +
                d2s(area, 2) + "," + d2s(perim, 4) + "," +
                d2s(major, 4) + "," + d2s(minor, 4) + "," +
                d2s(D_arith_mm, 4) + "," + d2s(D_geo_mm, 4) + "," +
                d2s(D_Feret_min_mm, 4) + "," + d2s(D_Feret_max_mm, 4) + "," +
                d2s(ari, 4) + "," + d2s(r, 6)
            );
        }

        print("    Valid: " + validInFile + " particles");
        close();
    }

    // Close layer CSV
    File.close(layerFileOut);

    totalDetectedGlobal += layerTotalDetected;

    // Record end-of-sample timestamp (computed here so each sample gets its own
    // completion time, not the macro start time).
    // Note: getDateAndTime() returns month as 0-based (Jan=0), so +1 is required.
    // Zero-padding uses if/else; IJ.pad() and ternary operator (?:) are not reliably
    // available in macro language.
    getDateAndTime(ts_year, ts_month, ts_dow, ts_day, ts_hour, ts_min, ts_sec, ts_msec);
    ts_mm  = ts_month + 1;
    if (ts_mm < 10) { ts_mm_s = "0" + d2s(ts_mm, 0); } else { ts_mm_s = d2s(ts_mm, 0); }
    if (ts_day < 10) { ts_dd_s = "0" + d2s(ts_day, 0); } else { ts_dd_s = d2s(ts_day, 0); }
    if (ts_hour < 10) { ts_hh_s = "0" + d2s(ts_hour, 0); } else { ts_hh_s = d2s(ts_hour, 0); }
    if (ts_min < 10) { ts_mi_s = "0" + d2s(ts_min, 0); } else { ts_mi_s = d2s(ts_min, 0); }
    layerTimestamp = d2s(ts_year, 0) + "/" + ts_mm_s + "/" + ts_dd_s + " " + ts_hh_s + ":" + ts_mi_s;

    // Accumulate summary row and label list here (string arrays not supported
    // reliably in newArray(); build strings directly instead).
    summaryNewRows = summaryNewRows + layerLabel + "," +
        layerExcludedMajorCount + "," + layerExcludedARCount + "," +
        layerTimestamp + "\n";
    if (layerLabelsList == "") {
        layerLabelsList = layerLabel;
    } else {
        layerLabelsList = layerLabelsList + "|" + layerLabel;
    }

    // Layer summary
    print("");
    print("Summary for '" + layerLabel + "':");
    print("  Detected        : " + layerTotalDetected);
    print("  Valid           : " + layerTotalValid);
    print("  Excl (major<100): " + layerExcludedMajorCount);
    print("  Excl (AR>10)    : " + layerExcludedARCount);
    print("");
}


// ========== Block 9: Summary CSV ==========
// Append mode: preserve rows from previous runs.
// Header is written only when the file does not yet exist.
// File.saveString() overwrites the file in one shot with all accumulated content.

summaryPath = outputDir + "Particle_R_Summary.csv";
summaryExists = File.exists(summaryPath);

// summaryNewRows was accumulated in Block 3 (one row per sample processed).
// Prepend header if first write; otherwise read existing content and append.
if (summaryExists == 0) {
    finalContent = "FolderName,ExcludedMajor,ExcludedAR,RunTimestamp\n" + summaryNewRows;
} else {
    existingContent = File.openAsString(summaryPath);
    finalContent = existingContent + summaryNewRows;
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
print("R_Lab Analysis Complete");
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

showMessage("R_Lab Analysis Complete",
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



// Populates verNames[] with all existing version names for sampleLabel.
// Checks base name, then _v2, _v3, ... sequentially (breaks on first gap).
// Returns the count of versions found.
function getVersionNames(sampleLabel, verNames) {
    count = 0;
    if (File.isDirectory(outputDir + sampleLabel) ||
        File.exists(outputDir + "Particle_R_" + sampleLabel + ".csv")) {
        verNames[count] = sampleLabel;
        count++;
    }
    for (v = 2; v <= 50; v++) {
        // Guard: stop if count would exceed array bounds.
        // verNames.length is set by the caller (52); leave last slot as safety margin.
        if (count >= verNames.length - 1) {
            v = 51;  // exit loop
        } else {
            vName = sampleLabel + "_v" + d2s(v, 0);
            if (File.isDirectory(outputDir + vName) ||
                File.exists(outputDir + "Particle_R_" + vName + ".csv")) {
                verNames[count] = vName;
                count++;
            } else {
                v = 51;  // no more versions; exit loop
            }
        }
    }
    return count;
}



// Deletes the PNG subfolder and per-sample CSV for a given version name.
// sep: native path separator (passed explicitly because nativeSep is a
//      global variable that may not be reliably accessible inside functions).
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


