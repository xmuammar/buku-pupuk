import {reportData, type RecordRow} from './report-data';

export const productNames = ['Urea', 'Phoska'] as const;
export type SimulationInput = {
  ureaSubsidySacks: number | null;
  ureaSubsidyPrice: number | null;
  ureaNonSubsidySacks: number | null;
  ureaNonSubsidyPrice: number | null;
  phoskaSubsidySacks: number | null;
  phoskaSubsidyPrice: number | null;
  phoskaNonSubsidySacks: number | null;
  phoskaNonSubsidyPrice: number | null;
};
export type SavedSimulation = {inputs: SimulationInput; updatedAt: string};
export const defaultSimulation: SimulationInput = {
  ureaSubsidySacks: 0, ureaSubsidyPrice: null,
  ureaNonSubsidySacks: 0, ureaNonSubsidyPrice: null,
  phoskaSubsidySacks: 0, phoskaSubsidyPrice: null,
  phoskaNonSubsidySacks: 0, phoskaNonSubsidyPrice: null,
};
export const inputLimits = Object.fromEntries(Object.keys(defaultSimulation).map(key =>
  [key, key.endsWith('Sacks') ? 1_000_000 : 100_000_000])) as Record<keyof SimulationInput, number>;
const round = (n: number) => Math.round(n * 1_000_000) / 1_000_000;
export function validSimulationInput(value: unknown): value is SimulationInput {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const data = value as Record<string, unknown>;
  return Object.keys(data).length === Object.keys(defaultSimulation).length &&
    (Object.keys(defaultSimulation) as (keyof SimulationInput)[]).every(key => {
      const n = data[key];
      return Object.hasOwn(data, key) && (n === null || typeof n === 'number' && Number.isFinite(n) && n >= 0 &&
        n <= inputLimits[key] && (key.endsWith('Sacks') ? Math.abs(n * 100 - Math.round(n * 100)) < 0.000001 : Number.isSafeInteger(n)));
    });
}
export function canonicalInputs(input: SimulationInput): string {
  return JSON.stringify(Object.fromEntries(Object.keys(defaultSimulation).map(key => [key, input[key as keyof SimulationInput]])));
}
export function validSavedSimulation(value: unknown): value is SavedSimulation {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const plan = value as SavedSimulation;
  return validSimulationInput(plan.inputs) && typeof plan.updatedAt === 'string' &&
    !Number.isNaN(Date.parse(plan.updatedAt)) && new Date(plan.updatedAt).toISOString() === plan.updatedAt;
}

// Older plans and backups remain readable without the removed funding or budget assumptions.
const legacyLimits: Record<string, number> = {
  funding: 10_000_000_000_000, subsidyBuyers: 10_000, subsidySacksPerBuyer: 100, subsidyUreaPercent: 100,
  nonSubsidyBuyers: 10_000, nonSubsidySacksPerBuyer: 100, nonSubsidyUreaPercent: 100, nonSubsidyKgPerSack: 1_000,
  ureaSubsidyPrice: 100_000_000, phoskaSubsidyPrice: 100_000_000, subsidyCommission: 100_000_000,
  extraCosts: 10_000_000_000_000, purchaseBudget: 10_000_000_000_000, targetMargin: 100_000_000,
  ureaBuyPrice: 100_000_000, ureaSellPrice: 100_000_000, phoskaBuyPrice: 100_000_000, phoskaSellPrice: 100_000_000,
};
function splitSacks(people: number | null, perBuyer: number | null, ureaPercent: number | null) {
  if (people === null || perBuyer === null || ureaPercent === null) return [null, null] as const;
  const total = round(people * perBuyer), urea = Math.min(total, Math.round(total * ureaPercent / 100));
  return [urea, round(total - urea)] as const;
}
export function normalizeSavedSimulation(value: unknown): SavedSimulation | null {
  if (validSavedSimulation(value)) return {inputs: {...value.inputs}, updatedAt: value.updatedAt};
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const old = value as {inputs?: Record<string, number | null>; updatedAt?: unknown}, data = old.inputs;
  if (!data || typeof data !== 'object' || Array.isArray(data) || Object.keys(data).length !== Object.keys(legacyLimits).length) return null;
  const decimals = new Set(['subsidySacksPerBuyer', 'nonSubsidySacksPerBuyer', 'nonSubsidyKgPerSack']);
  if (!Object.entries(legacyLimits).every(([key, max]) => Object.hasOwn(data, key) && (data[key] === null ||
    typeof data[key] === 'number' && Number.isFinite(data[key]) && data[key]! >= 0 && data[key]! <= max &&
    (decimals.has(key) ? Math.abs(data[key]! * 100 - Math.round(data[key]! * 100)) < 0.000001 : Number.isSafeInteger(data[key])) &&
    (key !== 'nonSubsidyKgPerSack' || data[key]! > 0)))) return null;
  const sub = splitSacks(data.subsidyBuyers, data.subsidySacksPerBuyer, data.subsidyUreaPercent);
  const non = splitSacks(data.nonSubsidyBuyers, data.nonSubsidySacksPerBuyer, data.nonSubsidyUreaPercent);
  // All new plans use 50 kg sacks; another old size needs new user input.
  const sameSize = data.nonSubsidyKgPerSack === 50;
  const plan = {updatedAt: old.updatedAt, inputs: {
    ureaSubsidySacks: sub[0], phoskaSubsidySacks: sub[1],
    ureaSubsidyPrice: data.ureaSubsidyPrice, phoskaSubsidyPrice: data.phoskaSubsidyPrice,
    ureaNonSubsidySacks: sameSize ? non[0] : null, phoskaNonSubsidySacks: sameSize ? non[1] : null,
    ureaNonSubsidyPrice: sameSize ? data.ureaSellPrice : null, phoskaNonSubsidyPrice: sameSize ? data.phoskaSellPrice : null,
  }};
  return validSavedSimulation(plan) ? plan : null;
}
function valueForQuantity(qty: number | null, price: number | null) {
  return qty === 0 ? 0 : qty === null || price === null ? null : qty * price;
}
function sumKnown(values: (number | null)[]): number | null {
  return values.some(value => value === null) ? null : values.reduce<number>((sum, value) => sum + (value as number), 0);
}

export function calculateSimulation(rows: RecordRow[], input: SimulationInput) {
  const actual = reportData(rows);
  const purchases = rows.filter(row => row.type === 'purchase');
  const incoming = purchases.filter(row => productNames.includes(row.product as typeof productNames[number]));
  const incomingSacks = incoming.reduce((sum, row) => sum + row.qty / 50, 0);
  const generalExpenses = rows.filter(row => row.type === 'expense' && !productNames.includes(row.product as typeof productNames[number]))
    .reduce((sum, row) => sum + row.amount, 0);
  const products = productNames.map((name, index) => {
    const prefix = index === 0 ? 'urea' : 'phoska';
    const bought = incoming.filter(row => row.product === name), sold = rows.filter(row => row.type === 'sale' && row.product === name);
    const purchaseSacks = bought.reduce((sum, row) => sum + row.qty / 50, 0), soldSacks = sold.reduce((sum, row) => sum + row.qty / 50, 0);
    const purchaseCost = bought.reduce((sum, row) => sum + row.amount, 0);
    const expenses = rows.filter(row => row.type === 'expense' && row.product === name).reduce((sum, row) => sum + row.amount, 0);
    const allocatedExpenses = incomingSacks > 0 ? generalExpenses * purchaseSacks / incomingSacks : 0;
    const landed = purchaseSacks > 0 ? (purchaseCost + expenses + allocatedExpenses) / purchaseSacks : null;
    const stock = round(purchaseSacks - soldSacks);
    const groups = (['Subsidy', 'NonSubsidy'] as const).map(kind => {
      const sacks = input[`${prefix}${kind}Sacks`], price = input[`${prefix}${kind}Price`];
      const revenue = valueForQuantity(sacks, price), cost = valueForQuantity(sacks, landed);
      return {kind, sacks, price, revenue, cost, margin: revenue === null || cost === null ? null : revenue - cost};
    });
    const sacks = sumKnown(groups.map(group => group.sacks)), revenue = sumKnown(groups.map(group => group.revenue));
    const cost = valueForQuantity(sacks, landed), remaining = sacks === null ? null : round(stock - sacks);
    const actualRevenue = sold.reduce((sum, row) => sum + row.amount, 0), actualCost = valueForQuantity(soldSacks, landed);
    return {name, stock, purchaseSacks, soldSacks, purchaseCost, expenses, allocatedExpenses, landed, groups, sacks,
      kg: sacks === null ? null : sacks * 50, revenue, cost, remaining,
      shortage: stock < -0.000001 || remaining !== null && remaining < -0.000001,
      margin: revenue === null || cost === null ? null : revenue - cost,
      actualRevenue, actualCost};
  });
  const shortage = products.some(product => product.shortage);
  const sacks = sumKnown(products.map(product => product.sacks)), revenue = sumKnown(products.map(product => product.revenue));
  const cost = sumKnown(products.map(product => product.cost));
  const profit = shortage || revenue === null || cost === null ? null : revenue - cost;
  const allocatedExpenses = products.filter(product => product.purchaseSacks > 0)
    .reduce((sum, product) => sum + product.expenses + product.allocatedExpenses, 0);
  const unallocatedExpenses = Math.max(0, actual.expenses - allocatedExpenses);
  const actualCost = sumKnown(products.map(product => product.actualCost));
  const actualProfit = actualCost === null ? null : actual.sales - actualCost - unallocatedExpenses;
  const periodProfit = profit === null || actualProfit === null ? null : actualProfit + profit;
  // Paid purchases and expenses are already in cash. Add only the new sale receipts.
  const closingCash = shortage || revenue === null ? null : actual.cash + revenue;
  const remainingCost = shortage ? null : sumKnown(products.map(product => valueForQuantity(product.remaining, product.landed)));
  const fertilizerPayments = purchases.reduce((sum, row) => sum + row.paid, 0) +
    rows.filter(row => row.type === 'pay').reduce((sum, row) => sum + row.amount, 0);
  return {products, shortage, sacks, revenue, cost, profit, actualProfit, periodProfit, closingCash, remainingCost,
    cash: actual.cash, debt: actual.debtTotal, receivables: actual.creditTotal, actualSales: actual.sales,
    fertilizerPayments, expenses: actual.expenses, expenditure: fertilizerPayments + actual.expenses,
    purchaseCost: actual.purchases, unallocatedExpenses,
    cashAfterDebt: closingCash === null ? null : closingCash - actual.debtTotal};
}
