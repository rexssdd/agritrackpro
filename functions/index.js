const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const v = require('./validation');
initializeApp();
const db = getFirestore();
const now = () => FieldValue.serverTimestamp();
const can = (role, roles) => roles.includes(role);

exports.storeOperation = onCall({region: 'us-central1', timeoutSeconds: 120}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const uid = request.auth.uid;
  const input = request.data ?? {};
  // A stable request ID gives checkout/adjustment retries exactly one outcome.
  let requestId;
  try { requestId = v.id(input.requestId); }
  catch (_) { throw new HttpsError('invalid-argument', 'Invalid request ID'); }
  const operationRef = db.collection('operations').doc(`${uid}_${requestId}`);
  try {
    return await db.runTransaction(async tx => {
      const profile = await tx.get(db.collection('users').doc(uid));
      const role = profile.data()?.role;
      const inventoryAccess = role === 'staff' && profile.data()?.inventoryAccess === true;
      if (profile.data()?.active !== true) throw new HttpsError('permission-denied', 'Account is not active.');
      const allowed = {
        checkout: ['owner', 'cashier', 'staff'],
        saveProduct: ['owner', 'inventory'],
        adjustStock: ['owner', 'inventory'],
        addExpense: ['owner', 'inventory'],
        seed: ['owner'],
        publish: ['owner'],
      createOrder: ['customer'],
      saveGcashQr: ['owner'],
      confirmOrder: ['owner', 'cashier', 'staff'],
      };
      if (!can(role, allowed[input.action] ?? []) &&
          !(inventoryAccess && ['saveProduct', 'adjustStock'].includes(input.action))) {
        throw new HttpsError('permission-denied', 'Your role cannot perform this action.');
      }
      const prior = await tx.get(operationRef);
      if (prior.exists) return prior.data().result;
      let result = {};
      if (input.action === 'saveGcashQr') {
        const imageBase64 = v.image(input.imageBase64 ?? '');
        tx.set(db.collection('store_settings').doc('gcash'), {
          imageBase64, updatedAt: now(), updatedBy: uid
        });
        result = {saved: true};
      } else if (input.action === 'confirmOrder') {
        v.requireValue(input.paymentVerified === true,
            'Confirm payment receipt before completing an order');
        const orderId = v.id(input.orderId);
        const orderRef = db.collection('customer_orders').doc(orderId);
        const orderDoc = await tx.get(orderRef);
        const order = orderDoc.data();
        v.requireValue(orderDoc.exists && order.status === 'pending', 'Order is no longer pending');
        const lines = order.items.map(item => ({productId: v.id(item.productId), quantity: item.quantity}));
        const refs = lines.map(l => db.collection('products').doc(l.productId));
        const docs = await tx.getAll(...refs);
        const sale = v.saleLines(lines, docs.map(d => d.data()));
        if (order.paymentMethod === 'GCash') v.requireValue(v.text(order.paymentReference ?? '', 100).length > 0, 'GCash payment reference is required');
        const saleId = `${orderId}_sale`;
        const record = {...sale, amountPaid: sale.total, change: 0, method: order.paymentMethod,
          paymentReference: order.paymentReference ?? '', paymentVerified: true,
          customer: order.customerId, customerId: order.customerId, cashierId: uid, createdAt: now()};
        tx.create(db.collection('sales').doc(saleId), record);
        const {cost, items, ...receipt} = record;
        tx.create(db.collection('receipts').doc(saleId), {...receipt, items: items.map(({unitCost, ...item}) => item)});
        docs.forEach((doc, i) => {
          const stock = doc.data().stock - lines[i].quantity;
          tx.update(refs[i], {stock, updatedAt: now()});
          tx.set(db.collection('catalog').doc(doc.id), v.catalog({...doc.data(), stock, updatedAt: now()}));
          tx.create(db.collection('stock_movements').doc(), {productId: doc.id, productName: doc.data().name,
            delta: -lines[i].quantity, before: doc.data().stock, after: stock, reason: 'Customer preorder', saleId, userId: uid, createdAt: now()});
        });
        tx.update(orderRef, {status: 'confirmed', saleId, confirmedBy: uid, confirmedAt: now(), updatedAt: now()});
        result = {id: saleId};
      } else if (input.action === 'createOrder') {
        const lines = input.items;
        v.requireValue(Array.isArray(lines) && lines.length > 0 && lines.length <= 100, 'Invalid cart');
        const refs = lines.map(l => db.collection('products').doc(v.id(l.productId)));
        const docs = await tx.getAll(...refs);
        const order = v.saleLines(lines, docs.map(d => d.data()));
        const deliveryMode = v.text(input.deliveryMode, 40);
        const paymentMethod = v.text(input.paymentMethod, 20);
        v.requireValue(['Pickup', 'Cash on delivery'].includes(deliveryMode), 'Invalid delivery mode');
        v.requireValue(['Cash', 'GCash'].includes(paymentMethod), 'Invalid payment method');
        const paymentReference = v.text(input.paymentReference ?? '', 100);
        v.requireValue(paymentMethod === 'Cash' || paymentReference.length > 0, 'Enter the GCash reference');
        const orderId = `${uid}_${requestId}`;
        tx.create(db.collection('customer_orders').doc(orderId), {
          customerId: uid, customerEmail: v.text(input.customerEmail ?? '', 160), address: v.text(input.address ?? '', 500), items: order.items.map(({unitCost, ...item}) => item), total: order.total,
          deliveryMode, paymentMethod, paymentReference, status: 'pending', createdAt: now(), updatedAt: now()
        });
        result = {id: orderId};
      } else if (input.action === 'checkout') {
        const lines = input.items;
        v.requireValue(Array.isArray(lines) && lines.length > 0 && lines.length <= 100, 'Invalid cart');
        const refs = lines.map(l => db.collection('products').doc(v.id(l.productId)));
        const docs = await tx.getAll(...refs);
        v.requireValue(docs.every(d => d.data()?.costConfirmed !== false), 'The owner must confirm purchase costs before selling these products');
        const sale = v.saleLines(lines, docs.map(d => d.data()));
        v.requireValue(['Cash', 'GCash', 'Bank transfer'].includes(input.method), 'Invalid payment method');
        const paymentReference = v.text(input.paymentReference ?? '', 100);
        v.requireValue(input.method === 'Cash' || (input.paymentVerified === true && paymentReference.length > 0), 'Verify payment and enter its reference');
        const paid = v.money(input.amountPaid);
        v.requireValue(paid >= sale.total, 'Payment is less than total');
        const record = {...sale, amountPaid: paid, change: v.money(paid - sale.total), method: input.method,
          paymentReference, paymentVerified: input.method === 'Cash' || input.paymentVerified === true,
          customer: v.text(input.customer ?? '', 120), cashierId: uid, createdAt: now()};
        const saleRef = db.collection('sales').doc(requestId);
        // IDs are scoped to the user to avoid cross-user collisions.
        const saleId = `${uid}_${saleRef.id}`;
        tx.create(db.collection('sales').doc(saleId), record);
        const {cost, items, ...receipt} = record;
        tx.create(db.collection('receipts').doc(saleId), {...receipt, items: items.map(({unitCost, ...item}) => item)});
        docs.forEach((doc, i) => {
          const stock = doc.data().stock - lines[i].quantity;
          tx.update(refs[i], {stock, updatedAt: now()});
          tx.set(db.collection('catalog').doc(doc.id), v.catalog({...doc.data(), stock, updatedAt: now()}));
          tx.create(db.collection('stock_movements').doc(), {productId: doc.id, productName: doc.data().name,
            delta: -lines[i].quantity, before: doc.data().stock, after: stock, reason: 'Sale', saleId, userId: uid, createdAt: now()});
        });
        result = {id: saleId};
      } else if (input.action === 'saveProduct') {
        const p = v.product(input.product ?? {});
        const ref = db.collection('products').doc(input.id ? v.id(input.id) : requestId);
        const old = await tx.get(ref);
        if (old.exists) p.stock = old.data().stock;
        if (role !== 'owner') p.cost = old.exists ? old.data().cost : 0;
        const record = {...p, costConfirmed: role === 'owner' || (old.exists && old.data().costConfirmed !== false), updatedAt: now()};
        tx.set(ref, record);
        tx.set(db.collection('catalog').doc(ref.id), v.catalog(record));
        if (!old.exists && p.stock > 0) tx.create(db.collection('stock_movements').doc(), {
          productId: ref.id, productName: p.name, delta: p.stock, before: 0, after: p.stock,
          reason: 'Opening stock', userId: uid, createdAt: now()});
        result = {id: ref.id};
      } else if (input.action === 'adjustStock') {
        const ref = db.collection('products').doc(v.id(input.id));
        const doc = await tx.get(ref);
        const reason = v.text(input.reason);
        v.requireValue(doc.exists && Number.isSafeInteger(input.delta) && input.delta !== 0 && Math.abs(input.delta) <= 1e7 && reason.length > 0, 'Invalid stock adjustment');
        const stock = v.quantity(doc.data().stock + input.delta);
        tx.update(ref, {stock, updatedAt: now()});
        tx.set(db.collection('catalog').doc(ref.id), v.catalog({...doc.data(), stock, updatedAt: now()}));
        tx.create(db.collection('stock_movements').doc(), {productId: ref.id, productName: doc.data().name,
          delta: input.delta, before: doc.data().stock, after: stock, reason, userId: uid, createdAt: now()});
      } else if (input.action === 'addExpense') {
        const amount = v.money(input.amount), description = v.text(input.description);
        const category = v.text(input.category, 80);
        const date = new Date(input.date);
        v.requireValue(amount > 0 && description.length > 0 && Number.isFinite(date.getTime()) && date.getTime() <= Date.now() + 60000, 'Invalid expense details or date');
        tx.create(db.collection('expenses').doc(requestId), {amount, description, category,
          createdAt: Timestamp.fromDate(date), recordedAt: now(), createdBy: uid});
      } else if (input.action === 'seed') {
        v.requireValue(Array.isArray(input.products) && input.products.length <= 20 && Array.isArray(input.expenses) && input.expenses.length <= 20, 'Invalid seed data');
        const records = [];
        for (const p of input.products) {
          records.push([db.collection('products').doc(v.id(p.id)), {...v.product(p), costConfirmed: true, updatedAt: now()}]);
        }
        for (const e of input.expenses) {
          const amount = v.money(e.amount), description = v.text(e.description);
          v.requireValue(amount > 0 && description.length > 0, 'Invalid seed expense');
          records.push([db.collection('expenses').doc(v.id(e.id)), {amount, description, category: v.text(e.category, 80), createdBy: uid, createdAt: now()}]);
        }
        const docs = await tx.getAll(...records.map(([ref]) => ref));
        let count = 0;
        records.forEach(([ref, data], i) => {
          if (!docs[i].exists) {
            tx.create(ref, data); count++;
            if (ref.parent.id === 'products' && data.stock > 0) tx.create(db.collection('stock_movements').doc(), {
              productId: ref.id, productName: data.name, delta: data.stock, before: 0, after: data.stock,
              reason: 'Sample opening stock', userId: uid, createdAt: now()});
          }
          if (ref.parent.id === 'products') tx.set(db.collection('catalog').doc(ref.id), v.catalog(docs[i].exists ? docs[i].data() : data));
        });
        result = {count};
      } else if (input.action === 'publish') {
        // Paginated backfill for existing stores; never return private data.
        const collection = input.collection === 'sales' ? 'sales' : 'products';
        let query = db.collection(collection).orderBy('__name__').limit(150);
        if (input.after) query = query.startAfter(v.id(input.after));
        const snapshot = await tx.get(query);
        for (const doc of snapshot.docs) {
          const data = doc.data();
          if (collection === 'products') tx.set(db.collection('catalog').doc(doc.id), v.catalog(data));
          else {
            const {cost, items, ...receipt} = data;
            tx.set(db.collection('receipts').doc(doc.id), {...receipt, items: (items ?? []).map(({unitCost, ...item}) => item)});
          }
        }
        result = {count: snapshot.size, after: snapshot.size === 150 ? snapshot.docs.at(-1).id : null};
      }
      tx.create(operationRef, {action: input.action, result, createdAt: now()});
      return result;
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error.code) {
      console.error('Store transaction failed', error.code);
      throw new HttpsError('unavailable', 'Unable to save. Retry with the same request.');
    }
    throw new HttpsError('invalid-argument', error.message);
  }
});
