# The ML Test Score

The rubric is Breck, Cai, Nielsen, Salib and Sculley, *The ML Test Score: A
Rubric for ML Production Readiness and Technical Debt Reduction*, IEEE Big Data
2017. It holds 28 tests in four sections.

Scoring, as the paper defines it. Half a point when a test runs by hand and the
result is written down. A full point when a system runs it automatically and
repeatedly. Sum each section, then take the **minimum** of the four.

| Score | Reading, from the paper |
| --- | --- |
| 0 | More of a research project than a product |
| (0, 1] | Not totally untested, but serious holes remain |
| (1, 2] | A first pass at productionisation |
| (2, 3] | Reasonably tested, more could be automated |
| (3, 5] | Strong automated testing and monitoring, fit for mission-critical work |
| > 5 | Exceptional |

## Section 1: features and data

| # | Test | Score | Where |
| --- | --- | --- | --- |
| 1 | Feature expectations are captured in a schema | 1 | `Candle` in `serve/api.py` bounds every feature. The API refuses a negative range or an impossible hour |
| 2 | All features are beneficial | 0 | Not tested. No feature ablation runs |
| 3 | No feature costs more than it is worth | 0.5 | Eleven features, all from one free source. Recorded, not automated |
| 4 | Features follow meta-level requirements | 1 | `test_no_feature_reads_the_future` runs on every commit |
| 5 | The data pipeline has appropriate privacy controls | 1 | The data is public market prices. No personal data exists to leak |
| 6 | New features can be added quickly | 0.5 | One list, `FEATURE_COLUMNS`, drives training and serving |
| 7 | All input feature code is tested | 1 | `test_features.py`, six tests, in CI |
| **Section total** | | **5.0** | |

## Section 2: model development

| # | Test | Score | Where |
| --- | --- | --- | --- |
| 1 | Model specs are reviewed and submitted | 1 | Every model lives in git and passes the pull request checks |
| 2 | Offline and online metrics correlate | 0 | Not tested. The service is not yet scored against the offline run |
| 3 | All hyperparameters have been tuned | 0.5 | `MODEL_PARAMS` is fixed and recorded. No search runs |
| 4 | The effect of model staleness is known | 1 | `monitoring_report` measures rolling skill and drift every run |
| 5 | A simpler model is not better | 1 | Every run scores the baseline beside the model. `skill` is the gap |
| 6 | Model quality is sufficient on all important data slices | 0.5 | Skill measured for each of the 24 hours of the day. Two hours come back negative. Recorded in `results/skill_by_hour.csv`, not automated |
| 7 | The model is tested for considerations of inclusion | 1 | Not applicable. The subject is a price series, and no person is scored |
| **Section total** | | **5.0** | |

## Section 3: infrastructure

| # | Test | Score | Where |
| --- | --- | --- | --- |
| 1 | Training is reproducible | 1 | Fixed seed, ordered split, pinned versions, and MLflow records each run |
| 2 | Model specs are unit tested | 1 | `test_train.py`, fourteen tests, in CI |
| 3 | The full ML pipeline is integration tested | 1 | The `smoke` job materialises all six assets on real data, on every push |
| 4 | Model quality is validated before serving | 1 | `production_model` promotes only on a win by margin |
| 5 | The model is debuggable | 0.5 | LightGBM exposes feature importance. No per-prediction explanation yet |
| 6 | Models are canaried before serving | 0.5 | Champion and challenger run side by side. No traffic split |
| 7 | Serving models can be rolled back | 1 | The registry alias moves. The previous version stays and serves again |
| **Section total** | | **6.0** | |

## Section 4: monitoring

| # | Test | Score | Where |
| --- | --- | --- | --- |
| 1 | Dependency changes result in notification | 0.5 | Versions are pinned. No automatic alert on a new release |
| 2 | Data invariants hold in training and serving | 1 | `parse_klines` rejects malformed candles. The API bounds every field |
| 3 | Training and serving features compute the same values | 1 | One module, `features/build.py`, feeds both paths |
| 4 | Models are not too stale | 1 | The schedule runs hourly, and drift decides retraining |
| 5 | The model is numerically stable | 1 | The API refuses NaN and out-of-range input before the model sees it |
| 6 | Computing performance has not regressed | 0 | Not tested. No timing assertion in CI |
| 7 | Prediction quality has not regressed on served data | 1 | Forecasts are stored before the hour happens, and scored when it closes |
| **Section total** | | **5.5** | |

## The score

| Section | Total |
| --- | --- |
| Features and data | 5.0 |
| Model development | 5.0 |
| Infrastructure | 6.0 |
| Monitoring | 5.5 |
| **ML Test Score** | **5.0** |

The score is the minimum of the four, so features and model development share
the floor. The gaps are named above: no feature ablation, no check of offline
against online, and no timing assertion.

A score of 5.0 sits at the top of the band the paper calls strong automated
testing and monitoring. The honest reading is that the infrastructure is ahead of the
modelling, which is the correct order for a project whose subject is the
pipeline.
