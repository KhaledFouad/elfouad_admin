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

async function fetchSalesForRange(startUtc, endUtc) {
  const start = admin.firestore.Timestamp.fromDate(startUtc.toJSDate());
  const end = admin.firestore.Timestamp.fromDate(endUtc.toJSDate());
  const fields = ['created_at', 'original_created_at', 'settled_at', 'updated_at'];
  const queries = fields.map((field) =>
    db
      .collection('sales')
      .where(field, '>=', start)
      .where(field, '<', end)
      .get(),
  );
  const snaps = await Promise.all(queries);
  const combined = new Map();
  for (const snap of snaps) {
    for (const doc of snap.docs) {
      combined.set(doc.id, doc.data());
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

    let financialMs = createdMs ?? productionMs;
    if (paid) {
      if (settledMs != null) {
        financialMs = settledMs;
      } else if (updatedMs != null) {
        financialMs = updatedMs;
      }
    }

    const prodInRange = productionMs >= startMs && productionMs < endMs;
    const finInRange = financialMs >= startMs && financialMs < endMs;

    if (finInRange && (!isDeferred || paid)) {
      const isComplimentary = sale.is_complimentary === true;
      const totalPrice = isComplimentary ? 0 : num(sale.total_price);
      const totalCost = num(sale.total_cost);
      let profitTotal = num(sale.profit_total);
      if (profitTotal === 0 && (totalPrice !== 0 || totalCost !== 0)) {
        profitTotal = totalPrice - totalCost;
      }
      sales += totalPrice;
      cost += totalCost;
      profit += profitTotal;
    }

    if (prodInRange) {
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
      drinks: kpis.drinks,
      snacks: kpis.snacks,
      expenses: kpis.expenses,
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
