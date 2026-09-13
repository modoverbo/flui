/// Opens the hosted checkout. Returns `false` when it could not be opened.
abstract interface class CheckoutLauncher {
  Future<bool> open(Uri purchaseUrl);
}
