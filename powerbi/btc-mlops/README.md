# The pipeline dashboard, in Power BI

The report reads what the [MLOps pipeline](../../github/btc-mlops) produced. It
holds no invented number.

The project is stored as PBIP, which is folders of text rather than one binary
file. The semantic model is TMDL, and the report is PBIR. Both are readable in
a pull request, which a `.pbix` is not.

## What it shows

**Overview.** Five tiles across the top: hours the model wins, model error,
baseline error, hours scored, and the ML Test Score. Below them, predicted
against actual hour by hour, skill by hour of day, the price series, the split
between hours the model wins and loses, and the drift table.

**Quality.** The score by section, the numbers the pipeline reported, model
error against baseline error one point per hour, and feature importance.

## The data

Six CSV files in `data/`, written by the pipeline.

| File | One row per | Rows |
| --- | --- | --- |
| `hourly.csv` | Hour in the test window, with the forecast, the baseline and both errors | 1,494 |
| `price.csv` | Hour of BTCUSDT, close, volume and trades | 720 |
| `kpi.csv` | Measure the pipeline reported | 8 |
| `skill_by_hour.csv` | Hour of the day, with skill and the verdict | 24 |
| `drift.csv` | Feature, with its p-value, verdict and importance | 11 |
| `test_score.csv` | Section of the ML Test Score | 4 |

## How to open it

1. Open `btc-mlops.pbip` in Power BI Desktop, February 2024 or later, with the
   PBIP and TMDL preview features on.
2. Open **Transform data**, then **Manage parameters**.
3. Set `DataFolder` to the full path of the `data` folder on your machine.
4. Refresh.

The parameter exists so that no personal path enters the repository.

## The theme

`MLOpsDark.json`, in `StaticResources`. Dark navy page, tiles a shade lighter,
rounded borders, and one accent colour per meaning.

| Colour | Meaning |
| --- | --- |
| Blue `#5B8DEF` | The model |
| Orange `#F5A623` | The baseline it has to beat |
| Teal `#22C1A4` | A win |
| Red `#EF4B6B` | A loss |
| Purple `#9B6BE8` | Production readiness |

## Regenerating it

The folder is generated, not clicked together. The generator lives with the
pipeline, so the report and the data cannot drift apart.
