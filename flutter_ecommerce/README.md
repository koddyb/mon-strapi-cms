# TLveta

TLveta is a Flutter Web storefront backed by the local Strapi v5 API.

For Strapi administration access, local setup, seed instructions, and complete
Postman request examples, see the [Strapi API guide](../README.md).

## Run locally

From the repository root, start Strapi and its local PostgreSQL database:

```powershell
npm run dev:start
```

In another terminal, run the storefront:

```powershell
cd .\flutter_ecommerce
flutter pub get
flutter run -d chrome --web-port 5000
```

The API base URL defaults to `http://127.0.0.1:1337/api`. Override it at build
or run time with `--dart-define=STRAPI_API_URL=https://your-api.example/api`.

The browser app never embeds an API token or processes real card details.
Catalogue and category reads are public; opening a product and using the cart
require a customer account. Strapi grants storefront actions to the
Authenticated role and removes public cart permissions during bootstrap.

Every product has a required positive EUR price. The imported catalogue's
missing prices are populated locally, and `npm run seed` also fills a missing
price on an existing seeded product. The backend calculates order totals from
the current product prices and adds a fixed 4 EUR delivery fee.

## Demonstration payment

Checkout creates a pending order and opens a Stripe-inspired demonstration
screen. Selecting **Simuler le paiement** starts a server-timed 10-second
simulation. No card number is requested and no payment is sent to Stripe; after
the simulation, the order is marked as paid, the cart is cleared, and the home
page asks for the delivery address.

## API routes

- `GET /api/produits`, `GET /api/categories`: public catalogue reads.
- `POST /api/auth/local/register`, `POST /api/auth/local`: customer accounts.
- `GET /api/mon-panier`, `POST /api/mon-panier/lignes`,
  `PUT /api/mon-panier/lignes/:lineId`, `DELETE /api/mon-panier/lignes/:lineId`:
  authenticated cart operations.
- `POST /api/checkout/commandes`: create a server-priced pending order.
- `GET /api/mes-commandes/:documentId`,
  `GET /api/commandes/miennes`: read the authenticated customer's own orders.
- `POST /api/commandes/:documentId/simulation`,
  `POST /api/commandes/:documentId/confirmer-paiement`: run and confirm the
  timed payment simulation.
- `PUT /api/commandes/:documentId/adresse-livraison`: save the delivery address
  for a paid order owned by the authenticated customer.
