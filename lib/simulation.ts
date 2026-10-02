import {cashFlow, reportData, type RecordRow} from './report-data';

export const productNames = ['Urea', 'Phoska'] as const;
export type SimulationInput = {
  funding: number | null;
  subsidyBuyers: number | null;
  subsidySacksPerBuyer: number | null;
  subsidyUreaPercent: number | null;
  nonSubsidyBuyers: number | null;
  nonSubsidySacksPerBuyer: number | null;
  nonSubsidyUreaPercent: number | null;
  nonSubsidyKgPerSack: number | null;
  ureaSubsidyPrice: number | null;
  phoskaSubsidyPrice: number | null;
  subsidyCommission: number | null;
  extraCosts: number | null;
  purchaseBudget: number | null;
  targetMargin: number | null;
  ureaBuyPrice: number | null;
  ureaSellPrice: number | null;
  phoskaBuyPrice: number | null;
  phoskaSellPrice: number | null;
};
export type SavedSimulation = {inputs: SimulationInput; updatedAt: string};
export const defaultSimulation: SimulationInput = {
  funding: 113_000_000,
  subsidyBuyers: 40, subsidySacksPerBuyer: 1, subsidyUreaPercent: 50,
  nonSubsidyBuyers: 50, nonSubsidySacksPerBuyer: 1, nonSubsidyUreaPercent: 50,
  nonSubsidyKgPerSack: 50,
  ureaSubsidyPrice: 90_000, phoskaSubsidyPrice: 92_000,
  subsidyCommission: 0, extraCosts: 500_000,
  purchaseBudget: 20_000_000, targetMargin: 20_000,
  ureaBuyPrice: null, ureaSellPrice: null, phoskaBuyPrice: null, phoskaSellPrice: null,
};
export const inputLimits: Record<keyof SimulationInput, number> = {
  funding: 10_000_000_000_000, subsidyBuyers: 10_000, subsidySacksPerBuyer: 100,
  subsidyUreaPercent: 100, nonSubsidyBuyers: 10_000, nonSubsidySacksPerBuyer: 100,
  nonSubsidyUreaPercent: 100, nonSubsidyKgPerSack: 1_000,
  ureaSubsidyPrice: 100_000_000, phoskaSubsidyPrice: 100_000_000,
  subsidyCommission: 100_000_000, extraCosts: 10_000_000_000_000,
  purchaseBudget: 10_000_000_000_000, targetMargin: 100_000_000,
  ureaBuyPrice: 100_000_000, ureaSellPrice: 100_000_000,
  phoskaBuyPrice: 100_000_000, phoskaSellPrice: 100_000_000,
};
const decimalFields = new Set(['subsidySacksPerBuyer', 'nonSubsidySacksPerBuyer', 'nonSubsidyKgPerSack']);
export function validSimulationInput(value: unknown): value is SimulationInput {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const data = value as Record<string, unknown>;
  return Object.keys(data).length === Object.keys(defaultSimulation).length &&
    (Object.keys(defaultSimulation) as (keyof SimulationInput)[]).every(key => {
      const n = data[key];
      return n === null || typeof n === 'number' && Number.isFinite(n) && n >= 0 &&
        n <= inputLimits[key] && (decimalFields.has(key) ? Math.abs(n * 100 - Math.round(n * 100)) < 0.000001 : Number.isSafeInteger(n)) &&
        (key !== 'nonSubsidyKgPerSack' || n > 0);
    });
}
export function canonicalInputs(input: SimulationInput): string {
  return JSON.stringify(Object.fromEntries(Object.keys(defaultSimulation).map(key => [key, input[key as keyof SimulationInput]])));
}
export function validSavedSimulation(value: unknown): value is SavedSimulation {
  if (!value || typeof value !== 'object') return false;
  const plan = value as SavedSimulation;
  return validSimulationInput(plan.inputs) && typeof plan.updatedAt === 'string' &&
    !Number.isNaN(Date.parse(plan.updatedAt)) && new Date(plan.updatedAt).toISOString() === plan.updatedAt;
}
const round = (n: number) => Math.round(n * 100) / 100;
function splitSacks(people: number | null, perBuyer: number | null, ureaPercent: number | null) {
  if (people === null || perBuyer === null || ureaPercent === null) return null;
  const total = round(people * perBuyer), urea = Math.min(total, Math.round(total * ureaPercent / 100));
  return [urea, round(total - urea)] as const;
}
function valueForQuantity(qty: number | null, price: number | null) {
  return qty === 0 ? 0 : qty === null || price === null ? null : qty * price;
}
function sumKnown(values: (number | null)[]) {
  return values.some(value => value === null) ? null : values.reduce<number>((sum, value) => sum + (value as number), 0);
}

export function calculateSimulation(rows: RecordRow[], input: SimulationInput) {
  const actual = reportData(rows), cash = rows.reduce((sum, row) => sum + cashFlow(row), 0);
  const withdrawals = rows.filter(row => row.type === 'withdraw').reduce((sum, row) => sum + row.amount, 0);
  const bank = input.funding === null ? null : input.funding - withdrawals;
  const liquid = bank === null ? null : bank + cash;
  const sub = splitSacks(input.subsidyBuyers, input.subsidySacksPerBuyer, input.subsidyUreaPercent);
  const non = splitSacks(input.nonSubsidyBuyers, input.nonSubsidySacksPerBuyer, input.nonSubsidyUreaPercent);
  const incoming = rows.filter(row => row.type === 'purchase' && productNames.includes(row.product as typeof productNames[number]));
  const incomingSacks = incoming.reduce((sum, row) => sum + row.qty / 50, 0);
  const generalExpenses = rows.filter(row => row.type === 'expense' && !productNames.includes(row.product as typeof productNames[number])).reduce((sum, row) => sum + row.amount, 0);
  const products = productNames.map((name, index) => {
    const purchases = incoming.filter(row => row.product === name);
    const purchaseSacks = purchases.reduce((sum, row) => sum + row.qty / 50, 0);
    const expenses = rows.filter(row => row.type === 'expense' && row.product === name).reduce((sum, row) => sum + row.amount, 0);
    const allocatedExpenses = incomingSacks > 0 ? generalExpenses * purchaseSacks / incomingSacks : 0;
    const landed = purchaseSacks > 0 ? (purchases.reduce((sum, row) => sum + row.amount, 0) + expenses + allocatedExpenses) / purchaseSacks : null;
    const sold = rows.filter(row => row.type === 'sale' && row.product === name).reduce((sum, row) => sum + row.qty / 50, 0);
    const stock = round(purchaseSacks - sold), subsidySacks = sub?.[index] ?? null, nonSubsidySacks = non?.[index] ?? null;
    const subsidyPrice = index === 0 ? input.ureaSubsidyPrice : input.phoskaSubsidyPrice;
    const buyPrice = index === 0 ? input.ureaBuyPrice : input.phoskaBuyPrice;
    const sellPrice = index === 0 ? input.ureaSellPrice : input.phoskaSellPrice;
    return {name, stock, landed, subsidyPrice, buyPrice, sellPrice, subsidySacks, nonSubsidySacks,
      subsidyKg: subsidySacks === null ? null : subsidySacks * 50,
      nonSubsidyKg: nonSubsidySacks === null || input.nonSubsidyKgPerSack === null ? null : nonSubsidySacks * input.nonSubsidyKgPerSack,
      remaining: subsidySacks === null ? null : round(stock - subsidySacks),
      subRevenue: valueForQuantity(subsidySacks, subsidyPrice), subCost: valueForQuantity(subsidySacks, landed),
      nonRevenue: valueForQuantity(nonSubsidySacks, sellPrice), nonCost: valueForQuantity(nonSubsidySacks, buyPrice),
    };
  });
  const shortage = products.some(product => product.remaining !== null && product.remaining < -0.000001);
  const subSacks = sub ? sub[0] + sub[1] : null, nonSacks = non ? non[0] + non[1] : null;
  const subRevenue = sumKnown(products.map(product => product.subRevenue)), subCost = sumKnown(products.map(product => product.subCost));
  const nonRevenue = sumKnown(products.map(product => product.nonRevenue)), nonCost = sumKnown(products.map(product => product.nonCost));
  const subMargin = subRevenue === null || subCost === null ? null : subRevenue - subCost;
  const commission = valueForQuantity(subSacks, input.subsidyCommission);
  const subContribution = subMargin === null || commission === null ? null : subMargin + commission;
  const nonMargin = nonRevenue === null || nonCost === null ? null : nonRevenue - nonCost;
  const revenue = sumKnown([subRevenue, nonRevenue]), cost = sumKnown([subCost, nonCost]);
  const profit = shortage || subContribution === null || nonMargin === null || input.extraCosts === null ? null : subContribution + nonMargin - input.extraCosts;
  // Use the same conservative target as the workbook; positive subsidy contribution isn't pledged to cover new overhead.
  const neededContribution = subContribution === null || input.extraCosts === null ? null : Math.max(0, -subContribution) + input.extraCosts;
  const breakEvenMargin = shortage || neededContribution === null || nonSacks === null || nonSacks === 0 ? null : neededContribution / nonSacks;
  const targetProfit = shortage || nonSacks === null || input.targetMargin === null || subContribution === null || input.extraCosts === null ? null : nonSacks * input.targetMargin + subContribution - input.extraCosts;
  const closingCash = shortage || liquid === null || nonCost === null || revenue === null || commission === null || input.extraCosts === null ? null : liquid - nonCost - input.extraCosts + revenue + commission;
  const remainingCost = shortage ? null : sumKnown(products.map(product => valueForQuantity(product.remaining, product.landed)));
  const remainingPriceGap = shortage ? null : sumKnown(products.map(product => product.landed === null || product.subsidyPrice === null ? product.remaining === 0 ? 0 : null : valueForQuantity(product.remaining, product.landed - product.subsidyPrice)));
  const scenarios = [10_000, 20_000, 30_000].map(margin => ({margin,
    contribution: nonSacks === null ? null : nonSacks * margin,
    profit: shortage || nonSacks === null || subContribution === null || input.extraCosts === null ? null : nonSacks * margin + subContribution - input.extraCosts,
  }));
  return {cash, withdrawals, bank, liquid, products, shortage, subSacks, nonSacks, subRevenue, subCost, subMargin, commission,
    subContribution, nonRevenue, nonCost, nonMargin, revenue, cost, profit, breakEvenMargin, neededContribution, targetProfit,
    closingCash, remainingCost, remainingPriceGap, scenarios, generalExpenses,
    debt: actual.debtTotal, receivables: actual.creditTotal,
    purchaseBudgetExceeded: nonCost !== null && input.purchaseBudget !== null && nonCost > input.purchaseBudget,
    upfrontCash: nonCost === null || input.extraCosts === null ? null : nonCost + input.extraCosts,
    budgetPerSack: input.purchaseBudget === null || !nonSacks ? null : input.purchaseBudget / nonSacks,
    bankAfterBudget: bank === null || input.purchaseBudget === null ? null : bank - input.purchaseBudget,
  };
}
