create schema if not exists raw;
create schema if not exists staging;
create schema if not exists core;
create schema if not exists analytics;

alter table public.customers set schema raw;
alter table public.subscriptions set schema raw;
alter table public.usage set schema raw;
alter table public.payments set schema raw;
alter table public.churn_labels set schema raw;

