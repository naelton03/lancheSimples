import { initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import fs from 'node:fs';

function loadCredential() {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    return cert(serviceAccount);
  }

  return applicationDefault();
}

const app = initializeApp({ credential: loadCredential() });
const db = getFirestore(app);

const tenantSeed = [
  {
    name: 'Lanche Central',
    tenantId: 'TENANT-1001',
    catalog: [
      { id: 'x-burger', name: 'X-Burger', price: 15, category: 'Lanches' },
      { id: 'x-salada', name: 'X-Salada', price: 17, category: 'Lanches' },
      { id: 'batata-g', name: 'Batata G', price: 12, category: 'Acompanhamentos' },
      { id: 'refrigerante-lata', name: 'Refrigerante Lata', price: 6, category: 'Bebidas' },
      { id: 'combo-familia', name: 'Combo Família', price: 39.9, category: 'Combos' }
    ]
  },
  {
    name: 'Burger do Bairro',
    tenantId: 'TENANT-1002',
    catalog: [
      { id: 'x-burger', name: 'X-Burger', price: 15, category: 'Lanches' },
      { id: 'x-salada', name: 'X-Salada', price: 17, category: 'Lanches' },
      { id: 'batata-g', name: 'Batata G', price: 12, category: 'Acompanhamentos' },
      { id: 'refrigerante-lata', name: 'Refrigerante Lata', price: 6, category: 'Bebidas' },
      { id: 'combo-familia', name: 'Combo Família', price: 39.9, category: 'Combos' }
    ]
  }
];

async function seed() {
  const batch = db.batch();
  const now = new Date().toISOString();

  for (const tenant of tenantSeed) {
    const tenantRef = db.collection('tenants').doc(tenant.tenantId);
    batch.set(tenantRef, {
      name: tenant.name,
      tenantId: tenant.tenantId,
      createdAt: now
    });

    for (const item of tenant.catalog) {
      const itemRef = tenantRef.collection('catalog').doc(item.id);
      batch.set(itemRef, {
        ...item,
        tenantId: tenant.tenantId,
        createdBy: 'seed-script',
        createdAt: now
      });
    }
  }

  await batch.commit();
  console.log(`Seed concluído com ${tenantSeed.length} tenants.`);
}

seed().catch((error) => {
  console.error('Falha ao executar seed do Firestore.');
  console.error(error);
  process.exitCode = 1;
});
