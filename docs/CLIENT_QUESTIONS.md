# Client Questions & Clarifications Needed

This document lists important questions and potential confusions that need clarification from the client before finalizing the ROI platform implementation.

---

## 🔴 CRITICAL QUESTIONS

### 1. **Principal Return on Investment Maturity**

**Current Behavior:**
- **On-chain investments** (with `contractStatus: 'staked'`): Principal IS returned automatically when investment matures
- **Regular investments** (without on-chain staking): Principal is NOT returned automatically

**Question:**
- Should principal be automatically returned to users when investments mature?
- Or should principal remain locked and users withdraw it separately?
- Is the distinction between on-chain and regular investments intentional?

**Impact:** This affects user expectations and withdrawal flows.

---

### 2. **ROI Wallet Currency Handling**

**Current Behavior:**
- ROI is credited to a separate "ROI" wallet type
- Each ROI credit stores the currency (INR or USDT) in the `RoiCredit` record
- However, the `Wallet` table doesn't have a currency field - it only has `type: 'ROI'`

**Question:**
- If a user has investments in both INR and USDT, they will receive ROI in both currencies
- How should the ROI wallet handle multiple currencies?
- Should there be separate ROI wallets per currency (ROI_INR, ROI_USDT)?
- Or should ROI always be in a single currency (e.g., always USDT)?

**Impact:** Affects withdrawal logic and wallet balance display.

---

### 3. **Investment Cancellation & Refund**

**Current Behavior:**
- Investment schema supports `status: 'cancelled'`
- Cancellation only happens when a breakdown refund is approved
- No direct cancellation mechanism for regular investments

**Questions:**
- Should users be able to cancel investments before maturity?
- If yes, what should happen:
  - Full principal refund?
  - Partial refund (minus fees/penalties)?
  - No refund?
- Should ROI already earned be clawed back on cancellation?
- What about investments that are already partially credited?

**Impact:** Affects user experience and financial calculations.

---

### 4. **Breakdown System Purpose**

**Current Behavior:**
- 20% of investment amount is deducted and goes to a "BREAKDOWN" wallet
- 80% goes to the breakdown wallet (which can be refunded after a certain period)
- This seems to be a "lock-up" or "escrow" mechanism

**Questions:**
- What is the purpose of the breakdown system?
- Is it a security measure, escrow, or something else?
- Should users understand this deduction upfront?
- Is the 20% deduction permanent or temporary?
- What happens to the 20% deduction - is it returned or kept by platform?

**Impact:** Affects user transparency and financial calculations.

---

## 🟡 IMPORTANT CLARIFICATIONS

### 5. **ROI Boost Expiration During Active Investment**

**Current Behavior:**
- ROI boost can expire while user has active investments
- Boost is checked at each ROI credit cycle

**Question:**
- If a ROI boost expires mid-investment, should it:
  - Stop applying immediately (only base ROI from that point)?
  - Continue for the entire investment duration (locked in at purchase)?
  - Something else?

**Impact:** Affects ROI calculations and user expectations.

---

### 6. **First ROI Credit Timing**

**Current Behavior:**
- For daily frequency plans, ROI can be credited on day 1 (same day as purchase)
- Calculation: `daysSinceLastCredit >= 1` (where lastCredit defaults to startDate)

**Question:**
- Should there be a minimum period before first ROI credit?
- For example: Daily plans credit on day 2, weekly on day 8, monthly on day 31?
- Or is same-day credit intentional?

**Impact:** Affects first ROI payment timing.

---

### 7. **On-Chain vs Off-Chain Investments**

**Current Behavior:**
- Some investments have `contractStatus: 'staked'` (on-chain)
- These are handled differently at maturity (principal returned)
- Regular investments don't have this field set

**Questions:**
- What determines if an investment should be staked on-chain?
- Is this automatic or manual?
- Should all investments be on-chain, or only specific plans?
- What's the business logic for this distinction?

**Impact:** Affects investment processing and maturity handling.

---

### 8. **Withdrawal from ROI Wallet**

**Current Behavior:**
- Users can withdraw from ROI wallet
- Withdrawal requires currency (INR or USDT)
- But ROI wallet type doesn't specify currency

**Question:**
- If user has ROI in both INR and USDT (from different investments), how should withdrawal work?
- Should withdrawal specify which currency to withdraw?
- Or should ROI be converted to a single currency for withdrawal?

**Impact:** Affects withdrawal UX and implementation.

---

### 9. **Investment Maturity Date Calculation**

**Current Behavior:**
- `maturityDate = startDate + durationDays`
- Uses simple date arithmetic

**Questions:**
- Should maturity date account for:
  - Business days only (exclude weekends/holidays)?
  - Timezone considerations?
  - Leap years?
- Or is simple calendar days sufficient?

**Impact:** Affects when investments mature.

---

### 10. **ROI Credit Failure Recovery**

**Current Behavior:**
- If ROI credit fails (e.g., database error), it's logged but not retried automatically
- Next cron run will attempt again if still eligible

**Question:**
- Should there be a manual retry mechanism for failed credits?
- Should admins be notified of failed credits?
- What's the acceptable failure rate?

**Impact:** Affects reliability and user trust.

---

## 🟢 MINOR CLARIFICATIONS

### 11. **ROI Rate Display**

**Question:**
- Should ROI rates be displayed as:
  - Per cycle (e.g., "10% per day")
  - Total over duration (e.g., "300% over 30 days")
  - Annualized (e.g., "3650% APY")
- What format is most user-friendly?

---

### 12. **Investment Status Transitions**

**Current States:** `active | completed | cancelled`

**Question:**
- Are there any other states needed (e.g., `paused`, `suspended`)?
- Can investments transition from `completed` back to `active`?
- What triggers each state change?

---

### 13. **Breakdown Refund Timeline**

**Current Behavior:**
- Breakdown refunds are eligible after `breakdownWindowDays` from investment start

**Question:**
- What is the typical breakdown window (e.g., 30 days, 90 days)?
- Should this be configurable per plan or global?
- What happens if user requests refund before window expires?

---

### 14. **ROI Credit Notifications**

**Current Behavior:**
- Users receive in-app notification and email on each ROI credit

**Question:**
- Is this frequency acceptable, or should there be:
  - Daily digest instead of per-credit?
  - Option to disable notifications?
  - SMS notifications for large credits?

---

### 15. **Minimum Investment Period**

**Question:**
- Is there a minimum investment period before users can request breakdown refunds?
- Should there be a "cooling-off" period for new investments?

---

## 📋 SUMMARY OF DECISIONS NEEDED

1. ✅ **Principal return policy** - Auto-return or manual withdrawal?
2. ✅ **ROI wallet currency** - Multi-currency or single currency?
3. ✅ **Investment cancellation** - Allowed? Refund policy?
4. ✅ **Breakdown purpose** - What is it for? Permanent or temporary?
5. ✅ **ROI boost expiration** - Locked in or expires mid-investment?
6. ✅ **First ROI timing** - Same day or next day?
7. ✅ **On-chain staking** - When and why?
8. ✅ **ROI withdrawal** - Currency selection or conversion?
9. ✅ **Maturity calculation** - Business days or calendar days?
10. ✅ **Failure recovery** - Manual retry needed?

---

## 🎯 RECOMMENDED NEXT STEPS

1. **Schedule a call** with client to discuss these questions
2. **Prioritize** critical questions (🔴) first
3. **Document decisions** in a requirements document
4. **Update implementation** based on client feedback
5. **Test edge cases** after decisions are made

---

## 📝 NOTES

- Some of these questions may have been answered in previous discussions but not documented in code
- It's better to clarify now than to discover issues in production
- Some decisions may require legal/compliance review (especially refund policies)
