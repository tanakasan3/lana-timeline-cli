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
    body {{ font-family: system-ui, Arial, sans-serif; margin: 20px; }}
    h1 {{ margin: 0 0 12px; }}
    .meta {{ color: #555; margin-bottom: 16px; }}
    input {{ padding: 8px; width: 100%; max-width: 560px; margin-bottom: 12px; }}
    table {{ border-collapse: collapse; width: 100%; font-size: 13px; }}
    th, td {{ border: 1px solid #ddd; padding: 6px 8px; text-align: left; vertical-align: top; }}
    th {{ position: sticky; top: 0; background: #f6f6f6; }}
    .muted {{ color: #777; }}
    .section {{ margin-top: 24px; }}
    .badge {{ display:inline-block; padding:2px 8px; border-radius:999px; background:#eee; font-size:12px; }}
    pre {{ margin: 0; white-space: pre-wrap; word-break: break-word; max-width: 520px; }}
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

function renderTable(elId, rows, preferredCols) {{
  const el = document.getElementById(elId);
  if (!rows.length) {{
    el.innerHTML = '<tr><td class="muted">No rows</td></tr>';
    return;
  }}
  const cols = preferredCols.filter(c => rows[0].hasOwnProperty(c));
  const thead = '<tr>' + cols.map(c => `<th>${{c}}</th>`).join('') + '</tr>';
  const tbody = rows.map(r => '<tr>' + cols.map(c => {{
      const v = (r[c] ?? '');
      if (c === 'details') return `<td><pre>${{String(v)}}</pre></td>`;
      return `<td>${{String(v)}}</td>`;
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
