// Shared, deterministic validation used by the trusted transaction handlers.
function requireValue(ok, message) {
  if (!ok) throw new Error(message);
}
function money(value) {
  requireValue(typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1e9, 'Invalid amount');
  return Math.round(value * 100) / 100;
}
function text(value, max = 500) {
  requireValue(typeof value === 'string' && value.trim().length <= max, 'Invalid text');
  return value.trim();
}
function id(value) {
  requireValue(typeof value === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(value), 'Invalid record ID');
  return value;
}
function quantity(value, positive = false) {
  requireValue(Number.isSafeInteger(value) && value >= (positive ? 1 : 0) && value <= 1e7, 'Invalid quantity');
  return value;
}
function product(input) {
  const name = text(input.name, 120);
  requireValue(name.length > 0, 'Enter a product name');
  const imageBase64 = input.imageBase64 ?? '';
  requireValue(typeof imageBase64 === 'string' && imageBase64.length <= 163840 && /^[A-Za-z0-9+/=]*$/.test(imageBase64), 'Invalid product image');
  return {name, category: text(input.category, 80), unit: text(input.unit, 30),
    description: text(input.description ?? '', 2000), imageBase64,
    price: money(input.price), cost: money(input.cost ?? 0),
    stock: quantity(input.stock), reorderLevel: quantity(input.reorderLevel), active: input.active !== false};
}
function catalog(product) {
  const visible = {};
  for (const key of ['name','category','unit','description','imageBase64','price','stock','reorderLevel','active','updatedAt']) {
    if (product[key] !== undefined) visible[key] = product[key];
  }
  return visible;
}
function saleLines(lines, products) {
  requireValue(Array.isArray(lines) && lines.length > 0 && lines.length <= 100, 'Cart must have 1 to 100 products');
  const seen = new Set();
  let totalCents = 0, costCents = 0;
  const items = lines.map((line, i) => {
    const productId = id(line.productId);
    requireValue(!seen.has(productId), 'Duplicate product in cart');
    seen.add(productId);
    const p = products[i];
    const count = quantity(line.quantity, true);
    requireValue(p && p.active !== false && p.stock >= count, 'Product unavailable or insufficient stock');
    const price = money(p.price), unitCost = money(p.cost);
    const subtotal = Math.round(price * 100) * count;
    totalCents += subtotal;
    costCents += Math.round(unitCost * 100) * count;
    return {productId, name: p.name, unit: p.unit, quantity: count, price, unitCost, subtotal: subtotal / 100};
  });
  return {items, total: totalCents / 100, cost: costCents / 100};
}
function image(value) {
  requireValue(typeof value === 'string' && value.length <= 163840 && /^[A-Za-z0-9+/=]*$/.test(value), 'Invalid image');
  return value;
}
module.exports = {requireValue, money, text, id, quantity, product, catalog, saleLines, image};
