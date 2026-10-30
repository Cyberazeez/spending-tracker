# 07-sms-catalog: observed SMS formats

Source: the owner's screenshots (2026-10-30). Names, phone and account numbers are deliberately left out. Real fixtures are redacted copies under `supabase/tests/fixtures/<sender>/`, one file per template below. **No parser is written until its fixture exists.**

## Sender IDs (what iOS shows; the Shortcuts filter matches on these)
`alinma`, `barq app`, `D360 Bank`, `STC Bank`, `SNB-AlAhli`, `AlRajhiBank`, `900` (STC telecom bills). The exact string the Shortcut sends as `sender` must be confirmed on the phone in milestone 2.

## Cross-bank rules learned from the samples
1. **Wallet top-ups appear twice** (once at the paying bank, once at the receiving wallet). Examples: SNB "online purchase" of 100 at merchant `STC Bank` pairs with STC "إضافة أموال لحسابك" 100; SNB purchase at `MYSR D360` 85.40 pairs with D360 "Account Funding via Apple Pay" 85.4; STC Apple Pay purchase at `barq` pairs with barq "Money Added to your Barq wallet". Merchants `barq`, `STC Bank`, `D360`, `MYSR D360` are therefore treated as **wallet_topup**, and a matcher pairs both sides by amount within 5 minutes. Both are internal, neither is spend.
2. **Transfers to own accounts** (SNB 0102/0103/3301, Al Rajhi 6331/1271, Alinma 6000/6698/8119, D360 5911/0513/7705/8920, barq 1224/9105, STC 6190) are internal. Some SMS carry the owner's own name plus an IBAN ending 6000: internal.
3. **Foreign purchases**: barq shows `19.1 BHD (190.23 SAR) FX 9.9597`: store both. STC shows USD only (`USD 0.58`, AWS): SAR amount unknown until the card statement. Store USD, estimate SAR with a stored FX rate, flag `estimated`.
4. **Fees** come inside the transfer SMS (Al Rajhi/Alinma 0.58, SNB 2.50): create the transfer and a separate `fee` transaction.
5. **Dates differ per sender and sometimes per template** (see table). The SMS arrives seconds after the event, so the parser picks the candidate date closest to `received_at` when a template is ambiguous.
6. **Repeated near-identical SMS are real** (four D360 refunds in one minute, two 20,000.50 transfers 14 minutes apart). Dedupe on exact body plus 2-minute bucket never merges different amounts.
7. **Never stored:** balances (`الرصيد`, `Balance`, `Available balance`, `Wallet balance`), OTP bodies, phone numbers, account numbers longer than last 4.

## alinma (Arabic)
| Template | Fields | Type | Date format |
|---|---|---|---|
| حوالة صادرة محلية | amount, fee 0.58, beneficiary name, last4 | transfer_out (+fee) | `HH:mm dd-MM-yy` |
| شراء إنترنت / ApplePay, بطاقة ائتمانية *8119, لدى merchant | amount, merchant, card | purchase | `HH:mm dd-MM-yy` |
| تم إيداع الراتب | amount, account **6000 | salary | `HH:mm dd-MM-yy` |
| خصم قسط تمويل (Murabahah Commodity RBG) | amount, remaining, account | loan_installment | `HH:mm dd-MM-yyyy` |
| القسط الشهري للعقد LD... مستحق في | contract id, due date | obligation notice (no transaction) | `dd-MM-yy` |
| إصدار كشف حساب, بطاقة **8119 | total due, minimum, due date | card_statement notice | `dd-MM-yyyy` |
| رمز التفعيل / OTP | | ignored (otp) | |

## barq app (English)
| Template | Fields | Type | Date format |
|---|---|---|---|
| POS Purchase | card, Apple Pay flag, amount, At | purchase | `yyyy-MM-dd HH:mm` |
| Online Purchase | card **1224, amount, At, A/C | purchase | same |
| POS International Purchase | amount in BHD etc with SAR, FX, At, Country | purchase (foreign) | same |
| Refund | card, amount, At, On (date only) | refund | `yyyy-MM-dd` (time from received_at) |
| Your refund of SAR n from X has been processed | amount, merchant | refund | received_at |
| Credit/Debit Transfer Internal | amount, counterparty (masked), account last4 | transfer_in / transfer_out | `yyyy-MM-dd HH:mm` |
| Money Added to your Barq wallet | amount, via, card last4 | wallet_topup | same |
| Rejected transaction: Insufficient balance | | ignored (declined) | |
| Card removed from Apple Pay | | ignored (wallet_event) | |

## D360 Bank (English)
| Template | Type | Date format |
|---|---|---|
| Local POS Purchase / Local Online Purchase / Purchase / Online Purchase (Amount: SAR, Card: *8920 - VISA (Apple Pay), At, On) | purchase | `yyyy-MM-dd HH:mm` |
| Refund: International POS Purchase (Amount, Card, Fee, At, Country, On) | refund | same |
| Account Funding via Apple Pay (Amount, Card, To: *5911) | wallet_topup | `dd/MM/yyyy HH:mm:ss` |
| Transfer Between Your Accounts (From, Amount, To) | internal transfer | `yyyy-MM-dd  HH:mm` |
| Transaction Declined: Insufficient balance | ignored (declined) | |
| card frozen/unfrozen, added/removed from digital wallet, new device, maintenance, finance application status, OTP | ignored | |

## STC Bank (Arabic)
| Template | Type | Date format |
|---|---|---|
| شراء Apple Pay / عملية انترنت / شراء VISA (عبر *6190, بـ amount, من merchant) | purchase | `HH:mm dd/MM/yy` |
| إضافة أموال لحسابك (بـ amount ر.س, عبر *XXXX) | wallet_topup (in) | **`M/d/yyyy` with garbled `AM?/PM?` text**, parse hour from 12h part |
| حوالة داخلية صادرة (بـ amount, إلى name, حساب *4452) | transfer_out | `HH:mm dd/MM/yy` |
| حوالة داخلية (older, no صادرة) | transfer_out | same |
| رصيد غير كافي | ignored (declined) | |
| beneficiary added/activated, OTP, fee-schedule notices | ignored | |

## SNB-AlAhli (Arabic)
| Template | Type | Date format |
|---|---|---|
| شراء انترنت / شراء POS- (بـ SAR, من *0103, من merchant, مدى-ابل *3301) | purchase | `HH:mm dd/MM/yy` |
| حوالة بين حساباتك (من *0102, إلى *0103) | internal transfer | same |
| حوالة صادرة محلية (to own Alinma 6000, fee 2.50 on large ones) | internal transfer (+fee) | same |
| حوالة صادرة داخلية (to *6905 etc.) | transfer_out | same |
| حوالة واردة داخلية (from *6905, *9000, *0603) | transfer_in | same |
| رصيد غير كافي لشراء نقاط البيع | ignored (declined) | **`HH:mm MM/dd` no year** |
| مدخرات شركات سابقة ... | unknown, send to Needs review until explained | |
| daily limit change, maintenance, tariff notices | ignored | |

## AlRajhiBank (Arabic/English)
| Template | Type | Date format |
|---|---|---|
| شراء / شراء انترنت (بطاقة:1271;مدى-ابل باي, مبلغ, لدى merchant, من:6331) | purchase | `HH:mm d-M-yy` or `HH:mm d/M/yy` |
| حوالة محلية صادرة بـ SR (من 6331, لـ 6000;name, رسوم 0.58) | transfer_out (+fee) / internal | **`yy/M/d HH:mm`** |
| حوالة محلية (مصرف:SAB/SNB, الرسوم, مرجع) | transfer_out | `HH:mm d-M-yy` |
| حوالة داخلية صادرة / واردة / محلية واردة | transfer_out / transfer_in | `HH:mm d-M-yy` or **`yy-M-d HH:mm`** |
| OTP for Apple Pay, card added/removed, beneficiary added/activated, card approval/decline, card-expiry, tariff notices | ignored | |

Two numeric orders appear for dates (`d-M-yy` and `yy-M-d`). Resolve with `received_at` proximity.

## 900 (STC telecom bill notices)
`ونود فقط اشعارك بصدور فاتورة جديدة للرقم <line> بمبلغ إجمالي <amount> ريال (رقم الحساب: <acct>)`. Creates an obligation instance (expected amount, issue date = received_at) matched by line last 4: **internet 7356, mobile 0569**. Not a transaction. Ownership-transfer OTP messages are ignored.

## Not yet seen
ATM withdrawal (any bank); salary from a bank other than Alinma; electricity bill notice; Nothing else blocking.

### Alinma loan deductions (owner confirmed 2026-10-30)
One loan, just started. A month's installment can be collected in more than one deduction (an 87 SAR deduction on the 28th with 227,641.48 remaining, then 3,857.46 on the 29th once salary landed). The `المبلغ المتبقي` figure on a deduction is what is still owed for that period: `0.00` means the month is fully collected. The obligation instance for the month therefore sums all `خصم قسط تمويل` deductions until the expected installment is covered.
