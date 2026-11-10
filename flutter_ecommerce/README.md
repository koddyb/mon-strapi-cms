# TLveta

TLveta is a Flutter Web storefront backed by the local Strapi v5 API.

For Strapi administration access, local setup, seed instructions, and complete
Postman request examples, see the [Strapi API guide](../strapi-cms/README.md).

## Run locally

Start Strapi on port `1350`, then run the storefront:

```powershell
flutter pub get
flutter run -d chrome --web-port 5000
```

Depuis la racine du dépôt cloné, pour démarrer Strapi sur le PC local :

```powershell
cd .\strapi-cms
$env:HOST = "127.0.0.1"
$env:PORT = "1350"
npm run develop
```

The API base URL defaults to `http://127.0.0.1:1350/api`. Override it at build
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
page asks for the delivery address. After saving the address, the app opens the
order timeline. Its payment, preparation, shipping, and delivery stages come
from order status and timestamped Strapi tracking events; unconfirmed stages are
shown as pending.

## Customer profile

From **Mon compte**, customers can update their first and last name, phone
number, and profile photo URL. The account page shows the saved name and photo.
Profile changes are stored on the authenticated Strapi user; the email remains
read-only.

## Order tracking

Open an order from **Mes commandes** to see its current status, dated events,
and shipping carrier or tracking number when available. Staff can update
`trackingStatus` (`preparing`, `shipped`, or `delivered`) and shipping details
in the Strapi administration. Strapi records each status change with a
timestamp; the storefront does not invent delivery progress.

## API routes

- `GET /api/produits`, `GET /api/categories`: public catalogue reads.
- `POST /api/auth/local/register`, `POST /api/auth/local`: customer accounts.
- `GET /api/users/me`, `PUT /api/client/profil`: read or update the authenticated
  customer's profile.
- `GET /api/mon-panier`, `POST /api/mon-panier/lignes`,
  `PUT /api/mon-panier/lignes/:lineId`, `DELETE /api/mon-panier/lignes/:lineId`:
  authenticated cart operations.
- `POST /api/checkout/commandes`: create a server-priced pending order.
- `GET /api/mes-commandes/:documentId`,
  `GET /api/commandes/miennes`: read the authenticated customer's own orders.
  These responses include the current tracking status and its event history.
- `POST /api/commandes/:documentId/simulation`,
  `POST /api/commandes/:documentId/confirmer-paiement`: run and confirm the
  timed payment simulation.
- `PUT /api/commandes/:documentId/adresse-livraison`: save the delivery address
  for a paid order owned by the authenticated customer.
