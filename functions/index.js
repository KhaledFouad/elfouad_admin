const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { DateTime } = require('luxon');

admin.initializeApp();

const db = admin.firestore();
const TZ = 'Africa/Cairo';
const OP_SHIFT_HOURS = 4;

function opStartLocal(nowLocal) {
  const base = nowLocal.set({
    hour: OP_SHIFT_HOURS,
    minute: 0,
    second: 0,
    millisecond: 0,
  });
  return nowLocal < base ? base.minus({ days: 1 }) : base;
}

function opEndLocal(nowLocal) {
  return opStartLocal(nowLocal).plus({ days: 1 });
}

function opDayKeyFromLocal(dayStartLocal) {
  return dayStartLocal
    .minus({ hours: OP_SHIFT_HOURS })
    .toFormat('yyyy-LL-dd');
}

function toMillis(value) {
  if (!value) return null;
  if (value.toMillis) {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  if (typeof value === 'number') {
    const raw = Math.trunc(value);
    return raw < 10000000000 ? raw * 1000 : raw;
  }
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function num(value) {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const n = parseFloat(value.replace(',', '.'));
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}

function toCount(value) {
  if (typeof value === 'number') return Math.round(value);
  if (typeof value === 'string') {
    const n = parseFloat(value.replace(',', '.'));
    return Number.isNaN(n) ? 0 : Math.round(n);
  }
  return 0;
}

function inRangeMs(tsMs, startMs, endMs) {
  return tsMs != null && tsMs >= startMs && tsMs < endMs;
}

function paymentEventsList(sale) {
  if (!Array.isArray(sale.payment_events)) return [];
  return sale.payment_events.filter((event) => event && typeof event === 'object');
}

function deferredPaidAmountInRange(sale, startMs, endMs) {
  const events = paymentEventsList(sale);
  if (events.length > 0) {
    let sum = 0;
    for (const event of events) {
      const amount = num(event.amount);
      if (amount <= 0) continue;
      const atMs = toMillis(event.at ?? event.paid_at ?? event.created_at);
      if (inRangeMs(atMs, startMs, endMs)) {
        sum += amount;
      }
    }
    return sum;
  }

  const fallbackAmount = num(sale.last_payment_amount);
  if (fallbackAmount <= 0) return 0;
  const fallbackAtMs = toMillis(sale.last_payment_at);
  return inRangeMs(fallbackAtMs, startMs, endMs) ? fallbackAmount : 0;
}

function hasDeferredPaymentTracking(sale) {
  if (sale.is_deferred !== true) return false;
  if (paymentEventsList(sale).length > 0) return true;
  return num(sale.last_payment_amount) > 0 && toMillis(sale.last_payment_at) != null;
}

async function fetchSalesForRange(startUtc, endUtc) {
  const start = admin.firestore.Timestamp.fromDate(startUtc.toJSDate());
  const end = admin.firestore.Timestamp.fromDate(endUtc.toJSDate());
  const fields = [
    'created_at',
    'original_created_at',
    'settled_at',
    'updated_at',
    'last_payment_at',
  ];
  const combined = new Map();
  const collections = ['sales', 'deferred_sales'];
  for (const coll of collections) {
    const queries = fields.map((field) =>
      db
        .collection(coll)
        .where(field, '>=', start)
        .where(field, '<', end)
        .get(),
    );
    const snaps = await Promise.all(queries);
    for (const snap of snaps) {
      for (const doc of snap.docs) {
        const data = doc.data();
        if (coll === 'deferred_sales' && data.is_deferred !== true) {
          data.is_deferred = true;
        }
        combined.set(doc.id, data);
      }
    }
  }
  return combined;
}

async function fetchExpensesForRange(startUtc, endUtc) {
  const start = admin.firestore.Timestamp.fromDate(startUtc.toJSDate());
  const end = admin.firestore.Timestamp.fromDate(endUtc.toJSDate());
  const snap = await db
    .collection('expenses')
    .where('created_at', '>=', start)
    .where('created_at', '<', end)
    .get();
  let expenses = 0;
  for (const doc of snap.docs) {
    expenses += num(doc.data().amount);
  }
  return expenses;
}

async function computeKpisForDay(dayStartLocal) {
  const startUtc = dayStartLocal.toUTC();
  const endUtc = dayStartLocal.plus({ days: 1 }).toUTC();
  const startMs = startUtc.toMillis();
  const endMs = endUtc.toMillis();

  const salesMap = await fetchSalesForRange(startUtc, endUtc);
  let sales = 0;
  let cost = 0;
  let profit = 0;
  let grams = 0;
  let drinks = 0;
  let snacks = 0;

  for (const sale of salesMap.values()) {
    const isDeferred = sale.is_deferred === true;
    const paid = sale.paid == null ? !isDeferred : sale.paid === true;

    const productionMs =
      toMillis(sale.original_created_at) ?? toMillis(sale.created_at);
    if (productionMs == null) {
      continue;
    }
    const createdMs = toMillis(sale.created_at);
    const settledMs = toMillis(sale.settled_at);
    const updatedMs = toMillis(sale.updated_at);
    const lastPaymentMs = toMillis(sale.last_payment_at);

    let financialMs = createdMs ?? productionMs;
    if (isDeferred && lastPaymentMs != null) {
      financialMs = lastPaymentMs;
    } else if (paid) {
      if (settledMs != null) {
        financialMs = settledMs;
      } else if (updatedMs != null) {
        financialMs = updatedMs;
      }
    }

    const prodInRange = inRangeMs(productionMs, startMs, endMs);
    const finInRange = inRangeMs(financialMs, startMs, endMs);

    let moneyFactor = 0;
    if (isDeferred && hasDeferredPaymentTracking(sale)) {
      const paidAmount = deferredPaidAmountInRange(sale, startMs, endMs);
      const basePrice = num(sale.parent_total_price) || num(sale.total_price);
      if (paidAmount > 0 && basePrice > 0) {
        moneyFactor = Math.max(0, Math.min(1, paidAmount / basePrice));
      }
    } else {
      moneyFactor = finInRange && (!isDeferred || paid) ? 1 : 0;
    }

    if (moneyFactor > 0) {
      const isComplimentary = sale.is_complimentary === true;
      const totalPrice = isComplimentary ? 0 : num(sale.total_price);
      const totalCost = num(sale.total_cost);
      let profitTotal = num(sale.profit_total);
      if (profitTotal === 0 && (totalPrice !== 0 || totalCost !== 0)) {
        profitTotal = totalPrice - totalCost;
      }
      sales += totalPrice * moneyFactor;
      cost += totalCost * moneyFactor;
      profit += profitTotal * moneyFactor;
    }

    const includeProduction = prodInRange && !(isDeferred && !paid);
    if (includeProduction) {
      const type = (sale.type ?? '').toString();
      if (type === 'drink') {
        const qty = num(sale.quantity);
        drinks += Math.max(1, Math.round(qty));
      } else if (type === 'single' || type === 'ready_blend') {
        grams += num(sale.grams);
      } else if (type === 'custom_blend') {
        grams += num(sale.total_grams);
      } else if (type === 'extra') {
        const qty = num(sale.quantity);
        snacks += Math.max(1, Math.round(qty));
      }
    }
  }

  const expenses = await fetchExpensesForRange(startUtc, endUtc);

  return {
    startUtc,
    endUtc,
    sales,
    cost,
    profit,
    grams,
    drinks,
    snacks,
    expenses,
  };
}

async function writeDailyArchive(dayStartLocal) {
  const dayKey = opDayKeyFromLocal(dayStartLocal);
  const year = dayStartLocal.year;
  const monthKey = dayStartLocal.toFormat('LL');
  const dayNumber = dayStartLocal.day;

  const kpis = await computeKpisForDay(dayStartLocal);

  const ref = db
    .collection('archive_daily')
    .doc(String(year))
    .collection(monthKey)
    .doc(dayKey);

  await ref.set(
    {
      dayKey,
      year,
      monthNumber: dayStartLocal.month,
      dayNumber,
      startUtc: kpis.startUtc.toISO(),
      endUtc: kpis.endUtc.toISO(),
      sales: kpis.sales,
      cost: kpis.cost,
      profit: kpis.profit,
      grams: kpis.grams,
      cups: kpis.drinks,
      units: kpis.snacks,
      drinks: kpis.drinks,
      snacks: kpis.snacks,
      expenses: kpis.expenses,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

exports.syncDailyArchiveKpis = functions.pubsub
  .schedule('every 15 minutes')
  .timeZone(TZ)
  .onRun(async () => {
    const nowLocal = DateTime.now().setZone(TZ);
    const todayStart = opStartLocal(nowLocal);
    const yesterdayStart = todayStart.minus({ days: 1 });

    await writeDailyArchive(todayStart);
    await writeDailyArchive(yesterdayStart);
  });
