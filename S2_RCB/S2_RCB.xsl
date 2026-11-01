<?xml version="1.0" encoding="UTF-8"?>
<!--
  S2_RCB.xsl : Rendu interactif du relevé bancaire.
  Intègre filtres, tris, Dark Mode, et tableau de bord analytique.
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output method="html" encoding="UTF-8" indent="yes" doctype-system="about:legacy-compat"/>
    <xsl:strip-space elements="*"/>

    <!-- Format monétaire français (espaces insécables pour les milliers) -->
    <xsl:decimal-format name="fr" decimal-separator="," grouping-separator="&#160;"/>

    <!-- ========================================================= Configuration -->
    <xsl:variable name="currency" select="'MAD'"/>
    <xsl:variable name="months" select="'janv.févr.mars avr. mai  juin juil.août sept.oct. nov. déc. '"/>

    <!-- ========================================================= Agrégations -->
    <xsl:variable name="ops" select="/releve/operations/operation"/>
    <xsl:variable name="nb-ops" select="count($ops)"/>
    
    <xsl:variable name="credits" select="$ops[@type='CREDIT']"/>
    <xsl:variable name="debits" select="$ops[@type='DEBIT']"/>
    
    <xsl:variable name="sum-credits" select="sum($credits/@montant)"/>
    <xsl:variable name="sum-debits" select="sum($debits/@montant)"/>
    <xsl:variable name="total-volume" select="$sum-credits + $sum-debits"/>

    <xsl:variable name="credit-share">
        <xsl:choose>
            <xsl:when test="$total-volume &gt; 0"><xsl:value-of select="round(100 * $sum-credits div $total-volume)"/></xsl:when>
            <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:variable name="debit-share" select="100 - $credit-share"/>

    <!-- ========================================================= Layout Principal -->
    <xsl:template match="/">
        <html lang="fr">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <meta name="color-scheme" content="light dark"/>
                <title>Relevé de Compte Bancaire</title>
                <style><![CDATA[
                    /* ---------- Design Tokens ---------- */
                    :root {
                        color-scheme: light dark;
                        --canvas: #EEF1F5;
                        --surface: #FFFFFF;
                        --head: #F7F9FB;
                        --row-hover: #F3F7FF;
                        --ink: #0F1B2D;
                        --muted: #566074;
                        --line: #DCE2EA;
                        --accent: #0B5FFF;
                        --accent-soft: #E6EEFF;
                        --credit: #0A7468;
                        --credit-soft: #DCF3EF;
                        --debit: #B3391A;
                        --debit-soft: #FDE8E1;
                        --radius-panel: 14px;
                        --radius-control: 10px;
                        --ease: cubic-bezier(.2, .7, .2, 1);
                        --dur-fast: 140ms;
                        --dur-base: 240ms;
                        --font: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                        
                        --icon-in: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 19V5M5 12l7-7 7 7'/%3E%3C/svg%3E");
                        --icon-out: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='M12 5v14M19 12l-7 7-7-7'/%3E%3C/svg%3E");
                    }

                    @media (prefers-color-scheme: dark) {
                        :root {
                            --canvas: #0A0F18;
                            --surface: #111826;
                            --head: #0E1521;
                            --row-hover: #151F33;
                            --ink: #E8EDF5;
                            --muted: #93A0B5;
                            --line: #222C3D;
                            --accent: #6EA0FF;
                            --accent-soft: #172746;
                            --credit: #4FD1BD;
                            --credit-soft: #0F2E2B;
                            --debit: #FF9A7A;
                            --debit-soft: #381C14;
                        }
                    }

                    /* ---------- Base ---------- */
                    *, *::before, *::after { box-sizing: border-box; }
                    [hidden] { display: none !important; }
                    body { margin: 0; background: var(--canvas); color: var(--ink); font: 400 1rem/1.5 var(--font); }
                    .sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0,0,0,0); }
                    .shell { max-width: 1120px; margin: auto; padding: clamp(20px, 5vw, 56px) clamp(16px, 4vw, 32px); }

                    /* ---------- Masthead ---------- */
                    .masthead { display: grid; grid-template-columns: minmax(0, 1fr) minmax(300px, 420px); gap: 28px 64px; align-items: end; margin-bottom: 32px; }
                    h1 { margin: 0; font-size: clamp(1.5rem, 1.1rem + 1.4vw, 2rem); font-weight: 650; line-height: 1.15; }
                    .lede { margin: 6px 0 0; color: var(--muted); }
                    
                    .balance-box { background: var(--surface); padding: 24px; border-radius: var(--radius-panel); border: 1px solid var(--line); box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
                    .balance-label { margin: 0; font-size: .875rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; }
                    .balance-amount { margin: 4px 0 0; font-size: clamp(2rem, 1.3rem + 3vw, 2.75rem); font-weight: 700; letter-spacing: -0.03em; font-variant-numeric: tabular-nums; }
                    .currency { margin-left: 6px; font-size: 1rem; color: var(--muted); font-weight: 600; }
                    
                    /* Split Bar */
                    .split { display: flex; gap: 3px; height: 8px; margin: 16px 0 10px; }
                    .split-seg { flex: var(--share) 1 0; border-radius: 999px; }
                    .split-credit { background: var(--credit); }
                    .split-debit { background: var(--debit); }
                    .legend { display: flex; justify-content: space-between; margin: 0; padding: 0; list-style: none; font-size: .875rem; }
                    .legend li { display: grid; gap: 2px; }
                    .legend-name { display: inline-flex; align-items: center; gap: 8px; font-weight: 600; }
                    .legend-name::before { content: ""; width: 8px; height: 8px; border-radius: 50%; background: var(--credit); }
                    .legend-debit .legend-name::before { background: var(--debit); }
                    .legend-value { font-variant-numeric: tabular-nums; color: var(--muted); }

                    /* ---------- Panel & Toolbar ---------- */
                    .panel { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius-panel); overflow: hidden; box-shadow: 0 1px 2px rgba(0,0,0,.05); }
                    .toolbar { display: flex; flex-wrap: wrap; gap: 12px; justify-content: space-between; padding: 14px 16px; border-bottom: 1px solid var(--line); }
                    .filters { display: flex; flex-wrap: wrap; gap: 8px; }
                    
                    .search { width: min(100%, 320px); padding: 9px 12px 9px 38px; border: 1px solid var(--line); border-radius: var(--radius-control); background: var(--surface) no-repeat 12px center / 16px url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 20 20' fill='none' stroke='%238A91A0' stroke-width='1.8' stroke-linecap='round'%3E%3Ccircle cx='9' cy='9' r='5.5'/%3E%3Cpath d='M13.5 13.5L17 17'/%3E%3C/svg%3E"); color: var(--ink); font: inherit; font-size: .9375rem; transition: border-color var(--dur-fast), box-shadow var(--dur-fast); }
                    .search:focus-visible { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px color-mix(in srgb, var(--accent) 25%, transparent); }

                    .segments { display: inline-flex; gap: 2px; padding: 3px; border: 1px solid var(--line); border-radius: var(--radius-control); background: var(--head); }
                    .segment { display: inline-flex; align-items: center; gap: 8px; padding: 6px 12px; border: 0; border-radius: 7px; background: transparent; color: var(--muted); font: inherit; font-size: .875rem; font-weight: 550; cursor: pointer; transition: all var(--dur-fast); }
                    .segment:hover { color: var(--ink); }
                    .segment[aria-pressed="true"] { background: var(--surface); color: var(--ink); box-shadow: 0 1px 2px rgba(0,0,0,.1), 0 0 0 1px var(--line); }

                    /* ---------- Table ---------- */
                    .table-wrap { max-height: 70vh; overflow: auto; overscroll-behavior: contain; }
                    .ledger { width: 100%; border-collapse: collapse; font-size: .9375rem; }
                    .ledger thead th { position: sticky; top: 0; z-index: 2; padding: 0; background: var(--head); border-bottom: 1px solid var(--line); color: var(--muted); font-size: .8125rem; font-weight: 600; text-align: left; }
                    .ledger thead th[aria-sort="ascending"], .ledger thead th[aria-sort="descending"] { color: var(--ink); }
                    
                    .sort { display: flex; align-items: center; gap: 8px; width: 100%; padding: 12px 16px; border: 0; background: none; color: inherit; font: inherit; cursor: pointer; font-weight: inherit; text-align: left; }
                    .sort::after { content: ""; width: .45em; height: .45em; border: solid currentColor; border-width: 0 1.6px 1.6px 0; transform: rotate(45deg); opacity: 0; transition: all var(--dur-fast); }
                    .sort:hover::after { opacity: .5; }
                    th[aria-sort="descending"] .sort::after { opacity: 1; }
                    th[aria-sort="ascending"] .sort::after { opacity: 1; transform: rotate(-135deg); }
                    
                    .num { text-align: right !important; font-variant-numeric: tabular-nums; }
                    .num .sort { justify-content: flex-end; }

                    .op-row td { padding: 12px 16px; border-bottom: 1px solid var(--line); vertical-align: middle; transition: background var(--dur-fast); }
                    .op-row:hover td { background: var(--row-hover); }
                    .op-row:last-child td { border-bottom: 0; }

                    /* ---------- Badges & Typo ---------- */
                    .date-col { font-weight: 500; }
                    .desc-col { font-weight: 600; }
                    .amt-credit { color: var(--credit); font-weight: 700; }
                    .amt-debit { font-weight: 500; }

                    .badge { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px 4px 8px; border-radius: 999px; font-size: .75rem; font-weight: 700; letter-spacing: 0.03em; text-transform: uppercase; }
                    .badge::before { content: ""; width: 14px; height: 14px; background: currentColor; -webkit-mask: var(--icon) center/contain no-repeat; mask: var(--icon) center/contain no-repeat; }
                    
                    .badge-credit { background: var(--credit-soft); color: var(--credit); --icon: var(--icon-in); }
                    .badge-debit { background: var(--debit-soft); color: var(--debit); --icon: var(--icon-out); }

                    /* ---------- Footer ---------- */
                    .panel-foot { padding: 12px 16px; border-top: 1px solid var(--line); color: var(--muted); font-size: .8125rem; }
                    .empty { padding: 48px 16px; text-align: center; color: var(--muted); }

                    /* ---------- Mobile ---------- */
                    @media (max-width: 44rem) {
                        .masthead { grid-template-columns: 1fr; gap: 20px; }
                        .toolbar { flex-direction: column; }
                        .search { width: 100%; }
                        .segments { display: flex; } .segment { flex: 1; justify-content: center; }
                        
                        .ledger thead { display: none; }
                        .ledger, .ledger tbody, .op-row, .op-row td { display: block; width: 100%; }
                        .op-row { padding: 12px 0; border-bottom: 1px solid var(--line); }
                        .op-row td { padding: 4px 16px; border: none; display: flex; justify-content: space-between; align-items: center; }
                        .op-row td::before { content: attr(data-label); color: var(--muted); font-size: .8125rem; }
                        .op-row:hover td { background: transparent; }
                    }
                ]]></style>
            </head>
            <body>
                <main class="shell">
                    <!-- En-tête avec les informations globales et le graphique de flux -->
                    <header class="masthead">
                        <div>
                            <h1>Relevé de Compte</h1>
                            <p class="lede">
                                <strong>RIB : </strong> <xsl:value-of select="/releve/@RIB"/><br/>
                                Période du <xsl:call-template name="date-fr"><xsl:with-param name="iso" select="/releve/operations/@dateDebut"/></xsl:call-template> 
                                au <xsl:call-template name="date-fr"><xsl:with-param name="iso" select="/releve/operations/@dateFin"/></xsl:call-template>
                            </p>
                        </div>

                        <section class="balance-box">
                            <p class="balance-label">Solde Actuel</p>
                            <p class="balance-amount">
                                <xsl:value-of select="format-number(/releve/solde, '#&#160;##0,00', 'fr')"/>
                                <span class="currency"><xsl:value-of select="$currency"/></span>
                            </p>
                            
                            <xsl:if test="$total-volume &gt; 0">
                                <div class="split" aria-hidden="true">
                                    <span class="split-seg split-credit" style="--share: {$credit-share}"/>
                                    <span class="split-seg split-debit" style="--share: {$debit-share}"/>
                                </div>
                                <ul class="legend">
                                    <li>
                                        <span class="legend-name">Entrées</span>
                                        <span class="legend-value">+ <xsl:call-template name="money"><xsl:with-param name="value" select="$sum-credits"/></xsl:call-template></span>
                                    </li>
                                    <li class="legend-debit">
                                        <span class="legend-name">Sorties</span>
                                        <span class="legend-value">- <xsl:call-template name="money"><xsl:with-param name="value" select="$sum-debits"/></xsl:call-template></span>
                                    </li>
                                </ul>
                            </xsl:if>
                        </section>
                    </header>

                    <section class="panel">
                        <!-- Barre d'outils (recherche et filtres) -->
                        <div class="toolbar" id="toolbar">
                            <input class="search" id="q" type="search" placeholder="Rechercher une opération..."/>
                            <div class="filters">
                                <div class="segments" role="group">
                                    <xsl:call-template name="segment">
                                        <xsl:with-param name="value" select="'ALL'"/><xsl:with-param name="label" select="'Toutes'"/>
                                    </xsl:call-template>
                                    <xsl:call-template name="segment">
                                        <xsl:with-param name="value" select="'CREDIT'"/><xsl:with-param name="label" select="'Entrées'"/>
                                    </xsl:call-template>
                                    <xsl:call-template name="segment">
                                        <xsl:with-param name="value" select="'DEBIT'"/><xsl:with-param name="label" select="'Sorties'"/>
                                    </xsl:call-template>
                                </div>
                            </div>
                        </div>

                        <!-- Tableau des opérations -->
                        <div class="table-wrap">
                            <table class="ledger" id="operationsTable">
                                <thead>
                                    <tr>
                                        <xsl:call-template name="th-sort"><xsl:with-param name="label" select="'Date'"/><xsl:with-param name="type" select="'text'"/></xsl:call-template>
                                        <xsl:call-template name="th-sort"><xsl:with-param name="label" select="'Opération'"/><xsl:with-param name="type" select="'text'"/></xsl:call-template>
                                        <xsl:call-template name="th-sort"><xsl:with-param name="label" select="'Type'"/><xsl:with-param name="type" select="'text'"/></xsl:call-template>
                                        <xsl:call-template name="th-sort"><xsl:with-param name="label" select="'Montant'"/><xsl:with-param name="type" select="'number'"/><xsl:with-param name="numeric" select="true()"/></xsl:call-template>
                                    </tr>
                                </thead>
                                <tbody>
                                    <xsl:apply-templates select="$ops"/>
                                </tbody>
                            </table>
                        </div>

                        <div class="empty" id="empty" hidden="hidden">
                            <p>Aucune opération ne correspond à votre recherche.</p>
                        </div>
                        <p class="panel-foot" id="count"><xsl:value-of select="$nb-ops"/> opérations affichées</p>
                    </section>
                </main>

                <!-- Script JS de Progressive Enhancement pour les tris et filtres -->
                <script><![CDATA[
                    (function () {
                        'use strict';
                        var table = document.getElementById('operationsTable');
                        if (!table) return;

                        var tbody = table.querySelector('tbody');
                        var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr.op-row'));
                        var headers = Array.prototype.slice.call(table.querySelectorAll('thead th'));
                        var segments = Array.prototype.slice.call(document.querySelectorAll('.segment'));
                        var input = document.getElementById('q');
                        var counter = document.getElementById('count');
                        var emptyState = document.getElementById('empty');
                        
                        var state = { query: '', filter: 'ALL', column: -1, direction: 1 };

                        function fold(text) {
                            return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
                        }

                        function compare(a, b, type) {
                            if (type === 'number') return parseFloat(a) - parseFloat(b);
                            return a.localeCompare(b, 'fr', { numeric: true });
                        }

                        function render() {
                            var ordered = rows;
                            if (state.column >= 0) {
                                var type = headers[state.column].dataset.type;
                                ordered = rows.slice().sort(function (a, b) {
                                    var valA = a.cells[state.column].dataset.sort || a.cells[state.column].textContent;
                                    var valB = b.cells[state.column].dataset.sort || b.cells[state.column].textContent;
                                    return state.direction * compare(valA, valB, type);
                                });
                            }

                            var visibleCount = 0;
                            ordered.forEach(function (row) {
                                var showType = state.filter === 'ALL' || row.dataset.type === state.filter;
                                var showQuery = !state.query || row.dataset.search.indexOf(state.query) !== -1;
                                var show = showType && showQuery;
                                
                                row.hidden = !show;
                                if (show) {
                                    visibleCount++;
                                    tbody.appendChild(row); // Réinsère pour appliquer l'ordre
                                }
                            });

                            emptyState.hidden = visibleCount > 0;
                            counter.textContent = visibleCount + ' opération' + (visibleCount > 1 ? 's' : '') + ' affichée' + (visibleCount > 1 ? 's' : '');
                        }

                        // Event Listeners
                        input.addEventListener('input', function () {
                            state.query = fold(input.value.trim());
                            render();
                        });

                        segments.forEach(function (segment) {
                            segment.addEventListener('click', function () {
                                state.filter = segment.dataset.filter;
                                segments.forEach(function(s) { s.setAttribute('aria-pressed', s === segment); });
                                render();
                            });
                        });

                        headers.forEach(function (th, index) {
                            var button = th.querySelector('.sort');
                            if (!button) return;
                            button.addEventListener('click', function () {
                                state.direction = state.column === index ? -state.direction : 1;
                                state.column = index;
                                headers.forEach(function (h) { h.setAttribute('aria-sort', 'none'); });
                                th.setAttribute('aria-sort', state.direction === 1 ? 'ascending' : 'descending');
                                render();
                            });
                        });
                    }());
                ]]></script>
            </body>
        </html>
    </xsl:template>

    <!-- ========================================================= Lignes du tableau -->
    <xsl:template match="operation">
        <tr class="op-row" data-type="{@type}" data-search="{translate(concat(@date, ' ', @description, ' ', @montant), 'ABCDEFGHIJKLMNOPQRSTUVWXYZÉÈ', 'abcdefghijklmnopqrstuvwxyzéè')}">
            <td data-label="Date" class="date-col" data-sort="{@date}">
                <xsl:call-template name="date-fr"><xsl:with-param name="iso" select="@date"/></xsl:call-template>
            </td>
            <td data-label="Opération" class="desc-col"><xsl:value-of select="@description"/></td>
            <td data-label="Type">
                <xsl:choose>
                    <xsl:when test="@type='CREDIT'"><span class="badge badge-credit">Crédit</span></xsl:when>
                    <xsl:otherwise><span class="badge badge-debit">Débit</span></xsl:otherwise>
                </xsl:choose>
            </td>
            <td data-label="Montant" class="num" data-sort="{@montant}">
                <xsl:choose>
                    <xsl:when test="@type='CREDIT'">
                        <span class="amt-credit">+<xsl:call-template name="money"><xsl:with-param name="value" select="@montant"/></xsl:call-template></span>
                    </xsl:when>
                    <xsl:otherwise>
                        <span class="amt-debit">-<xsl:call-template name="money"><xsl:with-param name="value" select="@montant"/></xsl:call-template></span>
                    </xsl:otherwise>
                </xsl:choose>
            </td>
        </tr>
    </xsl:template>

    <!-- ========================================================= Utilitaires -->
    <xsl:template name="th-sort">
        <xsl:param name="label"/>
        <xsl:param name="type"/>
        <xsl:param name="numeric" select="false()"/>
        <th aria-sort="none" data-type="{$type}">
            <xsl:if test="$numeric"><xsl:attribute name="class">num</xsl:attribute></xsl:if>
            <button class="sort" type="button"><xsl:value-of select="$label"/></button>
        </th>
    </xsl:template>

    <xsl:template name="segment">
        <xsl:param name="value"/>
        <xsl:param name="label"/>
        <button class="segment" type="button" data-filter="{$value}" aria-pressed="{$value = 'ALL'}">
            <xsl:value-of select="$label"/>
        </button>
    </xsl:template>

    <xsl:template name="money">
        <xsl:param name="value"/>
        <xsl:value-of select="format-number($value, '#&#160;##0,00', 'fr')"/>
        <xsl:text>&#160;</xsl:text>
        <xsl:value-of select="$currency"/>
    </xsl:template>
    
    <xsl:template name="date-fr">
        <xsl:param name="iso"/>
        <xsl:variable name="month" select="number(substring($iso, 6, 2))"/>
        <xsl:choose>
            <xsl:when test="string-length($iso) = 10 and $month &gt;= 1 and $month &lt;= 12">
                <time datetime="{$iso}">
                    <xsl:value-of select="number(substring($iso, 9, 2))"/>
                    <xsl:text>&#160;</xsl:text>
                    <xsl:value-of select="normalize-space(substring($months, ($month - 1) * 5 + 1, 5))"/>
                    <xsl:text>&#160;</xsl:text>
                    <xsl:value-of select="substring($iso, 1, 4)"/>
                </time>
            </xsl:when>
            <xsl:otherwise><xsl:value-of select="$iso"/></xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>