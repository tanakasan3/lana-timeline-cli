#!/usr/bin/env python3
import csv
import json
import sys
from pathlib import Path

if len(sys.argv) != 4:
    print("Usage: build_explorer.py <timeline_csv> <milestones_csv> <output_html>", file=sys.stderr)
    sys.exit(1)

timeline_csv = Path(sys.argv[1])
milestones_csv = Path(sys.argv[2])
output_html = Path(sys.argv[3])


def read_csv(path: Path):
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


timeline = read_csv(timeline_csv)
milestones = read_csv(milestones_csv)

html = f"""<!doctype html>
<html>
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>Lana Timeline Explorer</title>
  <style>
    :root {{
      color-scheme: dark;
      --bg: #0f1117;
      --panel: #161a22;
      --panel-2: #1d2430;
      --fg: #e6edf3;
      --muted: #9aa4b2;
      --border: #2a3342;
      --badge-bg: #253247;
      --accent: #7cc7ff;
    }}
    body {{
      font-family: system-ui, Arial, sans-serif;
      margin: 20px;
      background: var(--bg);
      color: var(--fg);
    }}
    h1 {{ margin: 0 0 12px; }}
    h2 {{ margin: 0 0 10px; }}
    .meta {{ color: var(--muted); margin-bottom: 16px; }}
    input {{
      padding: 8px;
      width: 100%;
      max-width: 560px;
      margin-bottom: 12px;
      border: 1px solid var(--border);
      border-radius: 8px;
      background: var(--panel);
      color: var(--fg);
    }}
    table {{ border-collapse: collapse; width: 100%; font-size: 13px; background: var(--panel); }}
    th, td {{ border: 1px solid var(--border); padding: 6px 8px; text-align: left; vertical-align: top; }}
    th {{ position: sticky; top: 0; background: var(--panel-2); }}
    .muted {{ color: var(--muted); }}
    .section {{ margin-top: 24px; }}
    .badge {{ display:inline-block; padding:2px 8px; border-radius:999px; background:var(--badge-bg); color: var(--accent); font-size:12px; border: 1px solid var(--border); }}
    pre {{ margin: 0; white-space: pre-wrap; word-break: break-word; max-width: 520px; }}
    .kv {{ margin: 0; padding-left: 16px; }}
    .kv li {{ margin: 0 0 2px; }}
    .details-title {{ font-weight: 600; margin-bottom: 4px; }}
    a {{ color: var(--accent); }}
  </style>
</head>
<body>
  <h1>Lana Timeline Explorer</h1>
  <div class=\"meta\">timeline rows: <b>{len(timeline)}</b> · milestone rows: <b>{len(milestones)}</b></div>

  <div class=\"section\">
    <h2>Timeline <span class=\"badge\">event-level</span></h2>
    <input id=\"q\" placeholder=\"Filter rows (customer id, facility id, event_type, entity, status...)\" />
    <table id=\"timeline\"></table>
  </div>

  <div class=\"section\">
    <h2>Milestones <span class=\"badge\">executive summary</span></h2>
    <table id=\"milestones\"></table>
  </div>

<script>
const timeline = {json.dumps(timeline)};
const milestones = {json.dumps(milestones)};

function esc(s) {{
  return String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}}

function safeJsonParse(s) {{
  try {{
    return JSON.parse(s);
  }} catch (_) {{
    return null;
  }}
}}

function val(path, obj) {{
  return path.reduce((acc, k) => (acc && acc[k] !== undefined ? acc[k] : null), obj);
}}

function dur(obj, path) {{
  const v = val(path.concat(['value']), obj);
  const t = val(path.concat(['type']), obj);
  if (v !== null && v !== undefined) return String(v) + (t ? (' ' + String(t)) : '');
  const raw = val(path, obj);
  return raw === null || raw === undefined ? null : JSON.stringify(raw);
}}

function satsToBtc(n) {{
  const x = Number(n);
  if (!Number.isFinite(x)) return null;
  return (x / 100000000).toFixed(8);
}}

function centsToUsd(n) {{
  const x = Number(n);
  if (!Number.isFinite(x)) return null;
  return (x / 100).toFixed(2);
}}

function pct(n) {{
  if (n === null || n === undefined) return null;
  const x = Number(n);
  if (!Number.isFinite(x)) return String(n);
  return x.toFixed(4) + '%';
}}

function cvl(v) {{
  if (v === null || v === undefined) return null;
  if (typeof v === 'object' && v.Finite !== undefined) return pct(v.Finite);
  return pct(v);
}}

function formatPeriod(period) {{
  if (!period || typeof period !== 'object') return '';
  const start = period.start ?? null;
  const end = period.end ?? null;
  const interval = (period.interval && period.interval.type) ? period.interval.type : null;
  const rows = [
    ['period_start', start],
    ['period_end', end],
    ['period_interval', interval],
  ].filter(([_, v]) => v !== null && v !== undefined)
   .map(([k, v]) => `<li><b>${{esc(k)}}:</b> ${{esc(v)}}</li>`)
   .join('');

  if (!rows) return '';
  return `<div class=\"details-title\">period</div><ul class=\"kv\">${{rows}}</ul>`;
}}

function formatTerms(terms) {{
  if (!terms || typeof terms !== 'object') return '';
  const picks = [
    ['duration', dur(terms, ['duration'])],
    ['annual_rate', pct(val(['annual_rate'], terms))],
    ['one_time_fee_rate', pct(val(['one_time_fee_rate'], terms))],
    ['initial_cvl', cvl(val(['initial_cvl'], terms))],
    ['margin_call_cvl', cvl(val(['margin_call_cvl'], terms))],
    ['liquidation_cvl', cvl(val(['liquidation_cvl'], terms))],
    ['disbursal_policy', val(['disbursal_policy'], terms)],
    ['accrual_interval', val(['accrual_interval', 'type'], terms) ?? JSON.stringify(val(['accrual_interval'], terms))],
    ['accrual_cycle_interval', val(['accrual_cycle_interval', 'type'], terms) ?? JSON.stringify(val(['accrual_cycle_interval'], terms))],
    ['interest_due_duration', dur(terms, ['interest_due_duration_from_accrual'])],
    ['overdue_duration', dur(terms, ['obligation_overdue_duration_from_due'])],
    ['liquidation_duration', dur(terms, ['obligation_liquidation_duration_from_due'])],
  ];

  const rows = picks
    .filter(([_, v]) => v !== null && v !== undefined && v !== 'null' && v !== 'undefined')
    .map(([k, v]) => `<li><b>${{esc(k)}}:</b> ${{esc(v)}}</li>`)
    .join('');

  if (!rows) return '';
  return `<div class=\"details-title\">terms</div><ul class=\"kv\">${{rows}}</ul>`;
}}

function formatQuant(parsed) {{
  const pairs = [];

  if (parsed.abs_diff !== undefined && parsed.abs_diff !== null) {{
    const btc = satsToBtc(parsed.abs_diff);
    if (btc !== null) {{
      const dir = String(parsed.direction || '').toLowerCase();
      const sign = dir === 'add' ? '+' : (dir === 'subtract' ? '-' : '');
      pairs.push(['abs_diff', `${{sign}}${{btc}}`]);
    }}
  }}

  if (parsed.collateral_amount !== undefined && parsed.collateral_amount !== null) {{
    const btc = satsToBtc(parsed.collateral_amount);
    if (btc !== null) pairs.push(['collateral_amount_btc', btc]);
  }}

  if (parsed.amount !== undefined && parsed.amount !== null) {{
    const usd = centsToUsd(parsed.amount);
    if (usd !== null) pairs.push(['amount_usd', usd]);
  }}

  for (const k of ['price', 'outstanding', 'trigger_price']) {{
    if (parsed[k] !== undefined && parsed[k] !== null) {{
      const usd = centsToUsd(parsed[k]);
      if (usd !== null) pairs.push([`${{k}}_usd`, usd]);
    }}
  }}

  for (const k of ['due_amount', 'overdue_amount', 'defaulted_amount', 'payment_allocation_amount']) {{
    if (parsed[k] !== undefined && parsed[k] !== null) {{
      const usd = centsToUsd(parsed[k]);
      if (usd !== null) pairs.push([`${{k}}_usd`, usd]);
    }}
  }}

  if (!pairs.length) return '';
  return `<div class=\"details-title\">quantitative</div><ul class=\"kv\">` +
    pairs.map(([k, v]) => `<li><b>${{esc(k)}}:</b> ${{esc(v)}}</li>`).join('') +
    `</ul>`;
}}

function formatCollateralizationRatio(v) {{
  if (v === null || v === undefined || v === '') return '';
  const parsed = (typeof v === 'string') ? safeJsonParse(v) : v;

  if (parsed === null) return 'NaN';

  if (typeof parsed === 'number') return String(parsed);
  if (typeof parsed === 'string') {{
    if (parsed.toLowerCase() === 'infinite' || parsed.toLowerCase() === 'null') return 'NaN';
    const n = Number(parsed);
    return Number.isFinite(n) ? String(n) : 'NaN';
  }}

  if (typeof parsed === 'object') {{
    if (parsed.Finite !== undefined && parsed.Finite !== null) {{
      const n = Number(parsed.Finite);
      return Number.isFinite(n) ? String(n) : String(parsed.Finite);
    }}
    if (parsed.Infinite !== undefined || parsed.Null !== undefined) return 'NaN';
  }}

  return 'NaN';
}}

function eom(y, m) {{
  return new Date(Date.UTC(y, m + 1, 0));
}}

function formatRepaymentSchedule(parsed, row) {{
  if (!parsed || !parsed.terms) return '';
  const terms = parsed.terms;
  const dur = terms.duration;
  if (!dur || dur.type !== 'months' || !dur.value) return '';
  const acyclType = val(['accrual_cycle_interval', 'type'], terms);
  if (acyclType !== 'end_of_month') return '';
  const annualRate = Number(val(['annual_rate'], terms));
  const otfRate = Number(val(['one_time_fee_rate'], terms));
  if (!Number.isFinite(annualRate)) return '';
  const principalCents = Number(row.amount_usd_cents);
  if (!Number.isFinite(principalCents) || principalCents <= 0) return '';

  const startStr = row.effective_at || '';
  if (!startStr) return '';
  const startDate = new Date(startStr);
  if (isNaN(startDate.getTime())) return '';

  const startY = startDate.getUTCFullYear();
  const startM = startDate.getUTCMonth();
  const startD = startDate.getUTCDate();
  const matDate = new Date(Date.UTC(startY, startM + dur.value, startD));
  const matTime = matDate.getTime();
  const startTime = Date.UTC(startY, startM, startD);

  const payments = [];
  let num = 1;

  if (Number.isFinite(otfRate) && otfRate > 0) {{
    const feeCents = Math.ceil(principalCents * otfRate / 100);
    payments.push({{ num: num++, date: startDate, daysSinceStart: 0, principal: 0, interest: feeCents }});
  }}

  let prevDate = new Date(startTime);
  let curM = startM + 1;
  let curY = startY;
  if (curM > 11) {{ curM -= 12; curY++; }}

  while (true) {{
    const eomDate = eom(curY, curM);
    if (eomDate.getTime() >= matTime) break;
    const daysInPeriod = Math.round((eomDate.getTime() - prevDate.getTime()) / 86400000);
    const intCents = Math.ceil(principalCents * daysInPeriod * annualRate / 100 / 365);
    const daysSinceStart = Math.round((eomDate.getTime() - startTime) / 86400000);
    payments.push({{ num: num++, date: eomDate, daysSinceStart, principal: 0, interest: intCents }});
    prevDate = eomDate;
    curM++;
    if (curM > 11) {{ curM -= 12; curY++; }}
  }}

  const finalDays = Math.round((matTime - prevDate.getTime()) / 86400000);
  const finalInt = Math.ceil(principalCents * finalDays * annualRate / 100 / 365);
  const totalDays = Math.round((matTime - startTime) / 86400000);
  payments.push({{ num: num++, date: matDate, daysSinceStart: totalDays, principal: principalCents, interest: finalInt }});

  function fmtDate(d) {{
    return d.toISOString().slice(0, 10);
  }}
  function fmtUsd(cents) {{
    return (cents / 100).toFixed(2);
  }}

  const hdr = '<tr><th>#</th><th>payment_date</th><th>days_since_start</th><th>principal_usd</th><th>interest_usd</th><th>total_usd</th></tr>';
  const rows = payments.map(p => {{
    const total = p.principal + p.interest;
    return `<tr><td>${{p.num}}</td><td>${{fmtDate(p.date)}}</td><td>${{p.daysSinceStart}}</td><td>${{fmtUsd(p.principal)}}</td><td>${{fmtUsd(p.interest)}}</td><td>${{fmtUsd(total)}}</td></tr>`;
  }}).join('');

  return `<details><summary class=\"details-title\">repayment schedule</summary><table style=\"font-size:12px;margin-top:6px;\">${{hdr}}${{rows}}</table></details>`;
}}

function formatDetails(v, row) {{
  const parsed = typeof v === 'string' ? safeJsonParse(v) : v;
  if (!parsed || typeof parsed !== 'object') return `<pre>${{esc(v)}}</pre>`;

  const topKeys = ['public_id','customer_type','approval_process_id','obligation_id','payment_id','beneficiary_id','reference','direction','maturity_date'];
  const topRows = topKeys
    .filter(k => parsed[k] !== undefined && parsed[k] !== null && parsed[k] !== '')
    .map(k => `<li><b>${{esc(k)}}:</b> ${{esc(parsed[k])}}</li>`)
    .join('');

  const topBlock = topRows ? `<ul class=\"kv\">${{topRows}}</ul>` : '';
  const quantBlock = formatQuant(parsed);
  const termsBlock = formatTerms(parsed.terms);
  const periodBlock = formatPeriod(parsed.period);
  const entity = (row && row.entity) ? row.entity : '';
  const schedBlock = (entity === 'credit_facility') ? formatRepaymentSchedule(parsed, row) : '';
  const rawBlock = `<details><summary class=\"muted\">raw json</summary><pre>${{esc(JSON.stringify(parsed, null, 2))}}</pre></details>`;

  return `${{topBlock}}${{quantBlock}}${{termsBlock}}${{periodBlock}}${{schedBlock}}${{rawBlock}}`;
}}

function renderTable(elId, rows, preferredCols) {{
  const el = document.getElementById(elId);
  if (!rows.length) {{
    el.innerHTML = '<tr><td class="muted">No rows</td></tr>';
    return;
  }}
  const cols = preferredCols.filter(c => rows[0].hasOwnProperty(c));
  const thead = '<tr>' + cols.map(c => `<th>${{esc(c)}}</th>`).join('') + '</tr>';
  const tbody = rows.map(r => '<tr>' + cols.map(c => {{
      const v = (r[c] ?? '');
      if (c === 'details') return `<td>${{formatDetails(v, r)}}</td>`;
      if (c === 'collateralization_ratio') return `<td>${{esc(formatCollateralizationRatio(v))}}</td>`;
      return `<td>${{esc(v)}}</td>`;
    }}).join('') + '</tr>').join('');
  el.innerHTML = `<thead>${{thead}}</thead><tbody>${{tbody}}</tbody>`;
}}

const timelineCols = [
  'timeline_bucket','event_at','effective_at','entity','event_type','status',
  'timeline_customer_id','timeline_facility_id','entity_id','version',
  'amount_usd_cents','collateral_sats','collateralization_ratio','price_usd','details'
];
const milestoneCols = ['milestone_bucket','milestone_at','milestone','source','customer_id','facility_id'];

renderTable('timeline', timeline, timelineCols);
renderTable('milestones', milestones, milestoneCols);

document.getElementById('q').addEventListener('input', (e) => {{
  const q = e.target.value.trim().toLowerCase();
  if (!q) return renderTable('timeline', timeline, timelineCols);
  const filtered = timeline.filter(r => Object.values(r).some(v => String(v ?? '').toLowerCase().includes(q)));
  renderTable('timeline', filtered, timelineCols);
}});
</script>
</body>
</html>
"""

output_html.write_text(html, encoding="utf-8")
print(str(output_html))
