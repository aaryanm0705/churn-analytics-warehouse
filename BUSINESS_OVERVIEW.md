# Business Overview

## What This Project Is About

Imagine a company that sells software on a monthly subscription — like a streaming service, a project management tool, or a cloud storage provider. Every month, customers either stay and pay, or they leave. When a customer leaves, that's called **churn**.

Churn is one of the most important problems a subscription business faces. Acquiring a new customer is almost always more expensive than keeping an existing one. When churn is high, the company is essentially pouring water into a leaky bucket — no matter how many new customers come in, revenue stagnates or shrinks.

This project takes the kind of data a subscription company generates every day — customer sign-ups, subscription plans, payment records, and product usage logs — and turns it into a clean, reliable foundation for understanding who is leaving, why they might be leaving, and what can be done about it.

---

## Where the Data Came From

The data used in this project is **synthetic**, meaning it was created to resemble what a real company's data would look like. It was not collected from actual customers.

This is a common and well-established practice. Companies routinely use synthetic data for internal analysis, testing, and training — especially when working with sensitive customer information isn't appropriate or necessary. The patterns in this data reflect realistic customer behaviour: people signing up on different dates, choosing different plans, paying in different ways, using the product at different intensities, and — in some cases — eventually leaving.

The dataset covers five areas of the business:
- **Customer profiles** — who signed up, when, where they're from, what plan they chose
- **Subscriptions** — when each subscription started and ended, and why some were cancelled
- **Payments** — how much was paid, when, and whether payments were on time
- **Product usage** — how often customers logged in, how long they used the product, and which features they engaged with
- **Churn records** — which customers ultimately left

Together, these five data sources paint a detailed picture of the customer lifecycle from sign-up to departure.

---

## Problems Hidden in the Raw Data

When data comes straight from business systems, it's rarely clean. Different tools, different teams, and different time periods all introduce inconsistencies. This project's raw data had the same kinds of problems you'd find in any real company:

- **Dates were written in multiple formats.** Some records used day-month-year, others used year-month-day, and some used slashes while others used dashes. A computer reading "01/02/2024" has no way to know if that means January 2nd or February 1st without clear rules.

- **Numbers were stored as text.** Payment amounts and usage counts looked like numbers to a human, but the system treated them as words — which means you couldn't add them up, average them, or compare them without first converting them properly.

- **Yes/no fields were recorded inconsistently.** One part of the system might store "true" while another stores "1" or "yes" or "Y" — all meaning the same thing, but requiring cleanup before analysis.

- **Country names and marketing channels appeared in different forms.** "Germany" in one record, "DE" in another, "de" in a third. Same meaning, different labels.

- **Some records were missing information entirely.** A payment without a date. A customer without a country. A subscription without an end date.

These aren't unusual problems — they're the reality of business data. But they make analysis unreliable if left unaddressed. A churn report built on messy data might overcount, undercount, or misattribute results in ways that quietly lead to bad decisions.

---

## What Was Done to Make the Data Reliable

The core of this project was transforming that messy raw data into something a business can trust.

Every record went through a cleaning process:
- **Dates were standardised** into a single, consistent format so that comparisons and timelines work correctly.
- **Numbers were validated and converted properly**, with anything unparseable flagged rather than silently included.
- **Yes/no fields were mapped to consistent labels**, so "true", "1", and "yes" all mean the same thing downstream.
- **Country names and channel labels were normalised** so that "Germany", "DE", and "de" all resolve to one value.
- **Missing data was handled explicitly** — marked as unknown rather than ignored or guessed.

The result is a single, reliable version of every customer, every subscription, every payment, and every day of product usage. When a question is asked of this data, the answer can be trusted because the foundation is clean.

Think of it like an accounting ledger. You wouldn't make financial decisions based on a spreadsheet where some amounts are in euros, some in dollars, and some are just blank. You'd standardise everything first. That's exactly what was done here.

---

## How Customer Churn Was Defined

In simple terms: a customer is considered **churned** if their subscription ended and they didn't come back within a reasonable window of time.

That window — a 30-day grace period — exists because not every lapse is permanent. A customer might forget to renew, have a payment issue, or take a short break. Counting them as lost immediately would overstate the problem. Waiting 30 days gives a more honest picture of who has genuinely left.

The churn determination was made by looking at each customer's most recent subscription. If that subscription ended more than 30 days before the analysis date, the customer is flagged as churned. If it's still active or ended recently, they're considered retained.

This approach mirrors how real subscription companies think about churn. It's conservative, defensible, and produces results that match business intuition.

---

## What Insights Were Produced

With clean data and a clear churn definition in place, the project produced several types of insight:

**Understanding who leaves and who stays.** Every customer now carries a clear churned-or-retained label. This makes it possible to compare the two groups across every dimension in the data — plan type, country, sign-up channel, payment behaviour, product usage patterns, and more.

**Comparing churn across business segments.** The analysis breaks churn down by subscription plan, by country, and by the marketing channel that originally brought the customer in. This reveals whether certain segments are systematically weaker than others — for example, whether customers acquired through one channel churn faster than those from another.

**Connecting behaviour to outcomes.** By combining payment history and product usage with churn status, the project surfaces behavioural patterns. Do customers who use the product less frequently leave sooner? Do late payments predict churn? These are the kinds of questions the data can now answer.

**Tracking business health over time.** Monthly revenue trends and usage engagement summaries show how the business is performing period over period — not just at a single point in time.

**Building a feature-rich customer profile.** Each customer now has a consolidated profile that captures tenure, subscription history, total spend, payment reliability, usage intensity, and more — all in one place. This kind of profile is exactly what's needed for deeper analysis or predictive modelling down the line.

---

## How a Real Company Could Use This

The outputs of this project aren't theoretical. They map directly to actions a business can take:

- **Identify high-risk customers early.** By understanding the traits and behaviours associated with churn, a company can flag at-risk customers before they leave — and intervene with targeted retention offers, outreach, or support.

- **Evaluate which plans and channels perform best.** If one subscription plan has significantly higher churn than others, that's a signal to investigate pricing, feature gaps, or expectation mismatches. If a marketing channel brings in customers who don't stick around, the acquisition strategy can be adjusted.

- **Improve retention strategy.** Rather than treating all customers the same, the business can focus retention spend on the segments and profiles where it will have the most impact.

- **Support predictive modelling.** The customer feature profiles produced here are designed to feed directly into predictive models — machine learning systems that can forecast which customers are most likely to churn in the coming weeks or months.

- **Make decisions with confidence.** When the underlying data is clean and the definitions are transparent, leadership can trust the numbers. That trust is the difference between "we think churn is around 20%" and "we know churn is 22.4% among enterprise customers in Germany, driven primarily by low product engagement."

---

## Why This Matters for Leadership

Customer churn has a direct impact on revenue, growth forecasts, and company valuation. Without a reliable way to measure and understand it, decisions are made on gut feeling or incomplete information.

This project provides:

- **Clarity** — a single, consistent definition of churn applied uniformly across all customers
- **Visibility** — breakdowns by plan, region, channel, and behaviour that reveal where problems are hiding
- **Confidence** — clean data with transparent methods, so the numbers can be defended in any boardroom or investor conversation
- **A foundation for action** — not just a report, but a structured dataset ready to support ongoing analysis, dashboards, and predictive tools

When leadership asks "why are we losing customers?", this project provides a credible, data-backed starting point for the answer.

---

## What This Project Demonstrates

- The ability to take messy, inconsistent business data and turn it into a reliable analytical foundation
- A clear, defensible approach to defining and measuring customer churn
- Focus on data quality, consistency, and reproducibility — not just producing numbers, but producing numbers that can be trusted
- Practical outputs designed for real business use: segmentation, trend analysis, risk identification, and feature engineering for predictive modelling
- The same methodology used by analytics teams at real subscription companies worldwide
