const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, collection, query, where, getDocs, serverTimestamp} = require('firebase/firestore');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} = require('firebase/auth');
const {getFunctions, connectFunctionsEmulator, httpsCallable} = require('firebase/functions');
const projectId = 'demo-agritrack';
let env;
const apps = [];
const users = {};

before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run with firebase emulators:exec. Never run against production.');
  env = await initializeTestEnvironment({projectId, firestore: {rules: fs.readFileSync('../firestore.rules', 'utf8')}});
  await env.clearFirestore();
  for (const role of ['owner','cashier','inventory','customer','staff','disabled']) {
    const app = initializeApp({projectId, apiKey: 'demo-key', authDomain: `${projectId}.firebaseapp.com`}, role);
    apps.push(app);
    const auth = getAuth(app);
    connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
    const credential = await createUserWithEmailAndPassword(auth, `${role}-${Date.now()}@example.test`, 'emulator-password');
    const functions = getFunctions(app);
    connectFunctionsEmulator(functions, '127.0.0.1', 5001);
    users[role] = {uid: credential.user.uid, call: httpsCallable(functions, 'storeOperation')};
  }
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const [role, user] of Object.entries(users)) await setDoc(doc(db, 'users', user.uid), {role, active: role !== 'disabled'});
    await setDoc(doc(db, 'products', 'rice'), {name:'Rice',category:'Seeds',unit:'bag',price:100,cost:60,stock:10,reorderLevel:2,active:true});
    await setDoc(doc(db, 'catalog', 'rice'), {name:'Rice',category:'Seeds',unit:'bag',price:100,stock:10,reorderLevel:2,active:true});
  });
});
after(async () => {
  await Promise.all(apps.map(deleteApp));
  if (env) await env.cleanup();
});
const client = role => env.authenticatedContext(users[role].uid).firestore();
let sequence = 0;
const call = (role, action, data = {}, requestId) => users[role].call({action, ...data, requestId: requestId ?? `test-${++sequence}`});

test('roles cannot read costs, write stock directly, or escalate themselves', async () => {
  await assertSucceeds(getDoc(doc(client('owner'), 'products', 'rice')));
  for (const role of ['cashier','inventory','customer','staff']) {
    const db = client(role);
    await assertSucceeds(getDoc(doc(db, 'catalog', 'rice')));
    await assertFails(getDoc(doc(db, 'products', 'rice')));
    await assertFails(setDoc(doc(db, 'sales', 'forged'), {total: 0}));
    await assertFails(updateDoc(doc(db, 'catalog', 'rice'), {stock: 999}));
    await assertFails(updateDoc(doc(db, 'users', users[role].uid), {role:'owner'}));
  }
  await assertFails(getDoc(doc(client('disabled'), 'catalog', 'rice')));
});
test('owner controls staff inventory access', async () => {
  const product = {name:'Staff test',category:'Seeds',unit:'bag',price:100,cost:0,stock:0,reorderLevel:2,active:true};
  await assert.rejects(call('staff','saveProduct',{id:'staff-product',product}));
  await assertFails(getDocs(collection(client('staff'),'stock_movements')));
  await assertSucceeds(updateDoc(doc(client('owner'),'users',users.staff.uid),
    {inventoryAccess:true,updatedAt:serverTimestamp()}));
  await call('staff','saveProduct',{id:'staff-product',product});
  await assertSucceeds(getDocs(collection(client('staff'),'stock_movements')));
  await assertSucceeds(updateDoc(doc(client('owner'),'users',users.staff.uid),
    {inventoryAccess:false,updatedAt:serverTimestamp()}));
  await assert.rejects(call('staff','adjustStock',{id:'rice',delta:1,reason:'Revoked'}));
});
test('owner assigns a workspace, non-owner cannot', async () => {
  const fields = {role: 'inventory', updatedAt: serverTimestamp()};
  await assertSucceeds(updateDoc(doc(client('owner'), 'users', users.staff.uid), fields));
  await assertFails(updateDoc(doc(client('cashier'), 'users', users.customer.uid), fields));
});
test('trusted checkout is idempotent, hides costs and deducts stock once', async () => {
  const payload = {items:[{productId:'rice',quantity:2,price:1}],method:'Cash',amountPaid:250,customer:'Farmer'};
  const first = await call('cashier','checkout',payload,'checkout-once');
  const second = await call('cashier','checkout',payload,'checkout-once');
  assert.equal(first.data.id, second.data.id);
  const product = await getDoc(doc(client('owner'),'products','rice'));
  assert.equal(product.data().stock, 8);
  const sale = await getDoc(doc(client('owner'),'sales',first.data.id));
  assert.equal(sale.data().total, 200);
  assert.equal(sale.data().cost, 120);
  const receipt = await getDoc(doc(client('cashier'),'receipts',first.data.id));
  assert.equal('cost' in receipt.data(), false);
  assert.equal('unitCost' in receipt.data().items[0], false);
  await assertFails(getDoc(doc(client('customer'),'receipts',first.data.id)));
  const receipts = await getDocs(query(collection(client('cashier'),'receipts'),where('cashierId','==',users.cashier.uid)));
  assert.equal(receipts.size, 1);
  await assertFails(getDocs(collection(client('cashier'),'receipts')));
});
test('payments, role restrictions, negative stock and adjustment audit are enforced', async () => {
  const payload = {items:[{productId:'rice',quantity:1}],method:'GCash',amountPaid:100};
  await assert.rejects(call('cashier','checkout',payload));
  await assert.rejects(call('inventory','checkout',{...payload,method:'Cash'}));
  await assert.rejects(call('customer','adjustStock',{id:'rice',delta:1,reason:'Forged'}));
  await assert.rejects(call('inventory','adjustStock',{id:'rice',delta:-999,reason:'Invalid'}));
  await call('inventory','adjustStock',{id:'rice',delta:5,reason:'Restock'});
  const product = await getDoc(doc(client('owner'),'products','rice'));
  assert.equal(product.data().stock, 13);
  const movements = await getDocs(collection(client('inventory'),'stock_movements'));
  assert.equal(movements.size, 2);
  await call('cashier','checkout',{...payload,paymentVerified:true,paymentReference:'GCASH-123'});
});
test('inventory product edits preserve hidden costs and stock; expenses accept dates', async () => {
  await call('inventory','saveProduct',{id:'rice', product:{name:'Rice updated',category:'Seeds',unit:'bag',price:110,cost:1,stock:999,reorderLevel:2,active:true}});
  const product = await getDoc(doc(client('owner'),'products','rice'));
  assert.equal(product.data().cost,60);
  assert.equal(product.data().stock,12);
  const date = '2026-01-05T00:00:00.000Z';
  await call('inventory','addExpense',{description:'Delivery',category:'Delivery',amount:100,date},'dated-expense');
  const expense = await getDoc(doc(client('owner'),'expenses','dated-expense'));
  assert.equal(expense.data().createdAt.toDate().toISOString(),date);
  await assert.rejects(call('cashier','addExpense',{description:'No access',category:'Other',amount:10,date}));
});

test('concurrent checkouts cannot sell the same final unit twice', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'products','last-unit'), {name:'Last unit',category:'Seeds',unit:'bag',price:100,cost:50,stock:1,reorderLevel:1,active:true});
  });
  const payload = {items:[{productId:'last-unit',quantity:1}],method:'Cash',amountPaid:100};
  const results = await Promise.allSettled([call('cashier','checkout',payload),call('cashier','checkout',payload)]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length,1);
  assert.equal((await getDoc(doc(client('owner'),'products','last-unit'))).data().stock,0);
});

test('a customer payment reference does not confirm an order', async () => {
  const created = await call('customer','createOrder',{
    items:[{productId:'rice',quantity:1}], deliveryMode:'Pickup',
    paymentMethod:'GCash', paymentReference:'UNVERIFIED-123'
  });
  const orderId = created.data.id;
  await assert.rejects(call('cashier','confirmOrder',{orderId}));
  assert.equal((await getDoc(doc(client('customer'),'customer_orders',orderId))).data().status,'pending');
  await call('cashier','confirmOrder',{orderId,paymentVerified:true});
  assert.equal((await getDoc(doc(client('customer'),'customer_orders',orderId))).data().status,'confirmed');
});

test('seeding is repeatable and backfill does not publish costs', async () => {
  const payload = {products:[{id:'demo-test',name:'Sample',category:'Seeds',unit:'bag',price:100,cost:60,stock:3,reorderLevel:1}],expenses:[]};
  assert.equal((await call('owner','seed',payload)).data.count,1);
  await call('owner','adjustStock',{id:'demo-test',delta:-1,reason:'Test deduction'});
  assert.equal((await call('owner','seed',payload)).data.count,0);
  assert.equal((await getDoc(doc(client('owner'),'products','demo-test'))).data().stock,2);
  await call('owner','publish',{collection:'products'});
  const catalog = await getDoc(doc(client('customer'),'catalog','demo-test'));
  assert.equal(catalog.data().stock,2);
  assert.equal('cost' in catalog.data(),false);
  await assert.rejects(call('customer','publish',{collection:'products'}));
});
