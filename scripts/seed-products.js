const path = require('path');
const fs = require('fs');
const os = require('os');
const https = require('https');

// Chargement automatique des variables d'environnement depuis .env si non définies
const envPath = path.resolve(__dirname, '../.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx !== -1) {
      const key = trimmed.slice(0, eqIdx).trim();
      const val = trimmed.slice(eqIdx + 1).trim();
      if (!process.env[key]) {
        process.env[key] = val;
      }
    }
  }
}

const { createStrapi } = require('@strapi/strapi');

// Helper pour télécharger un fichier distant
function downloadImage(url, destPath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(destPath);
    https.get(url, (response) => {
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        return downloadImage(response.headers.location, destPath).then(resolve).catch(reject);
      }
      if (response.statusCode !== 200) {
        return reject(new Error(`Erreur HTTP ${response.statusCode} lors du téléchargement de ${url}`));
      }
      response.pipe(file);
      file.on('finish', () => {
        file.close(() => resolve(destPath));
      });
    }).on('error', (err) => {
      fs.unlink(destPath, () => reject(err));
    });
  });
}

const CATEGORIES_DATA = [
  {
    name: 'Audio & Casques',
    slug: 'audio-casques',
    description: 'Casques haute fidélité, écouteurs sans fil True Wireless et enceintes nomades haute performance.',
  },
  {
    name: 'Informatique & Bureautique',
    slug: 'informatique-bureautique',
    description: 'Périphériques professionnels, claviers mécaniques custom, souris ergonomiques et écrans ultra-larges.',
  },
  {
    name: 'Objets connectés & Wearables',
    slug: 'objets-connectes',
    description: 'Montres intelligentes sport & santé, trackers d’activité avancés et stations de charge magnétique.',
  },
];

const PRODUCTS_DATA = [
  {
    title: 'Casque Sans Fil ANC Studio Pro',
    slug: 'casque-sans-fil-anc-studio-pro',
    categorySlug: 'audio-casques',
    description: 'Casque circum-aural haute résolution doté d’une réduction active hybride du bruit (ANC) jusqu’à -42dB. Transducteurs de 40mm en bio-cellulose pour une clarté sonore cristalline, coussinets à mémoire de forme ultra-confortables et 45 heures d’autonomie avec charge rapide USB-C.',
    imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=1000&q=80',
    imageName: 'casque-sans-fil-anc-studio-pro.jpg',
    imageAlt: 'Casque audio sans fil circum-aural noir avec réduction de bruit',
  },
  {
    title: 'Écouteurs True Wireless Neo ANC',
    slug: 'ecouteurs-true-wireless-neo-anc',
    categorySlug: 'audio-casques',
    description: 'Écouteurs intra-auriculaires Bluetooth 5.3 avec audio spatial 360° et réduction dynamique du vent. Résistance à l’eau et à la sueur IPX7, 3 micros par écouteur avec algorithme IA antibruit et boîtier de chargement compatible recharge sans fil Qi.',
    imageUrl: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=1000&q=80',
    imageName: 'ecouteurs-true-wireless-neo.jpg',
    imageAlt: 'Écouteurs intra-auriculaires True Wireless et leur étui de charge',
  },
  {
    title: 'Enceinte Bluetooth Nomade Pulse 360',
    slug: 'enceinte-bluetooth-nomade-pulse-360',
    categorySlug: 'audio-casques',
    description: 'Enceinte nomade compacte offrant un son omnidirectionnel puissant et des basses profondes grâce à son double radiateur passif. Certifiée IP67 étanche et résistante aux chocs, autonomie de 20 heures et anneau LED réactif au rythme de la musique.',
    imageUrl: 'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=1000&q=80',
    imageName: 'enceinte-portable-pulse-360.jpg',
    imageAlt: 'Enceinte portable Bluetooth avec diffusion audio à 360 degrés',
  },
  {
    title: 'Barre de Son Dolby Atmos Cinema Wave',
    slug: 'barre-de-son-dolby-atmos-cinema-wave',
    categorySlug: 'audio-casques',
    description: 'Système acoustique complet 3.1.2 canaux compatible Dolby Atmos et DTS:X pour transformer votre salon en salle de cinéma. Caisson de basses sans fil 200W, calibration spatiale automatique par micro intégré et connectique HDMI 2.1 eARC 4K pass-through.',
    imageUrl: 'https://images.unsplash.com/photo-1545454675-3531b543be5d?w=1000&q=80',
    imageName: 'barre-de-son-cinema-wave.jpg',
    imageAlt: 'Barre de son cinéma haute définition pour salon',
  },
  {
    title: 'Clavier Mécanique Sans Fil Apex Pro 75%',
    slug: 'clavier-mecanique-sans-fil-apex-pro-75',
    categorySlug: 'informatique-bureautique',
    description: 'Clavier mécanique compact format 75% usiné dans un châssis en aluminium anodisé CNC. Switches mécaniques linéaires pré-lubrifiés et interchangeables à chaud (Hot-Swap), touches en PBT double injection, rétroéclairage RGB personnalisable et triple connectivité sans fil.',
    imageUrl: 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=1000&q=80',
    imageName: 'clavier-mecanique-apex-pro.jpg',
    imageAlt: 'Clavier mécanique sans fil compact rétroéclairé',
  },
  {
    title: 'Souris Ergonomique Sans Fil ErgoGlide Master',
    slug: 'souris-ergonomique-sans-fil-ergoglide-master',
    categorySlug: 'informatique-bureautique',
    description: 'Souris verticale ergonomique inclinée à 57° pensée pour soulager la pression exercée sur le canal carpien et prévenir les tendinites. Capteur optique ultra-précis 4000 DPI réglable, molette magnétique crantée ou libre et batterie rechargeable avec 3 mois d’autonomie.',
    imageUrl: 'https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=1000&q=80',
    imageName: 'souris-ergonomique-ergoglide.jpg',
    imageAlt: 'Souris verticale ergonomique sans fil pour le bureau',
  },
  {
    title: 'Moniteur Incurvé 34" Ultrawide QHD Pro',
    slug: 'moniteur-incurve-34-ultrawide-qhd-pro',
    categorySlug: 'informatique-bureautique',
    description: 'Écran panoramique 21:9 WQHD (3440 x 1440) avec courbure immersive 1500R. Dalle IPS antireflet 144Hz couvrant 99% de l’espace DCI-P3, hub USB-C avec charge rapide 90W intégrée, commutateur KVM pour contrôler deux ordinateurs avec un seul ensemble clavier/souris.',
    imageUrl: 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=1000&q=80',
    imageName: 'moniteur-incurve-ultrawide-34.jpg',
    imageAlt: 'Moniteur incurvé 34 pouces ultra-large de bureau',
  },
  {
    title: 'Montre Connectée Titanium Horizon GPS',
    slug: 'montre-connectee-titanium-horizon-gps',
    categorySlug: 'objets-connectes',
    description: 'Montre connectée sportive d’exception conçue en titane de qualité aérospatiale avec verre saphir inrayable. Écran AMOLED Always-on ultra-lumineux 1500 nits, GPS bi-fréquence haute précision, capteur cardio optique 8 canaux, électrocardiogramme (ECG) et autonomie de 14 jours.',
    imageUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=1000&q=80',
    imageName: 'montre-connectee-titanium-horizon.jpg',
    imageAlt: 'Montre intelligente en titane avec bracelet sport',
  },
  {
    title: 'Bracelet d’Activité Pulse Fit Tracker',
    slug: 'bracelet-activite-pulse-fit-tracker',
    categorySlug: 'objets-connectes',
    description: 'Tracker connecté ultra-fin et léger pesant seulement 18 grammes. Suivi continu du sommeil en 4 phases, surveillance du stress et de la SpO2, étanchéité 5 ATM (50m) pour la natation, plus de 120 modes sportifs et autonomie remarquable de 18 jours par charge.',
    imageUrl: 'https://images.unsplash.com/photo-1575311373937-040b8e1fd5b6?w=1000&q=80',
    imageName: 'bracelet-activite-pulse-fit.jpg',
    imageAlt: 'Bracelet connecté de suivi d’activité physique et sommeil',
  },
  {
    title: 'Station de Charge Sans Fil 3-en-1 MagDock',
    slug: 'station-de-charge-sans-fil-3-en-1-magdock',
    categorySlug: 'objets-connectes',
    description: 'Support de charge magnétique pliable en aluminium aéronautique. Recharge simultanément à pleine puissance un smartphone compatible MagSafe (15W), des écouteurs sans fil (5W) et une montre connectée (5W). Idéal pour un bureau épuré ou pour vos déplacements professionnels.',
    imageUrl: 'https://images.unsplash.com/photo-1586816879360-004f5b0c51e5?w=1000&q=80',
    imageName: 'station-charge-magdock-3en1.jpg',
    imageAlt: 'Station de charge sans fil magnétique pliable en aluminium',
  },
];

async function seed() {
  console.log('🚀 Initialisation de Strapi 5...');
  const strapi = await createStrapi({
    distDir: path.resolve(__dirname, '../dist'),
  }).load();

  console.log('✅ Strapi 5 chargé avec succès.\n');

  const uploadService = strapi.plugin('upload').service('upload');
  const categoryDocsMap = new Map();

  // 1. Création des catégories
  console.log('📦 1/2. Traitement des Catégories...');
  for (const catData of CATEGORIES_DATA) {
    const existing = await strapi.documents('api::category.category').findMany({
      filters: { slug: catData.slug },
    });

    if (existing && existing.length > 0) {
      console.log(`   ℹ️ Catégorie existante : "${catData.name}" (${existing[0].documentId})`);
      categoryDocsMap.set(catData.slug, existing[0]);
    } else {
      const created = await strapi.documents('api::category.category').create({
        data: {
          name: catData.name,
          slug: catData.slug,
          description: catData.description,
        },
        status: 'published',
      });
      console.log(`   ✨ Catégorie créée : "${created.name}" (documentId: ${created.documentId})`);
      categoryDocsMap.set(catData.slug, created);
    }
  }

  console.log('\n📦 2/2. Traitement des 10 Produits & Upload des Médias...');
  let createdCount = 0;

  for (let i = 0; i < PRODUCTS_DATA.length; i++) {
    const prodData = PRODUCTS_DATA[i];
    console.log(`\n[${i + 1}/10] Traitement : "${prodData.title}"`);

    // Vérifier si le produit existe déjà
    const existing = await strapi.documents('api::produit.produit').findMany({
      filters: { slug: prodData.slug },
    });

    if (existing && existing.length > 0) {
      console.log(`   ℹ️ Produit déjà présent : "${prodData.title}" (${existing[0].documentId})`);
      continue;
    }

    const categoryDoc = categoryDocsMap.get(prodData.categorySlug);
    if (!categoryDoc) {
      console.error(`   ❌ Erreur : Catégorie introuvable pour "${prodData.categorySlug}"`);
      continue;
    }

    // Téléchargement de l'image
    const tmpFilePath = path.join(os.tmpdir(), `strapi-seed-${Date.now()}-${prodData.imageName}`);
    console.log(`   ⬇️ Téléchargement image depuis Unsplash...`);
    try {
      await downloadImage(prodData.imageUrl, tmpFilePath);
      const stat = fs.statSync(tmpFilePath);
      console.log(`   📷 Image téléchargée (${Math.round(stat.size / 1024)} Ko)`);

      // Upload dans la médiathèque Strapi
      const uploadedFiles = await uploadService.upload({
        data: {
          fileInfo: {
            name: prodData.imageName,
            alternativeText: prodData.imageAlt,
            caption: prodData.title,
          },
        },
        files: {
          filepath: tmpFilePath,
          originalFilename: prodData.imageName,
          mimetype: 'image/jpeg',
          size: stat.size,
        },
      });

      // Nettoyer le fichier temporaire
      if (fs.existsSync(tmpFilePath)) {
        fs.unlinkSync(tmpFilePath);
      }

      const uploadedMedia = uploadedFiles[0];
      console.log(`   📁 Média enregistré dans Strapi (id: ${uploadedMedia.id}, file: ${uploadedMedia.name})`);

      // Création du produit dans Strapi via le Document Service
      const createdProd = await strapi.documents('api::produit.produit').create({
        data: {
          title: prodData.title,
          slug: prodData.slug,
          description: prodData.description,
          category: categoryDoc.documentId,
          image: uploadedMedia.id,
          images: [uploadedMedia.id],
        },
        status: 'published',
      });

      console.log(`   ✅ Produit créé avec succès ! (documentId: ${createdProd.documentId})`);
      createdCount++;
    } catch (err) {
      console.error(`   ❌ Erreur lors du traitement du produit "${prodData.title}":`, err.message);
      if (fs.existsSync(tmpFilePath)) {
        fs.unlinkSync(tmpFilePath);
      }
    }
  }

  console.log(`\n🎉 Terminé ! ${createdCount} nouveaux produits insérés et publiés.`);
  try {
    await strapi.destroy();
  } catch (_) {}
  process.exit(0);
}

seed().catch((err) => {
  console.error('💥 Erreur fatale dans le script de seed :', err);
  process.exit(1);
});
