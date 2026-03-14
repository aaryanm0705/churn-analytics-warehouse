# Business Overview

## What This Project Models

A subscription software company — customers sign up for a plan, make monthly payments, use the product, and eventually either stay or leave. The data covers five areas: customer profiles, subscriptions, payments, daily product usage, and churn records.

**The data is fully synthetic.** It was generated to resemble real operational data, including the kinds of quality issues that make analysis harder: mixed date formats, numbers stored as text, inconsistent country labels, missing fields, and ambiguous boolean values. Handling those problems is a core part of what this project demonstrates.

---

## The Data Problems

Raw data from business systems is rarely clean. This dataset had:

- Dates in multiple formats (`DD/MM/YYYY`, `YYYY-MM-DD`, `MM-DD-YYYY`) — including ambiguous cases where day and month are indistinguishable
- Payment amounts stored as text — couldn't be summed or averaged without conversion
- Boolean fields with mixed representations (`true`, `1`, `yes`, `Y`) across different source systems
- Country names and channel labels in multiple forms (`Germany`, `DE`, `de`)
- ~300 subscription rows where `end_date < start_date` — swapped dates in the raw data, nulled out in core

Each was handled explicitly in the staging layer. Nothing was silently dropped or guessed.

---

## Churn Definition

A customer is churned if their most recent subscription ended more than 30 days before the analysis date.

The 30-day grace period accounts for payment lapses and short breaks — counting every lapsed subscription as permanent churn overstates the problem. The analysis date defaults to `MAX(end_date_clean)` across the dataset so results are always relative to the data loaded, not a hardcoded date.

---

## Key Findings

These are results from the actual data, not hypothetical outputs:

- **77.4% overall churn rate** — 15,471 of 20,000 customers churned
- **Churned customers paid more** — avg monthly fee $23.53 vs $14.64 for retained customers, suggesting price sensitivity is a churn driver
- **Churn is uniform across all acquisition channels** (~77% for Google, Instagram, LinkedIn, and other) — churn is a product or pricing problem, not an acquisition problem
- **Churn is uniform across all countries** — no geographic concentration, ruling out regional factors
- **Cancellation reasons are evenly split** across competition, high price, low usage, technical issues, and other — no single dominant reason, which points to a broad retention problem rather than one fixable issue
- **Monthly revenue is volatile** — ranging from $240K to $280K with no clear trend, consistent with high churn offsetting new customer revenue
- **Monthly active users hold steady around 18K–19K** with a sharp February dip worth investigating
