import '../../l10n/app_localizations.dart';

String typeLabel(AppLocalizations t, String type) => switch (type) {
  'purchase' => t.typePurchase,
  'refund' => t.typeRefund,
  'atm_withdrawal' => t.typeAtm,
  'transfer_out' => t.typeTransferOut,
  'transfer_in' => t.typeTransferIn,
  'salary' => t.typeSalary,
  'bill_payment' => t.typeBill,
  'card_payment' => t.typeCardPayment,
  'wallet_topup' => t.typeWalletTopup,
  'loan_installment' => t.typeLoan,
  'fee' => t.typeFee,
  _ => type,
};
