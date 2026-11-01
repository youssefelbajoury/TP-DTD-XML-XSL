<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" encoding="UTF-8" indent="yes" doctype-system="about:legacy-compat"/>
    
    <xsl:template match="/">
        <html lang="fr" data-theme="dark">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                <title>Dashboard Météo National</title>
                <!-- Intégration de Chart.js pour le graphique -->
                <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
                
                <style>
                    :root {
                        --bg: #0f172a; --surface: #1e293b; --surface-hover: #334155;
                        --text: #f8fafc; --text-muted: #94a3b8; --border: #334155;
                        --accent: #3b82f6; --accent-hover: #2563eb;
                        --temp-cold: #38bdf8; --temp-mild: #4ade80; --temp-hot: #f87171;
                        --font: 'Inter', system-ui, sans-serif;
                    }
                    @media (prefers-color-scheme: light) {
                        :root {
                            --bg: #f8fafc; --surface: #ffffff; --surface-hover: #f1f5f9;
                            --text: #0f172a; --text-muted: #64748b; --border: #e2e8f0;
                            --temp-cold: #0284c7; --temp-mild: #16a34a; --temp-hot: #dc2626;
                        }
                    }
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body { font-family: var(--font); background: var(--bg); color: var(--text); padding: 2rem; transition: background 0.3s; }
                    
                    .dashboard { max-width: 1200px; margin: 0 auto; display: flex; flex-direction: column; gap: 2rem; }
                    
                    .header { display: flex; justify-content: space-between; align-items: flex-end; }
                    h1 { font-size: 2.5rem; font-weight: 700; letter-spacing: -0.02em; background: linear-gradient(to right, #3b82f6, #8b5cf6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
                    
                    .controls { display: flex; gap: 1rem; background: var(--surface); padding: 1rem; border-radius: 12px; border: 1px solid var(--border); box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
                    .search-box { flex: 1; position: relative; }
                    .search-input { width: 100%; padding: 0.75rem 1rem 0.75rem 2.5rem; background: var(--bg); border: 1px solid var(--border); border-radius: 8px; color: var(--text); font-size: 1rem; transition: all 0.2s; }
                    .search-input:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.2); }
                    .search-icon { position: absolute; left: 0.75rem; top: 50%; transform: translateY(-50%); color: var(--text-muted); }
                    
                    .date-select { padding: 0.75rem 1rem; background: var(--bg); border: 1px solid var(--border); border-radius: 8px; color: var(--text); font-size: 1rem; cursor: pointer; }
                    
                    /* Graphique Layout */
                    .chart-container { background: var(--surface); padding: 1.5rem; border-radius: 12px; border: 1px solid var(--border); box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); height: 350px; position: relative; }
                    
                    /* Table Layout */
                    .table-container { background: var(--surface); border-radius: 12px; border: 1px solid var(--border); overflow: hidden; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); }
                    table { width: 100%; border-collapse: collapse; text-align: left; }
                    th { background: var(--bg); padding: 1rem 1.5rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; font-size: 0.75rem; letter-spacing: 0.05em; cursor: pointer; user-select: none; transition: background 0.2s; border-bottom: 2px solid var(--border); }
                    th:hover { background: var(--surface-hover); color: var(--text); }
                    th.sort-asc::after { content: ' ↑'; }
                    th.sort-desc::after { content: ' ↓'; }
                    
                    td { padding: 1rem 1.5rem; border-bottom: 1px solid var(--border); font-size: 0.95rem; vertical-align: middle; }
                    tr { transition: background-color 0.2s ease, transform 0.1s; animation: fadeIn 0.4s ease-out forwards; }
                    tr:hover { background-color: var(--surface-hover); transform: scale(1.002); }
                    tr:last-child td { border-bottom: none; }
                    
                    .ville-cell { font-weight: 600; display: flex; align-items: center; gap: 0.75rem; }
                    
                    .temp-badge { display: inline-flex; align-items: center; justify-content: center; padding: 0.25rem 0.75rem; border-radius: 999px; font-weight: 700; font-variant-numeric: tabular-nums; }
                    .temp-cold { background: rgba(56, 189, 248, 0.1); color: var(--temp-cold); }
                    .temp-mild { background: rgba(74, 222, 128, 0.1); color: var(--temp-mild); }
                    .temp-hot { background: rgba(248, 113, 113, 0.1); color: var(--temp-hot); }
                    
                    .condition-badge { display: inline-flex; align-items: center; gap: 0.5rem; color: var(--text-muted); font-size: 0.875rem; }
                    .empty-state { padding: 3rem; text-align: center; color: var(--text-muted); display: none; }
                    
                    @keyframes fadeIn { from { opacity: 0; transform: translateY(5px); } to { opacity: 1; transform: translateY(0); } }
                </style>
            </head>
            <body>
                <div class="dashboard">
                    <header class="header">
                        <div>
                            <h1>MétéoLive Dashboard</h1>
                            <p style="color: var(--text-muted); margin-top: 0.5rem;">Analyse interactive des températures</p>
                        </div>
                    </header>

                    <div class="controls">
                        <div class="search-box">
                            <span class="search-icon">🔍</span>
                            <input type="text" id="searchInput" class="search-input" placeholder="Rechercher une ville..."/>
                        </div>
                        <select id="dateSelect" class="date-select">
                            <option value="ALL">Toutes les dates</option>
                            <xsl:for-each select="meteo/mesure">
                                <option value="{@date}"><xsl:value-of select="@date"/></option>
                            </xsl:for-each>
                        </select>
                    </div>

                    <!-- Conteneur du Graphique -->
                    <div class="chart-container">
                        <canvas id="tempChart"></canvas>
                    </div>

                    <div class="table-container">
                        <table id="meteoTable">
                            <thead>
                                <tr>
                                    <th data-sort="date">Date de Relevé</th>
                                    <th data-sort="ville">Ville</th>
                                    <th data-sort="temp" data-type="number">Température</th>
                                    <th data-sort="cond">Conditions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <xsl:for-each select="meteo/mesure/ville">
                                    <xsl:variable name="dateStr" select="../@date"/>
                                    <xsl:variable name="tempNum" select="@temperature"/>
                                    
                                    <tr data-date="{$dateStr}" data-ville="{@nom}" data-search="{translate(@nom, 'ABCDEFGHIJKLMNOPQRSTUVWXYZÉÈ', 'abcdefghijklmnopqrstuvwxyzéè')}">
                                        <td style="color: var(--text-muted);"><xsl:value-of select="$dateStr"/></td>
                                        <td>
                                            <div class="ville-cell">
                                                <span>📍</span>
                                                <xsl:value-of select="@nom"/>
                                            </div>
                                        </td>
                                        <td data-value="{$tempNum}">
                                            <xsl:attribute name="class">
                                                <xsl:text>temp-badge </xsl:text>
                                                <xsl:choose>
                                                    <xsl:when test="$tempNum &lt; 20">temp-cold</xsl:when>
                                                    <xsl:when test="$tempNum &gt; 25">temp-hot</xsl:when>
                                                    <xsl:otherwise>temp-mild</xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:attribute>
                                            <xsl:value-of select="$tempNum"/>°C
                                        </td>
                                        <td>
                                            <div class="condition-badge">
                                                <xsl:choose>
                                                    <xsl:when test="@condition='Ensoleillé'">☀️</xsl:when>
                                                    <xsl:when test="@condition='Nuageux'">☁️</xsl:when>
                                                    <xsl:when test="@condition='Pluvieux'">🌧️</xsl:when>
                                                    <xsl:when test="@condition='Orageux'">⛈️</xsl:when>
                                                    <xsl:otherwise>🌡️</xsl:otherwise>
                                                </xsl:choose>
                                                <xsl:value-of select="@condition"/>
                                            </div>
                                        </td>
                                    </tr>
                                </xsl:for-each>
                            </tbody>
                        </table>
                        <div id="emptyState" class="empty-state">
                            <div style="font-size: 2rem; margin-bottom: 1rem;">🌪️</div>
                            <h3>Aucune donnée trouvée</h3>
                            <p>Essayez de modifier vos critères de recherche.</p>
                        </div>
                    </div>
                </div>

                <script>
                    document.addEventListener('DOMContentLoaded', () => {
                        const searchInput = document.getElementById('searchInput');
                        const dateSelect = document.getElementById('dateSelect');
                        const tbody = document.querySelector('tbody');
                        const rows = Array.from(tbody.querySelectorAll('tr'));
                        const emptyState = document.getElementById('emptyState');
                        const headers = document.querySelectorAll('th');
                        
                        let chartInstance = null;

                        // Configuration initiale du graphique
                        const initChart = () => {
                            const ctx = document.getElementById('tempChart').getContext('2d');
                            
                            // Couleurs CSS du thème
                            const textColor = getComputedStyle(document.documentElement).getPropertyValue('--text-muted').trim() || '#94a3b8';
                            const gridColor = getComputedStyle(document.documentElement).getPropertyValue('--border').trim() || '#334155';

                            chartInstance = new Chart(ctx, {
                                type: 'bar',
                                data: { labels: [], datasets: [{ label: 'Température (°C)', data: [], backgroundColor: [], borderRadius: 6, borderSkipped: false }] },
                                options: {
                                    responsive: true,
                                    maintainAspectRatio: false,
                                    plugins: { legend: { display: false }, tooltip: { callbacks: { label: (ctx) => `${ctx.raw}°C` } } },
                                    scales: {
                                        y: { beginAtZero: true, grid: { color: gridColor }, ticks: { color: textColor } },
                                        x: { grid: { display: false }, ticks: { color: textColor } }
                                    },
                                    animation: { duration: 400 }
                                }
                            });
                        };

                        // Mise à jour des données du graphique
                        const updateChart = (visibleRows) => {
                            const labels = [];
                            const data = [];
                            const colors = [];

                            visibleRows.forEach(row => {
                                labels.push(row.getAttribute('data-ville') + ' (' + row.getAttribute('data-date').substring(5) + ')');
                                const temp = parseFloat(row.querySelector('td[data-value]').getAttribute('data-value'));
                                data.push(temp);
                                
                                // Couleurs dynamiques selon la température (match avec les badges)
                                if (temp &lt; 20) colors.push('#38bdf8'); // Froid
                                else if (temp &gt; 25) colors.push('#f87171'); // Chaud
                                else colors.push('#4ade80'); // Tempéré
                            });

                            chartInstance.data.labels = labels;
                            chartInstance.data.datasets[0].data = data;
                            chartInstance.data.datasets[0].backgroundColor = colors;
                            chartInstance.update();
                        };

                        // Normalize string for elastic search
                        const normalize = str => str.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

                        // Engine de filtrage combiné (Recherche + Date)
                        const filterData = () => {
                            const term = normalize(searchInput.value);
                            const selectedDate = dateSelect.value;
                            
                            const visibleRows = [];

                            rows.forEach(row => {
                                const searchStr = row.getAttribute('data-search');
                                const date = row.getAttribute('data-date');
                                
                                const matchSearch = searchStr.includes(term);
                                const matchDate = selectedDate === 'ALL' || date === selectedDate;

                                if (matchSearch &amp;&amp; matchDate) {
                                    row.style.display = '';
                                    visibleRows.push(row);
                                } else {
                                    row.style.display = 'none';
                                }
                            });

                            emptyState.style.display = visibleRows.length === 0 ? 'block' : 'none';
                            updateChart(visibleRows);
                        };

                        // Moteur de tri de tableau
                        let currentSort = { col: -1, asc: true };
                        const sortTable = (colIndex, type) => {
                            const isAsc = currentSort.col === colIndex ? !currentSort.asc : true;
                            currentSort = { col: colIndex, asc: isAsc };
                            
                            headers.forEach(h => { h.classList.remove('sort-asc', 'sort-desc'); });
                            headers[colIndex].classList.add(isAsc ? 'sort-asc' : 'sort-desc');

                            const visibleRows = rows.filter(r => r.style.display !== 'none');
                            
                            visibleRows.sort((a, b) => {
                                let valA = a.children[colIndex].textContent.trim();
                                let valB = b.children[colIndex].textContent.trim();
                                
                                if (type === 'number') {
                                    valA = parseFloat(a.children[colIndex].getAttribute('data-value'));
                                    valB = parseFloat(b.children[colIndex].getAttribute('data-value'));
                                    return isAsc ? valA - valB : valB - valA;
                                }
                                return isAsc ? valA.localeCompare(valB) : valB.localeCompare(valA);
                            });

                            visibleRows.forEach(row => tbody.appendChild(row));
                            updateChart(visibleRows); // MAJ du graph après tri
                        };

                        // Initialisation
                        initChart();
                        filterData(); // Charge le graphique au démarrage

                        // Event Listeners
                        searchInput.addEventListener('input', filterData);
                        dateSelect.addEventListener('change', filterData);

                        headers.forEach((th, index) => {
                            th.addEventListener('click', () => { sortTable(index, th.getAttribute('data-type')); });
                        });
                    });
                </script>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>