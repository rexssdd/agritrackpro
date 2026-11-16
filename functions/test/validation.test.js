const {test} = require('node:test');
const assert = require('node:assert/strict');
const v = require('../validation');
const product = {name: 'Rice', price: 1.1, cost: 0.7, stock: 10, active: true, unit: 'bag'};

test('checkout uses trusted prices and integer cents', () => {
  const sale = v.saleLines([{productId: 'rice', quantity: 3, price: 0}], [product]);
  assert.equal(sale.total, 3.3);
  assert.equal(sale.cost, 2.1);
});
test('checkout rejects insufficient stock, duplicate lines and invalid quantities', () => {
  for (const quantity of [0, -1, 1.5, NaN, 11]) {
    assert.throws(() => v.saleLines([{productId: 'rice', quantity}], [product]));
  }
  assert.throws(() => v.saleLines([{productId: 'rice', quantity: 1}, {productId: 'rice', quantity: 1}], [product, product]));
  assert.throws(() => v.saleLines([{productId: 'rice', quantity: 1}], [{...product, active: false}]));
  assert.throws(() => v.saleLines([{productId: 'rice', quantity: 1}], [undefined]));
});
test('catalog projection contains only approved customer fields', () => {
  const visible = v.catalog({...product, supplierCost: 500, profit: 50, internalNote: 'secret'});
  assert.equal(visible.price, 1.1);
  for (const key of ['cost', 'supplierCost', 'profit', 'internalNote']) assert.equal(key in visible, false);
});
test('nonfinite monetary values and oversized images are rejected', () => {
  for (const amount of [NaN, Infinity, -1, '10']) assert.throws(() => v.money(amount));
  assert.throws(() => v.product({...product, category: 'Seeds', description: '', reorderLevel: 1, imageBase64: 'a'.repeat(163841)}));
});
