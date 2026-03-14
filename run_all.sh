#!/usr/bin/env bash
# =============================================================================
# run_all.sh — Build the entire churn analytics warehouse from scratch
# =============================================================================
#
# Prerequisites:
#   1. PostgreSQL is running and accessible
#   2. Raw CSV files have been imported into public.* tables
#   3. psql is available on your PATH
#
# Usage:
#   ./run_all.sh                          # uses defaults (localhost:5432/churn_db)
#   ./run_all.sh -h myhost -p 5433 -d mydb -U myuser
#
# The script runs all SQL files in dependency order and reports success/failure
# for each step. If any step fails, the script stops immediately.
# =============================================================================

set -euo pipefail

# ── Defaults (override with flags) ──────────────────────────────────────────
DB_HOST="${PGHOST:-localhost}"
DB_PORT="${PGPORT:-5432}"
DB_NAME="${PGDATABASE:-churn_db}"
DB_USER="${PGUSER:-postgres}"

# ── Parse flags ─────────────────────────────────────────────────────────────
while getopts "h:p:d:U:" opt; do
    case $opt in
        h) DB_HOST="$OPTARG" ;;
        p) DB_PORT="$OPTARG" ;;
        d) DB_NAME="$OPTARG" ;;
        U) DB_USER="$OPTARG" ;;
        *) echo "Usage: $0 [-h host] [-p port] [-d database] [-U user]"; exit 1 ;;
    esac
done

PSQL="psql -h $DB_HOST -p $DB_PORT -d $DB_NAME -U $DB_USER -v ON_ERROR_STOP=1"

# ── Resolve script directory ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="$SCRIPT_DIR/sql"

# ── Colour helpers ──────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No colour

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }
header() { echo -e "\n${CYAN}── $1 ──${NC}"; }

# ── Build steps ─────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo " Churn Analytics Warehouse — Full Build"
echo "========================================"
echo " Host: $DB_HOST:$DB_PORT  DB: $DB_NAME  User: $DB_USER"

# Step 1: Setup schemas
header "Step 1/8: Setup schemas"
$PSQL -f "$SQL_DIR/setup/setup_database_schemas.sql" > /dev/null 2>&1 \
    && pass "Schemas created, raw tables moved" \
    || fail "setup_database_schemas.sql"

# Step 2: Staging views
header "Step 2/8: Staging views"
for view in customers_clean subscriptions_clean payments_clean usage_clean churn_labels_clean; do
    $PSQL -f "$SQL_DIR/staging/${view}.sql" > /dev/null 2>&1 \
        && pass "$view" \
        || fail "$view"
done

# Step 3: Churn labels (must run before dim_customer)
header "Step 3/8: Analytics — churn labels"
$PSQL -f "$SQL_DIR/analytics/01_churn_labels.sql" > /dev/null 2>&1 \
    && pass "analytics.churn_labels" \
    || fail "01_churn_labels.sql"

# Step 4: Customer dimension
header "Step 4/8: Core — dim_customer"
$PSQL -f "$SQL_DIR/core/01_dim_customer.sql" > /dev/null 2>&1 \
    && pass "core.dim_customer" \
    || fail "01_dim_customer.sql"

# Step 5: Fact tables
header "Step 5/8: Core — fact tables"
for fact in 02_fact_payments 03_fact_subscriptions 04_fact_usage_daily; do
    $PSQL -f "$SQL_DIR/core/${fact}.sql" > /dev/null 2>&1 \
        && pass "$fact" \
        || fail "$fact"
done

# Step 6: Customer features
header "Step 6/8: Analytics — customer features"
$PSQL -f "$SQL_DIR/analytics/02_customer_features.sql" > /dev/null 2>&1 \
    && pass "analytics.customer_features" \
    || fail "02_customer_features.sql"

# Step 7: KPI tables
header "Step 7/8: Analytics — KPI tables"
$PSQL -f "$SQL_DIR/analytics/03_kpi_views.sql" > /dev/null 2>&1 \
    && pass "analytics.kpi_views" \
    || fail "03_kpi_views.sql"

# Step 8: Validation suite
header "Step 8/8: Validation suite"
echo ""
$PSQL -f "$SQL_DIR/validation/validation_suite.sql" \
    && pass "All validation checks complete" \
    || fail "validation_suite.sql"

echo ""
echo "========================================"
echo -e " ${GREEN}Build complete!${NC}"
echo "========================================"
echo ""
