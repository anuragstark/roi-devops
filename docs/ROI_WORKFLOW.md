# ROI Workflow Documentation

## Overview
This document describes the complete ROI (Return on Investment) workflow in the platform, from investment creation to periodic ROI crediting.

---

## 1. Investment Creation Flow

### User Purchase Process
1. **User selects a plan** (`/app/investments`)
   - Plans have currency requirements (INR or USDT)
   - Plans can be fixed amount or flexible (with min/max limits)
   - Each plan has:
     - `roiRatePctPerCycle`: ROI percentage per cycle
     - `frequency`: daily/weekly/monthly
     - `durationDays`: Total investment duration
     - `currency`: Required currency (INR or USDT)

2. **Purchase validation** (`backend/src/routes/investments.ts`)
   - Validates plan exists and is active
   - Checks user has sufficient balance in the **required currency** (no auto-conversion)
   - Validates amount against min/max limits for flexible plans

3. **Investment creation** (Transaction)
   - **Debits** user's wallet (INR or USDT based on plan currency)
   - **Creates** investment record with:
     - `amount`: Investment amount
     - `currency`: Plan's currency
     - `status`: 'active'
     - `startDate`: Current date
     - `maturityDate`: startDate + durationDays
     - `totalRoiEarned`: 0 (initialized)

4. **Post-investment actions** (Outside transaction, best-effort)
   - **Referral income**: Credits referrer(s) based on referral levels
   - **Salary qualification**: Checks if investment qualifies user for salary program
   - **Breakdown entry**: Creates 20% deduction entry (80% to breakdown wallet)
   - **ROI boost check**: Checks if user qualifies for ROI boost (50+ referrals)

---

## 2. ROI Boost System

### ROI Boost Activation
- **Trigger**: User reaches referral threshold (e.g., 50+ referrals)
- **Process** (`backend/src/services/roiBoost.ts`):
  1. Checks active ROI boost rules
  2. Counts user's total referrals
  3. Finds applicable rule (highest threshold met)
  4. Creates `RoiBoost` record with:
     - `boostPct`: Additional ROI percentage
     - `status`: 'active'
     - `startDate`: Current date
     - `endDate`: Optional expiration date

### ROI Boost Application
- Applied during ROI credit calculation
- Formula: `totalRoi = baseRoi + (baseRoi * boostPct / 100)`
- Example: If base ROI is 10% and boost is 2%, effective ROI = 12%

---

## 3. ROI Credit Process

### Cron Job Execution
- **Schedule**: Runs every hour (configurable via `CRON_SCHEDULE` env var)
- **File**: `backend/src/scripts/cron-roi.ts`
- **Function**: `processRoiCredits()` from `backend/src/services/roiCredit.ts`

### Credit Eligibility Check
For each active investment, the system checks:
1. **Status**: Investment must be 'active'
2. **Maturity**: `maturityDate > now` (not matured yet)
3. **Due date**: Based on `frequency`:
   - **Daily**: At least 1 day since last credit (or start date)
   - **Weekly**: At least 7 days since last credit
   - **Monthly**: At least 30 days since last credit

### ROI Credit Calculation
For each eligible investment:

1. **Base ROI calculation**:
   ```
   baseRoi = (investmentAmount * roiRatePctPerCycle) / 100
   ```

2. **ROI boost application** (if user has active boost):
   ```
   boostAmount = baseRoi * boostPct / 100
   totalRoi = baseRoi + boostAmount
   ```

3. **Cycle number**: Increments from last credit cycle (prevents double-crediting)

### Credit Transaction (Serializable Isolation)
All operations happen in a single transaction to prevent race conditions:

1. **Lock investment** (compare-and-swap on `lastRoiCreditAt`):
   - Prevents double-credit if cron overlaps
   - Updates `lastRoiCreditAt` to current time
   - Increments `totalRoiEarned` atomically

2. **Credit ROI wallet**:
   - Upserts user's ROI wallet (creates if doesn't exist)
   - Atomically increments balance using Prisma's `increment`

3. **Create ledger entry**:
   - Records credit transaction
   - `referenceType`: 'ROI_CREDIT'
   - `referenceId`: `investment-{id}-cycle-{number}`

4. **Create ROI credit record**:
   - Stores credit history in `RoiCredit` table
   - Links to investment and user
   - Tracks cycle number and currency

### User Notification
After successful credit:
- Creates in-app notification
- Sends email notification (if configured)
- Includes: amount, currency, cycle number, investment ID

---

## 4. Investment Maturity

### Automatic Maturity Handling
When an investment reaches `maturityDate`:

1. **Status update**: Investment status changes to 'completed'
2. **Notification**: User receives notification about investment completion
3. **No principal return**: Principal is NOT automatically returned (different from some platforms)

**Note**: Principal remains in the platform. Users can withdraw it separately via withdrawal requests.

---

## 5. Data Models

### Key Tables

**RoiPlan**
- Defines investment plans with ROI rates, frequencies, and currency requirements

**Investment**
- Stores user investments
- Tracks: amount, currency, status, dates, total ROI earned

**RoiCredit**
- Historical record of each ROI credit
- Tracks: amount, currency, cycle number, credit date
- Unique constraint: `(investmentId, cycleNumber)` prevents duplicate credits

**RoiBoost**
- Active ROI boosts for users
- Tracks: boost percentage, status, expiration

**Wallet** (type: 'ROI')
- Separate wallet type for ROI earnings
- Users can withdraw from ROI wallet separately

**LedgerEntry**
- Complete audit trail of all wallet transactions
- Tracks: credits, debits, balances, references

---

## 6. Safety Features

### Financial Safety Mechanisms

1. **Serializable Transactions**: All ROI credits use highest isolation level
2. **Atomic Operations**: Wallet updates use atomic increments
3. **Idempotency**: Cycle numbers and unique constraints prevent duplicate credits
4. **Compare-and-Swap**: Investment updates use optimistic locking
5. **Error Handling**: Failed credits don't affect other investments
6. **Audit Trail**: All transactions logged in ledger

### Race Condition Prevention
- `lastRoiCreditAt` timestamp used for optimistic locking
- Cycle numbers ensure sequential crediting
- Unique constraint on `(investmentId, cycleNumber)` prevents duplicates

---

## 7. Workflow Diagram

```
User Purchase
    ↓
Validate Plan & Balance
    ↓
Debit Wallet (INR/USDT)
    ↓
Create Investment (status: active)
    ↓
[Post-actions: Referral, Salary, Breakdown, ROI Boost]
    ↓
┌─────────────────────────────────────┐
│  Cron Job (Every Hour)             │
│  ┌───────────────────────────────┐ │
│  │ For each active investment:   │ │
│  │ 1. Check if due for credit    │ │
│  │ 2. Calculate ROI (+ boost)   │ │
│  │ 3. Credit ROI wallet          │ │
│  │ 4. Create ledger entry        │ │
│  │ 5. Record RoiCredit           │ │
│  │ 6. Notify user                │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
    ↓
ROI Credited to User's ROI Wallet
    ↓
User Can Withdraw ROI Earnings
```

---

## 8. Configuration

### Environment Variables
- `CRON_SCHEDULE`: Cron schedule for ROI credit job (default: `'0 * * * *'` = hourly)

### Admin Configuration
- ROI plans can be created/updated via admin panel
- ROI boost rules can be configured (threshold, boost percentage, duration)
- Currency enforcement: Plans specify required currency (INR or USDT)

---

## 9. Example Scenarios

### Scenario 1: Daily ROI Plan
- **Plan**: 10% daily ROI, 30-day duration, 1000 USDT fixed
- **Purchase**: User buys plan with 1000 USDT
- **Credits**: Every day for 30 days, user receives 100 USDT ROI (10% of 1000)
- **Total ROI**: 3000 USDT over 30 days

### Scenario 2: ROI Boost
- **User**: Has 50+ referrals, qualifies for 2% boost
- **Investment**: 1000 USDT, 10% daily ROI
- **Base ROI**: 100 USDT/day
- **Boost**: 2% of 100 = 2 USDT/day
- **Total ROI**: 102 USDT/day

### Scenario 3: Currency Enforcement
- **Plan**: Requires INR currency
- **User**: Has 1000 USDT but 0 INR
- **Result**: Purchase rejected (insufficient INR balance)
- **Note**: No auto-conversion between currencies

---

## 10. API Endpoints

### User Endpoints
- `POST /investments` - Purchase a plan
- `GET /investments` - List user investments
- `GET /investments/:id` - Get investment details

### Admin Endpoints
- `GET /admin/roi-plans` - List all plans
- `POST /admin/roi-plans` - Create plan
- `PUT /admin/roi-plans/:id` - Update plan
- `GET /admin/roi-boost/rules` - List boost rules
- `POST /admin/roi-boost/rules` - Create boost rule

---

## 11. Monitoring & Debugging

### Logs
- Cron job logs: Success/failure counts, investment IDs, amounts
- Error logs: Failed credits with error messages
- Transaction logs: All wallet operations in ledger

### Common Issues
1. **Double credit**: Prevented by compare-and-swap on `lastRoiCreditAt`
2. **Missing credits**: Check cron job is running, check `isDueForCredit` logic
3. **Wrong amounts**: Verify ROI calculation, check boost application
4. **Currency mismatch**: Ensure plan currency matches investment currency

---

## Summary

The ROI workflow is designed for:
- **Reliability**: Serializable transactions, atomic operations, idempotency
- **Flexibility**: Multiple frequencies, currency support, boost system
- **Transparency**: Complete audit trail, user notifications
- **Safety**: Race condition prevention, error handling, validation

All ROI credits are processed automatically via cron job, ensuring users receive their returns on schedule without manual intervention.
