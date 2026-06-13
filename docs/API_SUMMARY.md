# API Endpoints Summary

Complete list of all API endpoints implemented across 20 days.

## Authentication
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `POST /auth/refresh` - Refresh access token
- `POST /auth/2fa/setup` - Setup 2FA (placeholder)
- `POST /auth/2fa/verify` - Verify 2FA (placeholder)

## Health Check
- `GET /health` - Health check
- `GET /health?db=true` - Health check with DB

## KYC
- `POST /kyc` - Submit KYC documents
- `GET /kyc/status` - Get KYC status
- `GET /admin/kyc` - List KYC submissions (admin)
- `GET /admin/kyc/:id` - Get KYC details (admin)
- `PUT /admin/kyc/:id` - Approve/reject KYC (admin)

## Wallets
- `GET /wallets` - Get wallet balances
- `GET /wallets/:type/history` - Get wallet history

## Deposits (INR)
- `POST /deposits/inr/manual` - Create manual deposit
- `POST /deposits/inr/gateway` - Create gateway deposit
- `GET /deposits/inr` - List deposits
- `GET /admin/deposits` - List all deposits (admin)
- `PUT /admin/deposits/:id` - Approve/reject deposit (admin)

## Deposits (USDT)
- `POST /deposits/usdt/address` - Get/assign deposit address
- `GET /deposits/usdt` - List crypto deposits
- `POST /webhooks/moralis` - Moralis webhook

## Investments
- `POST /investments` - Purchase investment plan
- `GET /investments` - List user investments
- `GET /investments/:id` - Get investment details
- `GET /admin/plans` - List ROI plans (admin)
- `POST /admin/plans` - Create ROI plan (admin)
- `PUT /admin/plans/:id` - Update ROI plan (admin)
- `DELETE /admin/plans/:id` - Delete ROI plan (admin)

## ROI Management
- `GET /admin/roi/logs` - Get ROI credit logs (admin)
- `GET /admin/roi/stats` - Get ROI statistics (admin)
- `POST /admin/roi/credit/:investmentId` - Manually credit ROI (admin)
- `POST /admin/roi/process` - Process ROI credits (admin)

## Referrals
- `GET /referrals/me` - Get referral code & stats
- `GET /referrals/tree` - Get referral tree
- `GET /referrals/income` - Get referral income
- `GET /admin/referrals/levels` - Get referral levels (admin)
- `POST /admin/referrals/levels` - Configure levels (admin)
- `GET /admin/referrals/tree/:userId` - Get user tree (admin)
- `GET /admin/referrals/logs` - Get referral logs (admin)
- `GET /admin/referrals/stats` - Get referral stats (admin)

## Salary Income
- `GET /salary/status` - Check qualification status
- `GET /salary/stats` - Get salary statistics
- `GET /salary/income` - Get salary income history
- `GET /admin/salary/rules` - Get salary rules (admin)
- `POST /admin/salary/rules` - Create salary rule (admin)
- `PUT /admin/salary/rules/:id` - Update salary rule (admin)
- `GET /admin/salary/qualifications` - List qualifications (admin)
- `POST /admin/salary/check/:userId` - Check qualification (admin)
- `POST /admin/salary/credit/:qualificationId` - Credit salary (admin)
- `POST /admin/salary/process` - Process salary credits (admin)

## Breakdown & Refunds
- `GET /breakdown/stats` - Get breakdown statistics
- `GET /breakdown/entries` - Get breakdown entries
- `POST /breakdown/refund/:entryId` - Request refund
- `GET /breakdown/refunds` - Get refund requests
- `GET /breakdown/roi-boost` - Get ROI boost status
- `GET /admin/breakdown/policy` - Get breakdown policy (admin)
- `POST /admin/breakdown/policy` - Create policy (admin)
- `GET /admin/breakdown/entries` - List entries (admin)
- `GET /admin/breakdown/refunds` - List refund requests (admin)
- `POST /admin/breakdown/refunds/:requestId/process` - Process refund (admin)

## ROI Boost
- `GET /admin/roi-boost/rules` - Get boost rules (admin)
- `POST /admin/roi-boost/rules` - Create boost rule (admin)
- `PUT /admin/roi-boost/rules/:id` - Update boost rule (admin)
- `GET /admin/roi-boost/boosts` - List boosts (admin)
- `POST /admin/roi-boost/check/:userId` - Check boost (admin)
- `POST /admin/roi-boost/revoke/:boostId` - Revoke boost (admin)

## Withdrawals
- `POST /withdrawals` - Create withdrawal request
- `POST /withdrawals/:id/verify` - Verify OTP
- `GET /withdrawals` - List withdrawals
- `GET /withdrawals/:id` - Get withdrawal details
- `GET /admin/withdrawals` - List all withdrawals (admin)
- `POST /admin/withdrawals/:id/approve` - Approve withdrawal (admin)
- `POST /admin/withdrawals/:id/reject` - Reject withdrawal (admin)
- `POST /admin/withdrawals/:id/complete` - Complete withdrawal (admin)

## Transactions
- `GET /transactions` - Get transaction history
- `GET /transactions?export=csv` - Export to CSV
- `GET /transactions/summary` - Get transaction summary

## Currency Converter
- `GET /currency/rate` - Get exchange rate
- `POST /currency/convert` - Convert currency
- `GET /admin/currency/rates` - Get all rates (admin)
- `POST /admin/currency/rates` - Update rate (admin)
- `POST /admin/currency/fetch` - Fetch from API (admin)

## Notifications
- `GET /notifications` - Get notifications
- `PUT /notifications/:id/read` - Mark as read
- `PUT /notifications/read-all` - Mark all as read
- `GET /notifications/unread-count` - Get unread count
- `GET /admin/notifications/templates` - Get templates (admin)
- `POST /admin/notifications/templates` - Create template (admin)
- `PUT /admin/notifications/templates/:id` - Update template (admin)
- `POST /admin/notifications/send` - Send notification (admin)

## Admin Dashboard
- `GET /admin/dashboard/summary` - Get dashboard summary
- `GET /admin/dashboard/charts` - Get chart data
- `GET /admin/dashboard/top-referrers` - Get top referrers

## Support Tickets
- `POST /support/tickets` - Create ticket
- `GET /support/tickets` - List user tickets
- `GET /support/tickets/:id` - Get ticket with replies
- `POST /support/tickets/:id/replies` - Add reply
- `GET /admin/support/tickets` - List all tickets (admin)
- `PUT /admin/support/tickets/:id/assign` - Assign ticket (admin)
- `PUT /admin/support/tickets/:id/status` - Update status (admin)
- `POST /admin/support/tickets/:id/replies` - Add staff reply (admin)

## Blog
- `GET /blog/posts` - Get published posts
- `GET /blog/posts/:slug` - Get single post
- `GET /blog/categories` - Get categories
- `POST /blog/posts/:id/comments` - Add comment
- `GET /admin/blog/posts` - List all posts (admin)
- `POST /admin/blog/posts` - Create post (admin)
- `PUT /admin/blog/posts/:id` - Update post (admin)
- `DELETE /admin/blog/posts/:id` - Delete post (admin)
- `GET /admin/blog/categories` - List categories (admin)
- `POST /admin/blog/categories` - Create category (admin)
- `PUT /admin/blog/comments/:id/approve` - Approve comment (admin)

## CMS
- `GET /cms/pages` - Get published pages
- `GET /cms/pages/:slug` - Get single page
- `GET /admin/cms/pages` - List all pages (admin)
- `POST /admin/cms/pages` - Create page (admin)
- `PUT /admin/cms/pages/:id` - Update page (admin)
- `DELETE /admin/cms/pages/:id` - Delete page (admin)

## Settings (Admin)
- `GET /admin/settings/branding` - Get branding settings
- `PUT /admin/settings/branding` - Update branding
- `GET /admin/settings/fees-limits/:currency` - Get fees/limits
- `PUT /admin/settings/fees-limits/:currency` - Update fees/limits
- `GET /admin/settings/compliance` - Get compliance settings
- `PUT /admin/settings/compliance` - Update compliance
- `GET /admin/settings/integrations/:provider` - Get integration (masked)
- `PUT /admin/settings/integrations/:provider` - Update integration
- `GET /admin/settings/chains/:chain` - Get chain settings
- `PUT /admin/settings/chains/:chain` - Update chain settings
- `GET /admin/settings/audit` - Get audit log

## Staff & Roles (Admin)
- `GET /admin/staff/roles` - List roles
- `POST /admin/staff/roles` - Create role
- `PUT /admin/staff/roles/:id` - Update role
- `GET /admin/staff/staff` - List staff
- `POST /admin/staff/staff` - Create staff
- `PUT /admin/staff/staff/:id` - Update staff
- `GET /admin/staff/permissions` - List permissions

## White Label (Admin)
- `GET /admin/whitelabel/whitelabels` - List white labels
- `POST /admin/whitelabel/whitelabels` - Create white label
- `PUT /admin/whitelabel/whitelabels/:id` - Update white label
- `GET /admin/whitelabel/distributors` - List distributors
- `POST /admin/whitelabel/distributors` - Create distributor
- `PUT /admin/whitelabel/distributors/:id` - Update distributor
- `POST /admin/whitelabel/distributors/:id/assign-user` - Assign user
- `GET /admin/whitelabel/api/whitelabel/:apiKey` - Get white label info (public API)

## Webhooks
- `POST /webhooks/razorpay` - Razorpay webhook
- `POST /webhooks/moralis` - Moralis webhook

## Total Endpoints
- **User Endpoints**: ~40
- **Admin Endpoints**: ~80+
- **Webhooks**: 2
- **Total**: 120+ endpoints

All endpoints are documented in their respective day folders with examples and usage instructions.

