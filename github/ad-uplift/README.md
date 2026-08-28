# Paid advertising uplift: who is worth bidding on

An advertiser holds one budget and bids on a population. A response model finds
who converts. An uplift model finds who converts **because of** the ad. They are
different people, and the gap between them is the budget.

CRISP-DM carries the order. The data is CRITEO-UPLIFTv2, a randomised trial in
real-time bidding, which is the mechanism behind Meta Ads and Google Ads.

**Project page:** https://rafaeltavares98.github.io/ad-uplift.html

This is the third portfolio project and the first in Python. The two before it
are SQL: [fundamentals and EDA](https://rafaeltavares98.github.io/sql-eda.html),
then [window functions and CRISP-DM](https://rafaeltavares98.github.io/avocado-price-analysis.html).

## The finding

The ad lifts conversions by 58%, so the naive rule is to bid on everybody. That
is true and useless.

| Share of the population targeted | Incremental conversions captured | Against random |
| --- | --- | --- |
| Top 5% | 46.1% | 9.2x |
| **Top 10%** | **65.6%** | **6.6x** |
| Top 40% | 88.0% | 2.2x |
| Everybody | 100% | 1.0x |

A tenth of the population carries two thirds of every conversion the ad caused.
The other nine tenths spend the budget on sales that were coming anyway.

## The five things this project applies

| Item | Where |
| --- | --- |
| CRISP-DM | The order of the notebook, six phases |
| SLI and SLO | Phase 1 states both. Phase 5 returns the verdict |
| Three ML models | Phase 4 |
| Cross-validation | Phase 4, 5 folds, stratified by group and outcome |
| A/B test | Phase 5, on the randomised assignment |

## The SLI and the SLO

Phase 1 names what gets measured and what counts as good enough, before the
first model runs.

* **SLI.** The Qini coefficient, measured on users held out of training.
* **SLO.** Qini above zero, and the top decile above the population average, in
  every fold.

Phase 5 returns the verdict.

| Fold | Qini | Uplift, top decile | Uplift, overall | Verdict |
| --- | --- | --- | --- | --- |
| 1 | 0.0887 | 6.53pp | 1.09pp | pass |
| 2 | 0.0872 | 6.04pp | 1.09pp | pass |
| 3 | 0.0850 | 5.68pp | 1.09pp | pass |
| 4 | 0.0866 | 5.17pp | 1.09pp | pass |
| 5 | 0.0761 | 5.96pp | 1.09pp | pass |

The scores come from phase 4. Every row is ranked by a model that never saw it,
and nothing is refitted to produce this table.

## The models

Three families. The first is the baseline, and anything that cannot beat it is
not worth shipping.

| Model | Mean Qini | Spread | Worst fold |
| --- | --- | --- | --- |
| **LightGBM, treatment dummy** | **0.0847** | 0.0050 | 0.0761 |
| Logistic regression, treatment dummy | 0.0765 | 0.0032 | 0.0710 |
| Two-model LightGBM | 0.0717 | 0.0046 | 0.0661 |

The two-model approach is the one the field reaches for, and it comes last. It
fits one classifier per group and subtracts them. Each one spends its capacity
on predicting visits, and the small difference between them carries the error of
both.

Tree parameters are chosen inside a nested loop, on the training fold only. A
search that reads the fold it reports on inflates the number it reports.

## The A/B test

| Metric | Treated | Control | Lift | 95% interval | Detectable minimum |
| --- | --- | --- | --- | --- | --- |
| Visit | 4.935% | 3.841% | +1.09pp | 1.00 to 1.19pp | 0.128pp |
| Conversion | 0.320% | 0.202% | +0.12pp | 0.10 to 0.14pp | 0.030pp |

Both intervals exclude zero, and each effect is several times the minimum this
sample can detect. The randomisation is what makes these causal statements
rather than correlations.

## The data

CRITEO-UPLIFTv2, from the Criteo AI Lab. The rows come from incrementality
tests, a randomised trial where a random part of the population is prevented
from being targeted by advertising.

| Property | Value |
| --- | --- |
| Source rows | 13,979,592 |
| Sample used | 1,397,959, a deterministic 10% |
| After duplicates leave | 1,375,782 |
| Features | `f0` to `f11`, dense, float, anonymised |
| Treatment | Entered the auction for this user. 85% of rows |
| Exposure | Won the auction. Not randomised, so it stays out of the model |
| Outcomes | `visit` 4.7%, `conversion` 0.3% |

Source: https://ailab.criteo.com/criteo-uplift-prediction-dataset/

The notebook downloads the file, draws the sample one chunk at a time, and
caches it. Neither file enters this repository.

## What the checks find

Six rules pass. One fails.

| Rule | Result |
| --- | --- |
| No null in any column | pass |
| No duplicate row | **FAIL**, 22,177 rows |
| Treatment is binary | pass |
| Control is never exposed | pass |
| Conversion implies visit | pass |
| Balance under 0.10 standardised difference | pass, largest is 0.0497 |
| Propensity AUC under 0.55 | pass, 0.5114 |

The features are dense and anonymous, so a profile that repeats is the same
twelve numbers arriving twice. 7,549 of those profiles sit in both groups, and
that is what makes them a problem: the same numbers land in the training fold
and in the fold that scores it.

The propensity check is the one that licenses every causal claim. A model that
cannot predict who was treated confirms that nothing but chance decided it.

## How to run it

Python 3.12.

```bash
pip install -r requirements.txt
jupyter notebook notebook.ipynb
```

The first run downloads 297 MB and draws the sample. The modelling itself takes
10 minutes on eight cores. A later run reads the cached sample.

## The files

| File | What it holds |
| --- | --- |
| `notebook.ipynb` | The six phases, one section each, with the output that ran |
| `requirements.txt` | Pinned versions |

The notebook writes `results/` on every run: one CSV per table, plus the Qini
curve. The project page is built from those files, so the page and the notebook
cannot drift.

## The references

| Work | What it gives |
| --- | --- |
| Diemert, Betlei, Renaudin and Amini, *A Large Scale Benchmark for Uplift Modeling*, AdKDD at KDD 2018, extended as arXiv:2111.10106 | The data set, the sanity checks, and the task formalism |
| Rößler and Schoder, *Bridging the Gap*, Journal of Interactive Marketing, 2022 | The protocol for comparing methods on one data set |
| Gutierrez and Gérardy, *Causal Inference and Uplift Modelling*, PMLR, 2017 | The two-model formulation and the Qini vocabulary |
| Betlei, *Uplift Modeling for Online Advertising*, thesis, Université Grenoble Alpes, 2021 | The advertising case, and the chapter behind this data set |

Radcliffe's 2008 entry that won the Hillstrom challenge is the background. He
used bagged uplift trees, one 50% split, and resampling in place of a
significance test. This notebook closes that gap with cross-validation and a
stated A/B test.
