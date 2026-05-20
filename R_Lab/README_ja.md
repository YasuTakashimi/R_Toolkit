# R_Lab.ijm — 取扱説明書

*This document is written in Japanese. For the English version, see [README.md](README.md).*

**版：** 1.0（2026年）  
**著者：** 髙清水 康博（新潟大学 教育学部 地学教室）  
**ライセンス：** MIT License

---

## 目次

1. [R_Lab とは](#1-r_lab-とは)
2. [引用について](#2-引用について)
3. [動作環境](#3-動作環境)
4. [フォルダ構成](#4-フォルダ構成)
5. [撮影上の推奨事項](#5-撮影上の推奨事項)
6. [インストール](#6-インストール)
7. [使い方（手順）](#7-使い方手順)
8. [出力ファイルの説明](#8-出力ファイルの説明)
9. [計算式の説明](#9-計算式の説明)
10. [粒子の除外条件](#10-粒子の除外条件)
11. [再解析について](#11-再解析について)
12. [注意事項・制約](#12-注意事項制約)
13. [よくある質問（FAQ）](#13-よくある質問faq)
14. [ライセンス](#14-ライセンス)

---

## 1. R_Lab とは

R_Lab.ijm は，粒子（礫や砂粒子，粉体の工業製品，マイクロプラスチック，建築骨材としての採石，および鉄道のバラストなど）の光学写真，顕微鏡写真，およびスキャナ等によるデジタル画像から粒子の円磨度指標 *R* を半自動的に計算する ImageJ マクロです．

### 主な機能

- スケールキャリブレーション（ピクセル / mm の設定）
- 不要オブジェクト（ラベル，スケールバー，ゴミ等）の除去
- Otsu 法による自動二値化
- 粒子の自動検出と形状計測
- *R* 値・粒径・アスペクト比の CSV 出力
- 試料ごとの再解析・バージョン管理

### *R* 値とは

*R* は Takashimizu & Iiyoshi（2016）が提案した円磨度指標で，**アスペクト比（Aspect Ratio）で補正した真円度（Circularity）** です．従来の真円度指標が細長い粒子で過小評価になる問題を解消します．

---

## 2. 引用について

R_Lab.ijm を用いた研究を発表する際は，必ず以下の論文を引用してください：

> Takashimizu, Y. & Iiyoshi, M., 2016,  
> New parameter of roundness *R*: circularity corrected by aspect ratio.  
> *Progress in Earth and Planetary Science*, **3**, 2, pp. 1–16.  
> DOI: [10.1186/s40645-015-0078-x](https://doi.org/10.1186/s40645-015-0078-x)

---

## 3. 動作環境

| 項目 | 要件 |
|------|------|
| ソフトウェア | Fiji（ImageJ 2.x） |
| Java | Java 21 以上 |
| OS | Windows 10/11，macOS，Linux |

Fiji は [https://fiji.sc](https://fiji.sc) から無償で入手できます．

---

## 4. フォルダ構成

R_Lab を使用する前に，以下のフォルダ構成を準備してください：

```
任意のフォルダ（プロジェクトフォルダ）/
├── input_R_Lab/              ← 画像データを格納（名前は固定）
│   ├── SampleA/              ← 試料名フォルダ（任意の名前）
│   │   ├── image001.jpg
│   │   └── image002.jpg
│   └── SampleB/
│       └── image001.jpg
└── output_R_Lab/             ← 自動生成（名前は固定）
```

### フォルダ・ファイル名の規則

- `input_R_Lab` および `output_R_Lab` という名前は**変更できません**
- 試料名フォルダ・画像ファイル名に**カンマ（,）は使用できません**
- 試料名フォルダ名に `..`，`/`，`\` は使用できません
- 画像形式：JPG，JPEG，TIF，TIFF，BMP，PNG に対応

---

## 5. 撮影上の推奨事項

粒子の円磨度を正確に計測するためには，粒子のシルエットを明瞭に識別できる画像を用意することが重要です．**逆光（バックライト）での撮影**を推奨します．

- **室内で撮影する場合：** 透過原稿台の上に粒子を並べて撮影すると，輪郭をより明瞭に捉えることができます．
- **野外で撮影する場合：** 透明板の上に粒子を並べ，下から空を背景に撮影することで，粒子の輪郭をはっきりと得ることができます．

---

## 6. インストール

1. Fiji を起動します
2. `R_Lab.ijm` を Fiji のウィンドウにドラッグ＆ドロップします
3. スクリプトエディタが開きます
4. `Run` ボタンをクリックして実行します

または，メニューから `Plugins > Macros > Run...` で `R_Lab.ijm` を選択することもできます．

---

## 7. 使い方（手順）

### ステップ 1：起動・スプラッシュ画面

マクロを実行すると，著者情報・引用情報が表示されます．「OK」をクリックして進んでください．

---

### ステップ 2：`input_R_Lab` フォルダの選択

`input_R_Lab` フォルダを選択するダイアログが開きます．  
**フォルダ名が `input_R_Lab` でない場合はエラーになります．**

---

### ステップ 3：試料の選択（ダイアログ 1）

解析する試料を選択します．

```
┌──────────────────────────────────────┐
│ Select Samples to Analyze            │
│                                      │
│ Samples found:                       │
│   SampleA   [new]                    │
│   SampleB   [previous run found]     │
│                                      │
│ Analyze:                             │
│ ○ New only  ← デフォルト             │
│ ○ All                                │
│ ○ Individual                         │
└──────────────────────────────────────┘
```

| 選択肢 | 動作 |
|--------|------|
| **New only** | 過去に解析していない試料のみ選択（デフォルト） |
| **All** | 全試料を選択 |
| **Individual** | チェックボックスで個別に選択（ダイアログ 2 が開く） |

`[new]` は初回解析，`[previous run found]` は過去に解析済みの試料です．

---

### ステップ 3b：個別選択（Individual 選択時のみ）

Individual を選んだ場合，各試料のチェックボックスが表示されます．  
デフォルトでは `[new]` の試料のみチェックが入っています．

---

### ステップ 4：再解析モードの選択（解析済み試料がある場合のみ）

過去に解析済みの試料が選択されている場合に表示されます．

| 選択肢 | 動作 |
|--------|------|
| **Keep previous results (versioned re-run)** | 前回の結果を保持し，新しいバージョン（`_v2`，`_v3`…）として出力 |
| **Delete previous results** | 指定したバージョンを削除してから解析 |

「Delete」を選ぶと，試料ごとに削除するバージョンを選択するダイアログが開きます（デフォルトはすべて未選択 = 削除しない）．  
バージョン名の横には，そのバージョンの解析完了日時が表示されます．

---

### ステップ 5：スケールキャリブレーション（画像ごと）

各画像に対してスケールを設定します．

1. 基準長選択ダイアログが開きます（15, 12, 10, 5, 2, 1 cm またはカスタム入力）
2. 直線ツールで画像内のスケールバー上に線を引きます
3. 「Confirm Calibration」ダイアログで確認します  
   - `OK - proceed`：承認して次へ
   - `Redo - draw the line again`：線を引き直す
   - `Change reference length`：基準長を選び直す

> **注意：** カスタム入力には正の数値（cm単位）を入力してください．0，負の値，および文字列は受け付けません．

---

### ステップ 6：不要オブジェクトの除去（画像ごと）

スケールバー，ラベル，ゴミなど，計測対象の粒子以外の不要物を白塗りで除去します．

1. Rectangle，Polygon，または Freehand ツールで除去したい領域を囲みます
2. 「OK」をクリックすると白塗りされます
3. 次の選択肢が表示されます：
   - **Yes - proceed to binarization**：除去完了，二値化へ進む
   - **No - select another object**：続けて別の領域を除去する
   - **Redo - undo last fill and reselect**：直前の白塗りを取り消す

何も選択せずに OK を押した場合（選択なし）：
- **Yes - proceed to binarization**：除去なしで二値化へ進む
- **No - select another object**：選択をやり直す

---

### ステップ 7：自動処理（二値化 → 粒子検出 → *R* 計算）

以降は自動で実行されます：

1. **Otsu 法による自動二値化**
2. **二値化 PNG の保存**（`output_R_Lab/SampleA/` フォルダ内）
3. **Analyze Particles** による粒子検出
4. ***R* 値の計算**と CSV への書き込み

---

### ステップ 8：完了ダイアログ

全試料の処理が完了すると，検出粒子数・有効粒子数・除外率が表示されます．

---

## 8. 出力ファイルの説明

### フォルダ構成

```
output_R_Lab/
├── SampleA/                      ← 二値化 PNG（試料ごと）
│   ├── image001.png
│   └── image002.png
├── Particle_R_SampleA.csv        ← 粒子データ（試料ごと）
└── Particle_R_Summary.csv        ← 除外粒子数サマリー（全実行を累積）
```

再解析（Keep モード）の場合：

```
output_R_Lab/
├── SampleA/                      ← 初回
├── SampleA_v2/                   ← 2回目
├── Particle_R_SampleA.csv
├── Particle_R_SampleA_v2.csv
└── Particle_R_Summary.csv
```

---

### Particle_R_SampleA.csv の列構成

| 列名 | 内容 |
|------|------|
| FolderName | 試料フォルダ名 |
| FileName | 元画像ファイル名 |
| ParticleID | 有効粒子の通し番号（画像内） |
| Scale_pxPerMm | スケール（ピクセル / mm） |
| Area_px2 | 粒子面積（px²） |
| Perimeter_px | 粒子周長（px） |
| Major_px | 粒子シルエット画像を楕円近似した際の長軸長（px） |
| Minor_px | 粒子シルエット画像を楕円近似した際の短軸長（px） |
| D_arith_mm | 算術平均粒径（mm）= (長軸 + 短軸) / 2 |
| D_geo_mm | 幾何平均粒径（mm）= √(長軸 × 短軸) |
| D_Feret_min_mm | 最小フェレ径（mm） |
| D_Feret_max_mm | 最大フェレ径（mm） |
| AR_I | アスペクト比（長軸 / 短軸） |
| R | 円磨度指標 *R* |

---

### Particle_R_Summary.csv の列構成

| 列名 | 内容 |
|------|------|
| FolderName | 試料フォルダ名（バージョン含む） |
| ExcludedMajor | 長軸 < 100 px で除外された粒子数 |
| ExcludedAR | AR > 10 で除外された粒子数 |
| RunTimestamp | 試料の解析完了日時（yyyy/mm/dd hh:mm） |

このファイルは実行をまたいで**追記**されます．同じ試料を複数回解析した場合，行が追加されます．

---

## 9. 計算式の説明

Takashimizu & Iiyoshi（2016）に基づきます：

### 真円度（Circularity）

$$C_I = \frac{4\pi \cdot \text{Area}}{\text{Perimeter}^2}$$

### アスペクト比

$$AR_I = \frac{\text{Major}}{\text{Minor}}$$

### アスペクト比補正係数（6次多項式）

$$C_{AR} = 0.826261 + 0.337479 \cdot AR - 0.335455 \cdot AR^2 + 0.103642 \cdot AR^3 - 0.0155562 \cdot AR^4 + 0.00114582 \cdot AR^5 - 0.0000330834 \cdot AR^6$$

### 円磨度指標 R

$$R = C_I + (0.913 - C_{AR})$$

Krumbein (1941) の 0.1〜0.9 の粒子群は 0.7〜0.913 の範囲をとり（Takashimizu and Iiyoshi, 2016），小さな値ほど角張った粒子で，0.913 に近いほど良円磨粒子であることを意味します．

---

## 10. 粒子の除外条件

以下の条件に該当する粒子は計算対象から除外され，Summary CSV にカウントされます：

| 条件 | 理由 |
|------|------|
| 長軸 < 100 px | 画素化誤差が大きく，信頼性のある形状計測ができない．このことはまた，デジタル画像の粒子以外のバックグラウンドに小さな傷や粒子が画像中に含まれていても，全て除外されることを示しています．逆に長軸 > 100 px のものはすべて粒子と判断されます．スケールバーや大きな傷などはステップ 6 の行程で除去してください． |
| AR > 10 | 細長すぎて円磨度指標として意味をなさない |

> **推奨：** 長軸が 100 px 以上の粒子像が得られるよう，撮影倍率および解像度を設定してください．また，Confirm Calibration（較正の確認）ダイアログには参照値として「100 px = X mm」が表示されますので，目的とする粒径の粒子群が除外されていないかを確認する際の参考にしてください．

---

## 11. 再解析について

同じ試料を再解析する場合，2 つのモードを選べます：

### Keep モード（バージョン管理）

前回の出力を保持したまま，新しいバージョンとして出力します：

```
SampleA        → 初回
SampleA_v2     → 2 回目
SampleA_v3     → 3 回目
```

Summary CSV には各バージョンの行が追記されます（完了日時で区別可能）．

### Delete モード（削除して再解析）

指定したバージョンを削除してから再解析します．  
削除ダイアログでは全項目がデフォルトで未選択になっているため，誤削除のリスクを最小化しています．

> **注意：** Summary CSV の行は削除されません（解析履歴の記録として保持されます）．

---

## 12. 注意事項・制約

- フォルダ名・ファイル名に**カンマを含めることはできません**（CSV 出力が破損します）
- フォルダ名に `..`，`/`，`\` を含めることはできません
- 1 つの `input_R_Lab` フォルダ内に置ける試料フォルダは最大 **100 個**です
- 同一試料の再解析バージョンは最大 **50 個**（`_v2` 〜 `_v51`）まで管理されます
- スケールキャリブレーションのカスタム入力には正の数値を入力してください

---

## 13. よくある質問（FAQ）

**Q. 「The selected folder must be named 'input_R_Lab'」というエラーが出ます**  
A. `input_R_Lab` という名前のフォルダを選択してください．スペルが異なる場合は名前を修正してください．

**Q. 粒子が全く検出されません**  
A. スケールキャリブレーションの線が短すぎる（または別の場所に引かれている）可能性があります．また，画像が正しく二値化されているか，保存された PNG を確認してください．

**Q. Summary CSV に同じ試料名が複数行あります**  
A. 同じ試料を複数回解析した記録です（Keep モードまたは Delete 後の再解析）．RunTimestamp 列で実行を区別できます．

**Q. 大量の粒子が除外されます**  
A. Summary CSV の ExcludedMajor 列を確認してください．長軸 < 100 px の粒子が多い場合，撮影倍率を上げるか，解像度の高いスキャナを使用することを検討してください．

**Q. カスタムのスケール長を入力したらエラーになりました**  
A. 数値（例：`10.5`）を cm 単位で入力してください．0，負の値，および文字列は受け付けられません．

---

## 14. ライセンス

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

*このマクロの科学的設計および検証はすべて著者が行っています．AI コーディング支援（Claude，Anthropic）を開発に利用しています．*
